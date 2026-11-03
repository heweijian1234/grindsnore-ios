import SwiftUI

// 合规三件套之三：免责声明+隐私承诺（常驻可查）
struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Section {
                    Label("All audio is analyzed on this phone and immediately discarded. Nothing is uploaded, ever.", systemImage: "lock.shield.fill")
                        .font(.subheadline)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.teal.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

                Text("Privacy").font(.headline)
                Text("• Recording starts only when you tap Start.\n• No audio is stored — only event counts, timing and loudness.\n• No account, no network, no analytics, no ads.")

                Text("Not a medical device").font(.headline)
                Text("GrindSnore records sounds and shows patterns. It does not diagnose, treat or prevent any condition. For concerns about teeth grinding (bruxism) or snoring, talk to your dentist or doctor — and share your report with them.")

                Text("Battery note").font(.headline)
                Text("Overnight recording uses the microphone continuously. Keep the phone plugged in and place it on the bedside table.")
            }
            .padding()
        }
        .navigationTitle("About & Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}
