import Foundation

// MARK: - 夜记录模型与本地存储（JSON 文件，无云端无账号）

struct NightRecord: Codable, Identifiable {
    let id: UUID
    let date: Date
    let durationSeconds: TimeInterval
    var snoreEvents: [RecorderEngine.NightEvent]
    var grindEvents: [RecorderEngine.NightEvent]

    // 晨起自评（可后补）
    var jawSore: Int?          // 0-3
    var headache: Int?         // 0-3
    var sleepFeel: Int?        // 0-3
    var triggers: [String]     // coffee/alcohol/stress/lateMeal/none
    var note: String?          // 用户自由备注（11-03健哥需求：要有地方自己打字写描述）

    var grindTotalSeconds: TimeInterval { grindEvents.reduce(0) { $0 + $1.duration } }
    var snoreTotalSeconds: TimeInterval { snoreEvents.reduce(0) { $0 + $1.duration } }
    var avgGrindIntensity: Double {
        guard !grindEvents.isEmpty else { return 0 }
        return grindEvents.reduce(0) { $0 + $1.intensity } / Double(grindEvents.count)
    }
}

enum NightStore {
    static var directory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("nights", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func save(_ night: NightRecord) {
        let url = directory.appendingPathComponent("\(night.id.uuidString).json")
        if let data = try? JSONEncoder().encode(night) {
            try? data.write(to: url)
        }
    }

    /// 全部夜记录（升序）
    static func loadAll() -> [NightRecord] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return [] }
        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { try? Data(contentsOf: $0) }
            .compactMap { try? JSONDecoder().decode(NightRecord.self, from: $0) }
            .sorted { $0.date < $1.date }
    }

    static func update(_ night: NightRecord) { save(night) }

    static let triggerOptions: [(key: String, label: String)] = [
        ("coffee", "咖啡 ☕️"),
        ("alcohol", "喝酒 🍺"),
        ("stress", "压力大 😣"),
        ("lateMeal", "夜宵/吃太晚 🍜"),
        ("none", "都没有"),
    ]
}
