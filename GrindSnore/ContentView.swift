import SwiftUI

// MARK: - 主页：一键开始/停止 + 实时状态 + 夜列表入口
// 合规：录音只由用户手动开始；录音中常驻红色标识；措辞 track/record（无 diagnose）
struct ContentView: View {
    @StateObject private var recorder = RecorderEngine()
    @State private var nights: [NightRecord] = NightStore.loadAll()
    @State private var justFinished: NightRecord?
    @State private var showCheckIn = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if recorder.isRecording {
                    recordingSection
                } else {
                    idleSection
                }
                Spacer(minLength: 8)
            }
            .padding(.horizontal, 20)
            .navigationTitle("GrindSnore")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Image(systemName: "info.circle")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        TrendsView(nights: $nights)
                    } label: {
                        Image(systemName: "chart.bar.xaxis")
                    }
                }
            }
            .sheet(isPresented: $showCheckIn) {
                CheckInView(night: justFinished ?? placeholderNight) { checked in
                    if let checked { NightStore.update(checked) ; nights = NightStore.loadAll() }
                }
            }
        }
    }

    private var idleSection: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 56))
                .foregroundColor(.teal)
            Text("Track snoring & teeth grinding")
                .font(.headline)
            Text("All analysis happens on this phone. No audio leaves your device.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                recorder.start()
            } label: {
                Label("Start Night", systemImage: "record.circle")
                    .font(.title3.bold())
                    .padding()
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.teal)

            // 放置引导：只写床头柜（苹果 2.4.2 禁"枕头下"）
            Label("Place phone on the bedside table, screen up — mic facing you", systemImage: "bed.double.fill")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Spacer()

            if let last = nights.last {
                NavigationLink {
                    MorningReportView(night: last)
                } label: {
                    HStack {
                        Image(systemName: "sun.haze.fill")
                        Text("Last night: \(last.date.formatted(.dateTime.month().day())) — \(last.grindEvents.count) grind · \(last.snoreEvents.count) snore")
                            .font(.footnote)
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }

    private var recordingSection: some View {
        VStack(spacing: 16) {
            Spacer()
            Circle()
                .fill(Color.red.opacity(0.15 + 0.25 * recorder.lastLevel))
                .frame(width: 160, height: 160)
                .overlay(
                    Image(systemName: "mic.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.red)
                )
            Label("Recording — do not close the app", systemImage: "record.circle")
                .foregroundColor(.red)
                .font(.body.weight(.semibold))

            Text(elapsedString)
                .font(.system(size: 34, weight: .light).monospacedDigit())

            HStack(spacing: 32) {
                VStack {
                    Text("\(recorder.grindCount)").font(.title2.bold())
                    Text("grind").font(.caption).foregroundColor(.secondary)
                }
                VStack {
                    Text("\(recorder.snoreCount)").font(.title2.bold())
                    Text("snore").font(.caption).foregroundColor(.secondary)
                }
            }
            Spacer()

            Button {
                let events = recorder.stop()
                let night = NightRecord(
                    id: UUID(),
                    date: recorder.nightStart ?? Date(),
                    durationSeconds: recorder.elapsedSeconds,
                    snoreEvents: events.filter { $0.kind == .snore },
                    grindEvents: events.filter { $0.kind == .grind },
                    jawSore: nil, headache: nil, sleepFeel: nil, triggers: []
                )
                NightStore.save(night)
                nights = NightStore.loadAll()
                justFinished = night
                showCheckIn = true
            } label: {
                Label("I'm awake — Stop & Report", systemImage: "stop.circle.fill")
                    .font(.title3.bold())
                    .padding()
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .padding(.bottom, 8)
        }
    }

    private var elapsedString: String {
        let s = Int(recorder.elapsedSeconds)
        return String(format: "%02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }

    private var placeholderNight: NightRecord {
        NightRecord(id: UUID(), date: Date(), durationSeconds: 0,
                    snoreEvents: [], grindEvents: [],
                    jawSore: nil, headache: nil, sleepFeel: nil, triggers: [])
    }
}
