import SwiftUI
import AVFoundation

// MARK: - 事件明细（健哥 11-04 令）：回放片段 + 修正类型 + 删误报——修正进日志
struct EventListView: View {
    @Binding var night: NightRecord
    @State private var player: AVAudioPlayer?

    private var visibleEvents: [RecorderEngine.NightEvent] {
        (night.grindEvents + night.snoreEvents)
            .filter { !$0.userDeleted }
            .sorted { $0.offsetSeconds < $1.offsetSeconds }
    }

    var body: some View {
        List {
            if visibleEvents.isEmpty {
                Text("没有可显示的事件")
                    .foregroundColor(.secondary)
            }
            ForEach(visibleEvents) { ev in
                row(ev)
            }
            if !night.grindEvents.filter({ $0.userDeleted }).isEmpty
                || !night.snoreEvents.filter({ $0.userDeleted }).isEmpty {
                Text("已删误报 \(night.grindEvents.filter(\.userDeleted).count + night.snoreEvents.filter(\.userDeleted).count) 条")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
        .navigationTitle("事件明细")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ ev: RecorderEngine.NightEvent) -> some View {
        HStack(spacing: 12) {
            Button {
                play(ev)
            } label: {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(ev.clipFile != nil ? .teal : .gray.opacity(0.4))
            }
            .disabled(ev.clipFile == nil)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(ev.kind == .snore ? "打鼾" : "磨牙")
                        .font(.subheadline.bold())
                        .foregroundColor(ev.kind == .snore ? .indigo : .orange)
                    if ev.userCorrected {
                        Text("已修正").font(.caption2).foregroundColor(.green)
                    }
                }
                Text(timeString(ev.offsetSeconds) + " · \(String(format: "%.1f", ev.duration)) 秒")
                    .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Menu {
                Button {
                    correct(ev, to: ev.kind == .snore ? .grind : .snore)
                } label: {
                    Label(ev.kind == .snore ? "改成磨牙" : "改成打鼾", systemImage: "arrow.triangle.2.circlepath")
                }
                Button(role: .destructive) {
                    delete(ev)
                } label: {
                    Label("这是误报，删除", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.secondary)
            }
        }
    }

    private func play(_ ev: RecorderEngine.NightEvent) {
        guard let file = ev.clipFile else { return }
        let url = NightStore.clipsDir.appendingPathComponent(file)
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
    }

    private func correct(_ ev: RecorderEngine.NightEvent, to: RecorderEngine.NightEvent.Kind) {
        let from = ev.kind == .snore ? "打鼾" : "磨牙"
        let toLabel = to == .snore ? "打鼾" : "磨牙"
        apply(ev) { e in e.kind = to; e.userCorrected = true }
        NightStore.logCorrection(from: from, to: toLabel)
    }

    private func delete(_ ev: RecorderEngine.NightEvent) {
        let from = ev.kind == .snore ? "打鼾" : "磨牙"
        apply(ev) { e in e.userDeleted = true }
        NightStore.logCorrection(from: from, to: "删除")
    }

    /// 在 night 的两个数组里找到并改这条（类型变化挪数组），改完存档
    private func apply(_ ev: RecorderEngine.NightEvent, _ mut: (inout RecorderEngine.NightEvent) -> Void) {
        if let i = night.grindEvents.firstIndex(where: { $0.id == ev.id }) {
            var e = night.grindEvents[i]
            let was = e.kind
            mut(&e)
            if e.kind == was {
                night.grindEvents[i] = e
            } else {
                night.grindEvents.remove(at: i)
                if e.kind == .snore { night.snoreEvents.append(e) } else { night.grindEvents.append(e) }
            }
        } else if let i = night.snoreEvents.firstIndex(where: { $0.id == ev.id }) {
            var e = night.snoreEvents[i]
            let was = e.kind
            mut(&e)
            if e.kind == was {
                night.snoreEvents[i] = e
            } else {
                night.snoreEvents.remove(at: i)
                if e.kind == .snore { night.snoreEvents.append(e) } else { night.grindEvents.append(e) }
            }
        }
        NightStore.update(night)
    }

    private func timeString(_ sec: TimeInterval) -> String {
        let s = Int(sec)
        return String(format: "%02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }
}
