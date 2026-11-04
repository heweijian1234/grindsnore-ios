import SwiftUI

// MARK: - 晨间自评（30 秒）：下巴酸痛/头痛/睡眠感 + 诱因勾选 + 自由备注
// 诱因数据供"诱因×磨牙对照"（增强档②）
struct CheckInView: View {
    let night: NightRecord
    var onDone: (NightRecord?) -> Void

    @State private var jawSore = 0
    @State private var headache = 0
    @State private var sleepFeel = 0
    @State private var triggers: Set<String> = []
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("下巴感觉怎么样？") {
                    Picker("下巴酸痛", selection: $jawSore) {
                        Text("无").tag(0); Text("轻微").tag(1); Text("酸痛").tag(2); Text("很痛").tag(3)
                    }
                    .pickerStyle(.segmented)
                }
                Section("头痛吗？") {
                    Picker("头痛", selection: $headache) {
                        Text("无").tag(0); Text("轻微").tag(1); Text("中等").tag(2); Text("厉害").tag(3)
                    }
                    .pickerStyle(.segmented)
                }
                Section("睡得怎么样？") {
                    Picker("睡眠感", selection: $sleepFeel) {
                        Text("差").tag(0); Text("一般").tag(1); Text("好").tag(2); Text("很好").tag(3)
                    }
                    .pickerStyle(.segmented)
                }
                Section("昨天有没有以下情况？") {
                    ForEach(NightStore.triggerOptions, id: \.key) { opt in
                        Toggle(opt.label, isOn: Binding(
                            get: { triggers.contains(opt.key) },
                            set: { on in
                                if on { triggers.insert(opt.key) } else { triggers.remove(opt.key) }
                                if opt.key != "none" { triggers.remove("none") }
                                if opt.key == "none" { triggers.removeAll(); triggers.insert("none") }
                            }
                        ))
                    }
                }
                Section("还想写点什么？（选填）") {
                    TextField("下巴什么感觉、做梦、环境吵不吵……随便写", text: $note, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .navigationTitle("晨间自评")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("跳过") { onDone(nil) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        var n = night
                        n.jawSore = jawSore
                        n.headache = headache
                        n.sleepFeel = sleepFeel
                        n.triggers = Array(triggers)
                        n.note = note.isEmpty ? nil : note
                        onDone(n)
                    }
                }
            }
        }
        .presentationDragIndicator(.visible)
    }
}
