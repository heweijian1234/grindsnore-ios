import SwiftUI

// MARK: - 7 天趋势（粗版：最近 7 夜关键数+简单条形）
struct TrendsView: View {
    @Binding var nights: [NightRecord]

    private var recent: [NightRecord] { Array(nights.suffix(7)) }

    var body: some View {
        List {
            Section {
                if recent.isEmpty {
                    Text("还没有记录——今晚录第一夜！")
                        .foregroundColor(.secondary)
                }
                ForEach(recent.reversed()) { night in
                    NavigationLink {
                        MorningReportView(night: night)
                    } label: {
                        row(night)
                    }
                }
            }
            if recent.count >= 2 {
                Section("最近 7 夜 · 磨牙次数") {
                    barChart
                }
            }
        }
        .navigationTitle("趋势")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ night: NightRecord) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(night.date.formatted(.dateTime.weekday().month().day()))
                .font(.subheadline.weight(.medium))
            HStack(spacing: 10) {
                Label("\(night.grindEvents.count)", systemImage: "mouth.fill")
                    .font(.caption).foregroundColor(.orange)
                Label("\(night.snoreEvents.count)", systemImage: "waveform")
                    .font(.caption).foregroundColor(.indigo)
                Text("\(Int(night.durationSeconds / 60)) 分钟")
                    .font(.caption).foregroundColor(.secondary)
                if night.jawSore != nil {
                    Text("下巴: \(["无","轻微","酸痛","很痛"][min(night.jawSore!,3)])").font(.caption).foregroundColor(.secondary)
                }
            }
        }
    }

    private var barChart: some View {
        let maxCount = max(recent.map(\.grindEvents.count).max() ?? 1, 1)
        return VStack(alignment: .leading, spacing: 6) {
            ForEach(recent) { night in
                HStack(spacing: 8) {
                    Text(night.date.formatted(.dateTime.weekday(.abbreviated)))
                        .font(.caption2).foregroundColor(.secondary)
                        .frame(width: 36, alignment: .leading)
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.orange)
                            .frame(width: max(geo.size.width * CGFloat(night.grindEvents.count) / CGFloat(maxCount), 3))
                    }
                    .frame(height: 12)
                    Text("\(night.grindEvents.count)")
                        .font(.caption2.monospacedDigit()).foregroundColor(.secondary)
                        .frame(width: 28, alignment: .trailing)
                }
            }
        }
    }
}
