import SwiftUI

// 骨架版 UI：睡前一键开始（大按钮）+ 放置引导 + 状态展示
// 粗版 7 件套按方案 v2 逐件填充：录音分拣/晨报/自评/趋势/PDF解锁/隐私三件套
struct ContentView: View {
    @State private var recording = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("GrindSnore")
                .font(.largeTitle.bold())

            Text(recording ? "Recording — place phone on bedside table"
                           : "Track snoring & teeth grinding")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                recording.toggle()
            } label: {
                Text(recording ? "Stop (morning report comes next)" : "Start Night")
                    .font(.title2.bold())
                    .padding()
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 40)

            // 放置引导（措辞纪律：只写床头柜，禁"枕头下"——苹果2.4.2）
            Label("Phone on the bedside table, screen up", systemImage: "bed.double")
                .font(.footnote)
                .foregroundColor(.secondary)

            Spacer()
        }
    }
}
