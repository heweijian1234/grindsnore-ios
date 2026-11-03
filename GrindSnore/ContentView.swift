import SwiftUI

// MARK: - 主页：一键开始/停止 + 实时状态 + 夜列表入口
// 合规：录音只由用户手动开始；录音中常驻红色标识；措辞 track/record（无 diagnose）
struct ContentView: View {
    @StateObject private var recorder = RecorderEngine()
    @State private var nights: [NightRecord] = NightStore.loadAll()
    @State private var justFinished: NightRecord?
    @State private var showCheckIn = false
    @State private var showReport = false
    @State private var pendingReport = false

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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                // 夜间舒缓：深夜靛蓝渐变（录音时更暗）
                LinearGradient(colors: recordingBg,
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            )
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
            .sheet(isPresented: $showCheckIn, onDismiss: {
                // 自评 sheet 完全关闭后再弹晨报——SwiftUI 禁止 sheet 叠 sheet（此前 Save/Skip"无反应"的病根：旧代码在 sheet 内直弹第二个 sheet 被吞）
                if pendingReport {
                    pendingReport = false
                    showReport = true
                }
            }) {
                CheckInView(night: justFinished ?? placeholderNight) { checked in
                    let finalNight: NightRecord
                    if let checked {
                        NightStore.update(checked)
                        finalNight = checked
                    } else {
                        finalNight = justFinished ?? placeholderNight
                    }
                    nights = NightStore.loadAll()
                    justFinished = finalNight
                    showCheckIn = false        // 先关本 sheet，onDismiss 时再弹晨报
                    pendingReport = true
                }
            }
            .sheet(isPresented: $showReport) {
                NavigationStack {
                    MorningReportView(night: justFinished ?? placeholderNight)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { showReport = false }
                            }
                        }
                }
            }
        }
    }

    private var idleSection: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 56))
                .foregroundColor(Color(red: 0.95, green: 0.82, blue: 0.58))
            Text("Track snoring & teeth grinding")
                .font(.headline)
                .foregroundColor(.white.opacity(0.92))
            Text("All analysis happens on this phone. No audio leaves your device.")
                .font(.footnote)
                .foregroundColor(.white.opacity(0.5))
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

            if recorder.micDenied {
                VStack(spacing: 6) {
                    Text("Microphone access is off — GrindSnore can't listen.")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.red)
                    Link("Open Settings to allow microphone", destination: URL(string: UIApplication.openSettingsURLString)!)
                        .font(.footnote.weight(.semibold))
                }
            }

            // 放置引导：只写床头柜（苹果 2.4.2 禁"枕头下"）
            Label("Place phone on the bedside table, screen up — mic facing you", systemImage: "bed.double.fill")
                .font(.footnote)
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
            Spacer()

            if let last = nights.last {
                NavigationLink {
                    MorningReportView(night: last)
                } label: {
                    HStack {
                        Image(systemName: "sun.haze.fill")
                            .foregroundColor(Color(red: 0.95, green: 0.82, blue: 0.58))
                        Text("Last night: \(last.date.formatted(.dateTime.month().day())) — \(last.grindEvents.count) grind · \(last.snoreEvents.count) snore")
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }

    // 夜间舒缓配色：深夜靛蓝渐变（健哥令：睡前使用，要舒缓）
    private var recordingBg: [Color] {
        recorder.isRecording
            ? [Color(red: 0.07, green: 0.09, blue: 0.18), Color(red: 0.10, green: 0.12, blue: 0.24)]
            : [Color(red: 0.09, green: 0.13, blue: 0.22), Color(red: 0.13, green: 0.17, blue: 0.28)]
    }

    private var recordingSection: some View {
        VStack(spacing: 16) {
            Spacer()
            // 呼吸圈：暖琥珀（夜间柔和，不用红色）+ 平滑插值动画（easeInOut 0.45s——跟随声音起伏像呼吸不像跳）
            ZStack {
                Circle()
                    .fill(Color(red: 0.94, green: 0.74, blue: 0.42).opacity(0.08 + 0.22 * recorder.lastLevel))
                    .frame(width: 190, height: 190)
                    .animation(.easeInOut(duration: 0.45), value: recorder.lastLevel)
                Circle()
                    .fill(Color(red: 0.94, green: 0.74, blue: 0.42).opacity(0.10 + 0.18 * recorder.lastLevel))
                    .frame(width: 150, height: 150)
                    .animation(.easeInOut(duration: 0.45), value: recorder.lastLevel)
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 36))
                    .foregroundColor(Color(red: 0.95, green: 0.82, blue: 0.58))
                    .scaleEffect(0.94 + 0.12 * recorder.lastLevel)
                    .animation(.easeInOut(duration: 0.45), value: recorder.lastLevel)
            }
            Label("Listening — you can lock the screen", systemImage: "record.circle")
                .foregroundColor(Color(red: 0.95, green: 0.82, blue: 0.58))
                .font(.body.weight(.medium))

            if recorder.elapsedSeconds < 15 {
                Text("Test: speak softly — the moon glows")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.55))
            }

            Text(elapsedString)
                .font(.system(size: 34, weight: .light).monospacedDigit())
                .foregroundColor(.white.opacity(0.9))

            HStack(spacing: 32) {
                VStack {
                    Text("\(recorder.grindCount)").font(.title2.bold()).foregroundColor(.white.opacity(0.92))
                    Text("grind").font(.caption).foregroundColor(.white.opacity(0.45))
                }
                VStack {
                    Text("\(recorder.snoreCount)").font(.title2.bold()).foregroundColor(.white.opacity(0.92))
                    Text("snore").font(.caption).foregroundColor(.white.opacity(0.45))
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
                Label("I'm awake", systemImage: "sun.haze.fill")
                    .font(.title3.bold())
                    .padding()
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.55, green: 0.45, blue: 0.75))   // 柔和暮紫
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
