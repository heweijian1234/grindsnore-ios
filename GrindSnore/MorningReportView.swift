import SwiftUI

// MARK: - 晨报：时长/两类事件次数时段/强度分布 + 诱因×磨牙对照（增强档②）
struct MorningReportView: View {
    let night: NightRecord
    @State private var checkInNight: NightRecord?

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                header
                if night.jawSore == nil {
                    Button {
                        checkInNight = night
                    } label: {
                        Label("Add morning check-in (30s)", systemImage: "square.and.pencil")
                            .font(.footnote.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                    .tint(.teal)
                }
                statGrid
                timelineSection
                if !night.triggers.isEmpty { triggerSection }
                shareSection
            }
            .padding()
        }
        .navigationTitle("Morning Report")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $checkInNight) { n in
            CheckInView(night: n) { checked in
                if let checked { NightStore.update(checked) }
                checkInNight = nil   // 置 nil 关 sheet（否则又"按钮无反应"）
            }
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text(night.date.formatted(.dateTime.weekday().month().day()))
                .font(.headline)
            Text("\(Int(night.durationSeconds / 60)) min tracked")
                .font(.subheadline).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.teal.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }

    private var statGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCell(title: "Grind events", value: "\(night.grindEvents.count)", sub: "\(Int(night.grindTotalSeconds))s total", color: .orange)
            StatCell(title: "Snore events", value: "\(night.snoreEvents.count)", sub: "\(Int(night.snoreTotalSeconds))s total", color: .indigo)
            StatCell(title: "Grind intensity", value: Int(night.avgGrindIntensity * 100) == 0 ? "—" : "\(Int(night.avgGrindIntensity * 100))", sub: "avg of 100", color: .red)
            StatCell(title: "Jaw feel", value: jawLabel, sub: "self-reported", color: .teal)
        }
    }

    // 事件时间线：一夜 24 格（每 30 分钟一格），点密度=该时段事件数
    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("When it happened").font(.subheadline.weight(.semibold))
            let slots = timelineSlots()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 12), spacing: 3) {
                ForEach(0..<slots.count, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color(for: slots[i]))
                        .frame(height: 22)
                }
            }
            HStack {
                Text("night start").font(.caption2).foregroundColor(.secondary)
                Spacer()
                Text("morning").font(.caption2).foregroundColor(.secondary)
            }
            HStack(spacing: 12) {
                legend(color: .orange, text: "grind")
                legend(color: .indigo, text: "snore")
                legend(color: .teal.opacity(0.25), text: "both/quiet")
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    // 诱因×磨牙对照（增强档②：用户痛点=找原因）
    private var triggerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Triggers you logged").font(.subheadline.weight(.semibold))
            Text(night.triggers.map { t in NightStore.triggerOptions.first(where: { $0.key == t })?.label ?? t }.joined(separator: "  ·  "))
                .font(.body)
            if let note = night.note, !note.isEmpty {
                Text("Your note").font(.caption).foregroundColor(.secondary)
                Text(note).font(.callout)
            }
            let firstHalf = night.grindEvents.filter { $0.offsetSeconds < night.durationSeconds / 2 }.count
            let secondHalf = night.grindEvents.count - firstHalf
            if night.grindEvents.count > 0 {
                Text(firstHalf >= secondHalf * 2 ? "Grinding concentrated in the first half of the night — often linked to alcohol or late meals." :
                     (secondHalf >= firstHalf * 2 ? "Grinding concentrated in the second half — often linked to stress and morning anxiety." :
                      "Grinding spread evenly across the night."))
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            Text("Patterns, not diagnosis — track over multiple nights to see what affects you.")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.yellow.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private var shareSection: some View {
        VStack(spacing: 8) {
            ShareLink(item: textReport, subject: Text("GrindSnore night report")) {
                Label("Share report (text)", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            Text("Full PDF export for your dentist comes with Pro.")
                .font(.caption).foregroundColor(.secondary)
        }
    }

    // MARK: helpers

    private var jawLabel: String {
        switch night.jawSore {
        case 0: return "None"
        case 1: return "Mild"
        case 2: return "Sore"
        case 3: return "Very"
        default: return "—"
        }
    }

    private func timelineSlots() -> [(grind: Int, snore: Int)] {
        let slotCount = 24
        var slots = Array(repeating: (grind: 0, snore: 0), count: slotCount)
        let total = max(night.durationSeconds, 1)
        for e in night.grindEvents {
            let i = min(Int(e.offsetSeconds / total * Double(slotCount)), slotCount - 1)
            slots[i].grind += 1
        }
        for e in night.snoreEvents {
            let i = min(Int(e.offsetSeconds / total * Double(slotCount)), slotCount - 1)
            slots[i].snore += 1
        }
        return slots
    }

    private func color(for slot: (grind: Int, snore: Int)) -> Color {
        if slot.grind > 0 && slot.snore > 0 { return .teal.opacity(0.6) }
        if slot.grind > 0 { return .orange }
        if slot.snore > 0 { return .indigo }
        return .teal.opacity(0.12)
    }

    private func legend(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 10, height: 10)
            Text(text).font(.caption2).foregroundColor(.secondary)
        }
    }

    private var textReport: String {
        let headacheText: String
        if let h = night.headache { headacheText = "\(h)" } else { headacheText = "—" }
        let sleepText: String
        if let s = night.sleepFeel { sleepText = "\(s)" } else { sleepText = "—" }
        return """
        GrindSnore — night of \(night.date.formatted(.dateTime.month().day()))
        Tracked: \(Int(night.durationSeconds / 60)) min
        Grind events: \(night.grindEvents.count) (\(Int(night.grindTotalSeconds))s, intensity \(Int(night.avgGrindIntensity * 100))/100)
        Snore events: \(night.snoreEvents.count) (\(Int(night.snoreTotalSeconds))s)
        Jaw: \(jawLabel) · Headache: \(headacheText) · Sleep: \(sleepText)
        Triggers: \(night.triggers.isEmpty ? "—" : night.triggers.joined(separator: ", "))
        (Recorded on-device by GrindSnore — pattern tracking, not a diagnosis.)
        """
    }
}

struct StatCell: View {
    let title: String
    let value: String
    let sub: String
    let color: Color
    var body: some View {
        VStack(spacing: 4) {
            Text(title).font(.caption).foregroundColor(.secondary)
            Text(value).font(.title2.bold()).foregroundColor(color)
            Text(sub).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }
}
