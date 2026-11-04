import SwiftUI

// MARK: - 晨报：时长/两类事件次数时段/强度分布 + 诱因×磨牙对照（增强档②）+ 备注
struct MorningReportView: View {
    let night: NightRecord
    @State private var checkInNight: NightRecord?
    @State private var exportRange = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                header
                if night.jawSore == nil {
                    Button {
                        checkInNight = night
                    } label: {
                        Label("补晨间自评（30秒）", systemImage: "square.and.pencil")
                            .font(.footnote.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                    .tint(.teal)
                }
                statGrid
                timelineSection
                if !night.triggers.isEmpty || !(night.note ?? "").isEmpty { triggerSection }
                shareSection
            }
            .padding()
        }
        .navigationTitle("晨报")
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
            Text(night.date.formatted(.dateTime.month().day()))
                .font(.headline)
            Text("记录了 \(Int(night.durationSeconds / 60)) 分钟")
                .font(.subheadline).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.teal.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }

    private var statGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCell(title: "磨牙次数", value: "\(night.grindEvents.count)", sub: "累计 \(Int(night.grindTotalSeconds)) 秒", color: .orange)
            StatCell(title: "打鼾次数", value: "\(night.snoreEvents.count)", sub: "累计 \(Int(night.snoreTotalSeconds)) 秒", color: .indigo)
            StatCell(title: "磨牙强度", value: Int(night.avgGrindIntensity * 100) == 0 ? "—" : "\(Int(night.avgGrindIntensity * 100))", sub: "平均值（满分100）", color: .red)
            StatCell(title: "下巴感觉", value: jawLabel, sub: "自评", color: .teal)
        }
    }

    // 事件时间线：24 格（每 30 分钟一格），点密度=该时段事件数
    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("发生在什么时段").font(.subheadline.weight(.semibold))
            let slots = timelineSlots()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 12), spacing: 3) {
                ForEach(0..<slots.count, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color(for: slots[i]))
                        .frame(height: 22)
                }
            }
            HStack {
                Text("入睡").font(.caption2).foregroundColor(.secondary)
                Spacer()
                Text("早晨").font(.caption2).foregroundColor(.secondary)
            }
            HStack(spacing: 12) {
                legend(color: .orange, text: "磨牙")
                legend(color: .indigo, text: "打鼾")
                legend(color: .teal.opacity(0.25), text: "两者/安静")
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    // 诱因×磨牙对照（增强档②：用户痛点=找原因）+ 备注
    private var triggerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("你记录的诱因").font(.subheadline.weight(.semibold))
            Text(night.triggers.map { t in NightStore.triggerOptions.first(where: { $0.key == t })?.label ?? t }.joined(separator: "  ·  "))
                .font(.body)
            if let note = night.note, !note.isEmpty {
                Text("你的备注").font(.caption).foregroundColor(.secondary)
                Text(note).font(.callout)
            }
            let firstHalf = night.grindEvents.filter { $0.offsetSeconds < night.durationSeconds / 2 }.count
            let secondHalf = night.grindEvents.count - firstHalf
            if night.grindEvents.count > 0 {
                Text(firstHalf >= secondHalf * 2 ? "磨牙集中在**前半夜**——常与喝酒、吃太晚有关。" :
                     (secondHalf >= firstHalf * 2 ? "磨牙集中在**后半夜**——常与压力、晨间焦虑有关。" :
                      "磨牙整夜分布均匀。"))
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            Text("这是规律不是诊断——多记几晚，看什么在影响你。")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.yellow.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private var shareSection: some View {
        VStack(spacing: 8) {
            Picker("导出范围", selection: $exportRange) {
                Text("本晚").tag(0)
                Text("最近7晚").tag(1)
                Text("全部").tag(2)
            }
            .pickerStyle(.segmented)
            ShareLink(item: rangeText, subject: Text("GrindSnore 夜间报告")) {
                Label("分享报告（文字版）", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            Text("多夜汇总 PDF（给医生看的专业版）将随 Pro 解锁")
                .font(.caption).foregroundColor(.secondary)
        }
    }

    private var rangeText: String {
        let all = NightStore.loadAll()
        let list: [NightRecord]
        switch exportRange {
        case 1: list = Array(all.suffix(7))
        case 2: list = all
        default: list = [night]
        }
        guard list.count > 1 else { return textReport }
        var lines = ["GrindSnore 多夜报告（\(list.count) 晚）", ""]
        let totalGrind = list.reduce(0) { $0 + $1.grindEvents.count }
        let totalSnore = list.reduce(0) { $0 + $1.snoreEvents.count }
        for n in list {
            lines.append("\(n.date.formatted(.dateTime.month().day()))：磨牙 \(n.grindEvents.count) 次 · 打鼾 \(n.snoreEvents.count) 次 · 记录 \(Int(n.durationSeconds / 60)) 分钟")
        }
        lines.append("")
        lines.append("合计：磨牙 \(totalGrind) 次 · 打鼾 \(totalSnore) 次 · 日均磨牙 \(list.isEmpty ? 0 : totalGrind / list.count) 次")
        lines.append("（GrindSnore 本机记录——规律参考，非诊断）")
        return lines.joined(separator: "\n")
    }

    // MARK: helpers

    private var jawLabel: String {
        switch night.jawSore {
        case 0: return "无"
        case 1: return "轻微"
        case 2: return "酸痛"
        case 3: return "很痛"
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
        if let h = night.headache { headacheText = ["无","轻微","中等","厉害"][min(h,3)] } else { headacheText = "—" }
        let sleepText: String
        if let s = night.sleepFeel { sleepText = ["差","一般","好","很好"][min(s,3)] } else { sleepText = "—" }
        return """
        GrindSnore 夜间报告 · \(night.date.formatted(.dateTime.month().day()))
        记录时长：\(Int(night.durationSeconds / 60)) 分钟
        磨牙：\(night.grindEvents.count) 次（累计 \(Int(night.grindTotalSeconds)) 秒，强度 \(Int(night.avgGrindIntensity * 100))/100）
        打鼾：\(night.snoreEvents.count) 次（累计 \(Int(night.snoreTotalSeconds)) 秒）
        下巴：\(jawLabel) · 头痛：\(headacheText) · 睡眠：\(sleepText)
        诱因：\(night.triggers.isEmpty ? "—" : night.triggers.joined(separator: ", "))
        备注：\(night.note ?? "—")
        （GrindSnore 本机记录——规律参考，非诊断）
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
