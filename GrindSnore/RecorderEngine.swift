import Foundation
import AVFoundation
import Accelerate

// MARK: - 夜间录音引擎（粗版核心）
// 整夜录音 + 实时分拣：打鼾事件（低频段主导）/ 磨牙事件（宽带高频瞬时）/ 背景（自适应基线）
// 合规三纪律：仅用户手动开始；音频即析即弃（原始音频不落盘）；无任何网络请求
final class RecorderEngine: ObservableObject {

    struct NightEvent: Codable, Identifiable {
        enum Kind: String, Codable { case snore, grind }
        let id: UUID
        let kind: Kind
        let offsetSeconds: TimeInterval  // 相对夜开始的秒数
        let duration: TimeInterval
        let intensity: Double            // 0...1
        let lowRatio: Double             // 事件期间低频占比
    }

    @Published private(set) var isRecording = false
    @Published private(set) var nightStart: Date?
    @Published private(set) var lastLevel: Double = 0
    @Published private(set) var snoreCount = 0
    @Published private(set) var grindCount = 0
    @Published private(set) var elapsedSeconds: TimeInterval = 0
    @Published private(set) var micDenied = false

    private(set) var events: [NightEvent] = []

    private let engine = AVAudioEngine()
    private var baseline: Double = 0.001
    private var eventStartSec: TimeInterval?
    private var eventKind: NightEvent.Kind?
    private var eventPeak: Double = 0
    private var eventLowAcc: Double = 0
    private var eventFrames = 0
    private var lastLoudSec: TimeInterval?
    private let quietGapToClose: TimeInterval = 1.6

    private var tickTimer: Timer?

    // MARK: 生命周期

    func start() {
        guard !isRecording else { return }
        // 麦克风权限：拒绝→标志置位（UI 引导去设置）；未决定→弹系统询问后递归
        let session = AVAudioSession.sharedInstance()
        switch session.recordPermission {
        case .denied:
            micDenied = true
            return
        case .undetermined:
            session.requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    if granted { self?.start() } else { self?.micDenied = true }
                }
            }
            return
        default:
            break
        }
        do {
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            print("audio session error: \(error)")
            return
        }
        events.removeAll()
        snoreCount = 0
        grindCount = 0
        baseline = 0.001
        eventStartSec = nil; eventKind = nil; lastLoudSec = nil
        nightStart = Date()

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { return }
        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            guard let self, let channel = buffer.floatChannelData?[0] else { return }
            let n = Int(buffer.frameLength)
            guard n > 0 else { return }
            let result = Self.analyze(channel, n)
            DispatchQueue.main.async {
                self.handle(rms: result.rms, lowRatio: result.lowRatio)
            }
        }
        do {
            try engine.start()
            isRecording = true
            tickTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                guard let self, let start = self.nightStart else { return }
                self.elapsedSeconds = Date().timeIntervalSince(start)
            }
        } catch {
            print("engine start error: \(error)")
        }
    }

    func stop() -> [NightEvent] {
        closeOpenEvent()
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
        tickTimer?.invalidate(); tickTimer = nil
        isRecording = false
        return events
    }

    // MARK: 分析（朴素实现——云编译一轮 6 分钟，稳定优先于花活）

    struct FrameResult { let rms: Double; let lowRatio: Double }

    /// RMS + 低频占比。低频上限 ~288Hz（48kHz/1024≈46.9Hz/bin，取前 6 个 bin）
    static func analyze(_ samples: UnsafePointer<Float>, _ n: Int) -> FrameResult {
        var sumSq: Float = 0
        for i in 0..<n {
            let s = samples[i]
            sumSq += s * s
        }
        let rms = Double(max((sumSq / Float(n)).squareRoot(), 0))
        guard rms > 0.0002 else { return FrameResult(rms: rms, lowRatio: 0.5) }

        // DFT 1024 点（vDSP_DFT_zop，实部虚部原位）
        let N = 1024
        var real = [Float](repeating: 0, count: N)
        var imag = [Float](repeating: 0, count: N)
        for i in 0..<min(n, N) { real[i] = samples[i] }
        guard let setup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(N), vDSP_DFT_Direction.FORWARD) else {
            return FrameResult(rms: rms, lowRatio: 0.5)
        }
        defer { vDSP_DFT_DestroySetup(setup) }
        real.withUnsafeMutableBufferPointer { rp in
            imag.withUnsafeMutableBufferPointer { ip in
                vDSP_DFT_Execute(setup, rp.baseAddress!, ip.baseAddress!, rp.baseAddress!, ip.baseAddress!)
            }
        }
        var low: Float = 0, total: Float = 0
        for i in 1..<(N / 2) {
            let mag = real[i] * real[i] + imag[i] * imag[i]
            total += mag
            if i <= 6 { low += mag }
        }
        let lowRatio = total > 0 ? Double(low / total) : 0.5
        return FrameResult(rms: rms, lowRatio: lowRatio)
    }

    // MARK: 事件状态机

    private func handle(rms: Double, lowRatio: Double) {
        guard let start = nightStart else { return }
        let now = Date().timeIntervalSince(start)

        baseline = baseline * 0.995 + rms * 0.005
        let floor = max(baseline * 6, 0.004)
        let loud = rms > floor
        lastLevel = min(max((rms - baseline) / 0.1, 0), 1)

        if loud {
            if eventStartSec == nil {
                eventStartSec = now
                eventKind = nil
                eventPeak = rms; eventLowAcc = lowRatio; eventFrames = 1
            } else {
                eventPeak = max(eventPeak, rms)
                eventLowAcc += lowRatio
                eventFrames += 1
            }
            lastLoudSec = now
            if eventKind == nil, eventFrames >= 8 {
                let avgLow = eventLowAcc / Double(max(eventFrames, 1))
                eventKind = (avgLow > 0.55) ? .snore : .grind
            }
        } else if let es = eventStartSec, eventKind != nil,
                  let lastLoud = lastLoudSec, now - lastLoud > quietGapToClose {
            appendEvent(startSec: es, endSec: lastLoud)
            eventStartSec = nil; eventKind = nil; lastLoudSec = nil
        }
    }

    private func closeOpenEvent() {
        guard let es = eventStartSec, eventKind != nil else { return }
        let end = lastLoudSec ?? elapsedSeconds
        appendEvent(startSec: es, endSec: end)
        eventStartSec = nil; eventKind = nil; lastLoudSec = nil
    }

    private func appendEvent(startSec: TimeInterval, endSec: TimeInterval) {
        guard let kind = eventKind else { return }
        let duration = endSec - startSec
        guard duration >= 0.4 else { return }
        let floor = max(baseline * 6, 0.004)
        let intensity = min(max((eventPeak - floor) / 0.08, 0), 1)
        let avgLow = eventLowAcc / Double(max(eventFrames, 1))
        let ev = NightEvent(id: UUID(), kind: kind, offsetSeconds: startSec,
                            duration: duration, intensity: intensity, lowRatio: avgLow)
        events.append(ev)
        if kind == .snore { snoreCount += 1 } else { grindCount += 1 }
    }
}
