import Foundation

struct ScheduleEntry: Codable, Identifiable {
    var id: UUID = UUID()
    var targetPath: String = ""
    var targetName: String = ""
    var openTime: Date?  = nil
    var closeTime: Date? = nil
    var isPaused: Bool   = false  // per-entry pause
}

struct SchedulerConfig: Codable {
    var entries: [ScheduleEntry] = []
    var isRunning: Bool    = false
    var showCountdown: Bool = true
}

class ConfigStore {
    private static let key = "SchedulerConfig_v3"

    static func load() -> SchedulerConfig {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let config = try? JSONDecoder().decode(SchedulerConfig.self, from: data)
        else { return SchedulerConfig() }
        return config
    }

    static func save(_ config: SchedulerConfig) {
        guard let data = try? JSONEncoder().encode(config) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
