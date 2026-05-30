import Foundation

enum RuntimeLog {
    private static let queue = DispatchQueue(label: "com.kumabar.runtime-log")

    static func write(_ message: String) {
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"
        queue.sync {
            let fileManager = FileManager.default
            let directory = fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Logs/KumaBar", isDirectory: true)
            let file = directory.appendingPathComponent("KumaBar.log")

            do {
                try fileManager.createDirectory(
                    at: directory,
                    withIntermediateDirectories: true
                )
                if !fileManager.fileExists(atPath: file.path) {
                    try Data().write(to: file)
                }
                let handle = try FileHandle(forWritingTo: file)
                try handle.seekToEnd()
                try handle.write(contentsOf: Data(line.utf8))
                try handle.close()
            } catch {
                // Logging must never affect the menu bar app.
            }
        }
    }
}
