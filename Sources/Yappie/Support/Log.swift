import OSLog

enum Log {
    static let audio = Logger(subsystem: "com.jaicodes77.yappie", category: "audio")
    static let speech = Logger(subsystem: "com.jaicodes77.yappie", category: "speech")
    static let hotkey = Logger(subsystem: "com.jaicodes77.yappie", category: "hotkey")
    static let inject = Logger(subsystem: "com.jaicodes77.yappie", category: "inject")
    static let app = Logger(subsystem: "com.jaicodes77.yappie", category: "app")
}
