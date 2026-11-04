import SwiftUI
import MessageUI

// MARK: - 用户反馈页（健哥 11-04 令）——邮件直达开发者；自动附识别修正统计（改进数据回流）
struct FeedbackView: View {
    @State private var text = ""
    @State private var showMail = false
    private var mailAvailable: Bool { MFMailComposeViewController.canSendMail() }

    var body: some View {
        Form {
            Section("说说你的想法") {
                TextField("哪里好用、哪里别扭、识别准不准、想要什么功能……直接写，开发者本人看。", text: $text, axis: .vertical)
                    .lineLimit(6...14)
            }
            Section {
                Button {
                    showMail = true
                } label: {
                    Label("发送给开发者", systemImage: "paperplane.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !mailAvailable)
                if !mailAvailable {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("本机没有配置邮件账户——请把意见发到：")
                            .font(.caption).foregroundColor(.secondary)
                        Text("48449892@qq.com")
                            .font(.body.bold())
                            .textSelection(.enabled)
                    }
                }
            }
            let logs = NightStore.loadCorrections()
            if !logs.isEmpty {
                Section("你的识别修正记录（会随反馈自动附上）") {
                    ForEach(Array(logs.suffix(10).enumerated().reversed()), id: \.offset) { _, log in
                        HStack {
                            Text("\(log.from) → \(log.to)")
                                .font(.caption)
                            Spacer()
                            Text(log.date.formatted(.dateTime.month().day().hour().minute()))
                                .font(.caption2).foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("意见反馈")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showMail) {
            MailComposer(body: composeBody())
        }
    }

    private func composeBody() -> String {
        var body = text
        let logs = NightStore.loadCorrections()
        if !logs.isEmpty {
            body += "\n\n——识别修正记录（\(logs.count) 条）——"
            for log in logs.suffix(30) {
                body += "\n\(log.date.formatted(.dateTime.month().day().hour().minute()))：\(log.from) → \(log.to)"
            }
        }
        return body
    }
}

struct MailComposer: UIViewControllerRepresentable {
    let body: String
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let m = MFMailComposeViewController()
        m.setToRecipients(["48449892@qq.com"])
        m.setSubject("GrindSnore 用户反馈")
        m.setMessageBody(body, isHTML: false)
        m.mailComposeDelegate = context.coordinator
        return m
    }
    func updateUIViewController(_ vc: MFMailComposeViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            controller.dismiss(animated: true)
        }
    }
}
