import SwiftUI

// 合规三件套之三：免责声明+隐私承诺（常驻可查）——测试期中文版（上架前本地化）
struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Section {
                    Label("所有音频在本机分析后立即丢弃，永不联网上传。", systemImage: "lock.shield.fill")
                        .font(.subheadline)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.teal.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

                Text("隐私").font(.headline)
                Text("• 录音只在你点「开始」后才启动\n• 不存原始音频——只保留事件次数、时段和响度\n• 无账号、无联网、无统计、无广告")

                Text("不是医疗器械").font(.headline)
                Text("GrindSnore 只记录声音并显示规律。它不诊断、不治疗、不预防任何状况。如果担心磨牙（夜磨牙症）或打鼾，请咨询牙医或医生——可以把报告分享给 TA 看。")

                Text("电池提示").font(.headline)
                Text("整夜录音会持续使用麦克风。建议手机插着充电，放在床头柜上。")
            }
            .padding()
        }
        .navigationTitle("关于与隐私")
        .navigationBarTitleDisplayMode(.inline)
    }
}
