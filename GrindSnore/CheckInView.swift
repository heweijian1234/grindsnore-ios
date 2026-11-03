import SwiftUI

// MARK: - 晨起自评（30 秒）：下巴酸痛/头痛/睡眠感 + 诱因勾选
// 诱因数据供"诱因×磨牙对照"（增强档②）
struct CheckInView: View {
    let night: NightRecord
    var onDone: (NightRecord?) -> Void

    @State private var jawSore = 0
    @State private var headache = 0
    @State private var sleepFeel = 0
    @State private var triggers: Set<String> = []

    var body: some View {
        NavigationStack {
            Form {
                Section("How does your jaw feel?") {
                    Picker("Jaw soreness", selection: $jawSore) {
                        Text("None").tag(0); Text("Mild").tag(1); Text("Sore").tag(2); Text("Very sore").tag(3)
                    }
                    .pickerStyle(.segmented)
                }
                Section("Headache?") {
                    Picker("Headache", selection: $headache) {
                        Text("None").tag(0); Text("Mild").tag(1); Text("Moderate").tag(2); Text("Strong").tag(3)
                    }
                    .pickerStyle(.segmented)
                }
                Section("How did you sleep?") {
                    Picker("Sleep feel", selection: $sleepFeel) {
                        Text("Bad").tag(0); Text("OK").tag(1); Text("Good").tag(2); Text("Great").tag(3)
                    }
                    .pickerStyle(.segmented)
                }
                Section("Did you have any of these yesterday?") {
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
            }
            .navigationTitle("Morning check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") { onDone(nil) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var n = night
                        n.jawSore = jawSore
                        n.headache = headache
                        n.sleepFeel = sleepFeel
                        n.triggers = Array(triggers)
                        onDone(n)
                    }
                }
            }
        }
        .presentationDragIndicator(.visible)
    }
}
