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
        var kind: Kind                   // 用户可修正（健哥 11-04 令）
        let offsetSeconds: TimeInterval
        let duration: TimeInterval
        let intensity: Double
        let lowRatio: Double
        var clipFile: String?            // 回放片段（m4a）
        var userCorrected: Bool = false  // 用户改过类型
        var userDeleted: Bool = false    // 用户判误报删除
    }

    @Published private(set) var isRecording = false
    @Published private(set) var nightStart: Date?
    @Published private(set) var lastLevel: Double = 0
    @Published private(set) var snoreCount = 0
    @Published private(set) var grindCount = 0
    @Published private(set) var elapsedSeconds: TimeInterval = 0
    @Published private(set) var micDenied = false
    // 测试期调试 HUD（正式版删）：当前 RMS 与触发门槛，供远程校准
    @Published private(set) var debugRMS: Double = 0
    @Published private(set) var debugFloor: Double = 0
    @Published private(set) var lastEventDesc = "—"
    // 灵敏度档（健哥白天测试环境有底噪，自适应门槛被抬太高埋没人声——高档=固定低门槛不吃环境账）
    @Published var sensitivity: Int = 1   // 0=高 1=中 2=低

    private(set) var events: [NightEvent] = []

    private let engine = AVAudioEngine()
    private var baseline: Double = 0.001
    private var eventStartSec: TimeInterval?
    private var eventPeak: Double = 0
    private var eventLowAcc: Double = 0
    private var eventFrames = 0
    private var lastLoudSec: TimeInterval?
    private let quietGapToClose: TimeInterval = 1.6

    private var tickTimer: Timer?

    // 环形音频缓存（健哥 11-04 令：事件可回放）——保最近 30 秒样本，事件闭合时导出片段
    private let ringLock = NSLock()
    private var ringBuffer: [Float] = []
    private var ringStartOffset: Double = 0   // ringBuffer[0] 对应的夜内偏移秒
    private var sampleRate: Double = 48000
    private let ringSeconds: Double = 30
    private var clipCounter = 0

    static var clipsDir: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("clips", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

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
        eventStartSec = nil; lastLoudSec = nil
        nightStart = Date()

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { return }
        sampleRate = format.sampleRate
        ringLock.lock(); ringBuffer.removeAll(); ringStartOffset = 0; ringLock.unlock()
        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            guard let self, let channel = buffer.floatChannelData?[0] else { return }
            let n = Int(buffer.frameLength)
            guard n > 0 else { return }
            // 环形缓存追加（音频线程，锁保护）
            self.ringLock.lock()
            self.ringBuffer.append(contentsOf: UnsafeBufferPointer(start: channel, count: n))
            let maxLen = Int(self.sampleRate * self.ringSeconds)
            if self.ringBuffer.count > maxLen {
                let overflow = self.ringBuffer.count - maxLen
                self.ringBuffer.removeFirst(overflow)
                self.ringStartOffset += Double(overflow) / self.sampleRate
            }
            self.ringLock.unlock()
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

        // 11-04 校准 v4（基于健哥实测音频分析定死）：环境底噪实测 0.011-0.013，模拟声 0.03-0.21
        // 自适应门槛在该环境已证不可靠（环境尖峰与目标声重叠）——高/中改固定值
        baseline = baseline * 0.9985 + rms * 0.0015
        let floor: Double
        switch sensitivity {
        case 0: floor = 0.020   // 高：固定，略高于实测底噪（会收少量环境尖峰）
        case 2: floor = max(baseline * 4, 0.013)  // 低：自适应（夜间极安静环境）
        default: floor = 0.030  // 中（默认）：实测最优——环境90%分位在线下，模拟声过线
        }
        let loud = rms > floor
        debugRMS = rms
        debugFloor = floor
        lastLevel = min(max((rms - baseline) / 0.1, 0), 1)

        if loud {
            if eventStartSec == nil {
                eventStartSec = now
                eventPeak = rms; eventLowAcc = lowRatio; eventFrames = 1
            } else {
                eventPeak = max(eventPeak, rms)
                eventLowAcc += lowRatio
                eventFrames += 1
            }
            lastLoudSec = now
        } else if let es = eventStartSec,
                  let lastLoud = lastLoudSec, now - lastLoud > quietGapToClose {
            appendEvent(startSec: es, endSec: lastLoud)
            eventStartSec = nil; lastLoudSec = nil
        }
    }

    private func closeOpenEvent() {
        guard let es = eventStartSec else { return }
        let end = lastLoudSec ?? elapsedSeconds
        appendEvent(startSec: es, endSec: end)
        eventStartSec = nil; lastLoudSec = nil
    }

    private func appendEvent(startSec: TimeInterval, endSec: TimeInterval) {
        let duration = endSec - startSec
        guard duration >= 0.5 else { return }
        let floor: Double
        switch sensitivity {
        case 0: floor = 0.020
        case 2: floor = max(baseline * 4, 0.013)
        default: floor = 0.030
        }
        let intensity = min(max((eventPeak - floor) / 0.08, 0), 1)
        let avgLow = eventLowAcc / Double(max(eventFrames, 1))
        // 分类（实测特征：磨牙串低频 0.33-0.55 / 打鼾串 0.67-0.93；模拟打鼾 0.7s→时长窗 0.6 起）
        let kind: NightEvent.Kind
        if avgLow > 0.62 && duration >= 0.6 && duration <= 20 {
            kind = .snore
        } else {
            kind = .grind
        }
        let ev = NightEvent(id: UUID(), kind: kind, offsetSeconds: startSec,
                            duration: duration, intensity: intensity, lowRatio: avgLow,
                            clipFile: exportClip(from: max(startSec - 2, 0), to: endSec + 1))
        events.append(ev)
        if kind == .snore { snoreCount += 1 } else { grindCount += 1 }
        lastEventDesc = "\(kind == .snore ? "打鼾" : "磨牙") \(String(format: "%.1f", duration))s 低频\(String(format: "%.2f", avgLow))"
    }

    /// 从环形缓存导出片段（m4a）——事件前 2 秒到结束后 1 秒
    private func exportClip(from: Double, to: Double) -> String? {
        ringLock.lock()
        let bufferCopy = ringBuffer
        let ringStart = ringStartOffset
        ringLock.unlock()
        guard !bufferCopy.isEmpty else { return nil }
        let sr = sampleRate
        let startIdx = max(Int((from - ringStart) * sr), 0)
        let endIdx = min(Int((to - ringStart) * sr), bufferCopy.count)
        guard endIdx > startIdx else { return nil }
        let samples = Array(bufferCopy[startIdx..<endIdx])
        clipCounter += 1
        let name = "clip-\(clipCounter).m4a"
        let url = Self.clipsDir.appendingPathComponent(name)
        guard let outFormat = AVAudioFormat(settings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: sr,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium,
        ]) else { return nil }
        do {
            let file = try AVAudioFile(forWriting: url, settings: outFormat.settings)
            let srcFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sr, channels: 1, interleaved: false)!
            let chunkFrames = 48000
            var idx = 0
            while idx < samples.count {
                let frames = min(chunkFrames, samples.count - idx)
                if let buf = AVAudioPCMBuffer(pcmFormat: srcFormat, frameCapacity: AVAudioFrameCount(frames)) {
                    buf.frameLength = AVAudioFrameCount(frames)
                    if let ptr = buf.floatChannelData?[0] {
                        for i in 0..<frames { ptr[i] = samples[idx + i] }
                    }
                    try file.write(from: buf)
                }
                idx += frames
            }
            try file.close()
            return name
        } catch {
            print("clip export error: \(error)")
            return nil
        }
    }
}
