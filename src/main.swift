import AppKit

/// Phase 1 skeleton: records the URLs LaunchServices hands over.
/// Dispatch to Vivaldi is not implemented yet.

let logFile = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Logs/VivaldiShim.log")

/// How long the shim stays alive after handling an event. Exiting immediately
/// puts termination exactly where a closely-following event arrives, which
/// loses it; any delay moves the exit clear of that arrival.
let exitDelay: TimeInterval = 0.050

let timestamps: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
}()

/// Appends one timestamped line to the shim's log file, creating it if needed.
func record(_ message: String) {
    let stamp = timestamps.string(from: Date())
    let line = Data("\(stamp) \(message)\n".utf8)

    guard let handle = try? FileHandle(forWritingTo: logFile) else {
        try? line.write(to: logFile)
        return
    }
    defer { try? handle.close() }
    _ = try? handle.seekToEnd()
    try? handle.write(contentsOf: line)
}

final class ShimDelegate: NSObject, NSApplicationDelegate {
    /// LaunchServices delivers one GURL Apple event per URL. The shim handles
    /// each one and exits after `exitDelay`, leaving no resident process.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            record("received \(url.absoluteString)")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + exitDelay) {
            NSApp.terminate(nil)
        }
    }
}

let delegate = ShimDelegate()
let app = NSApplication.shared
app.delegate = delegate
app.run()
