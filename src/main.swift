import AppKit

/// Receives http and https URLs from LaunchServices and hands them to Vivaldi
/// over a path that loads them in every Vivaldi state, including the
/// running-with-no-windows case that LaunchServices drops.

let vivaldiBundleID = "com.vivaldi.Vivaldi"

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

/// Runs Vivaldi's own binary with the URLs as arguments. When Vivaldi is already
/// running, Chromium's process singleton hands them to that instance and this
/// process exits; when it is not, this process becomes the browser. Either way
/// the URLs arrive through command-line startup handling, which opens a window
/// when there is none - the case the LaunchServices path drops.
func relay(_ urls: [URL], to bundleURL: URL) {
    guard let executable = Bundle(url: bundleURL)?.executableURL else {
        record("no executable inside \(bundleURL.path)")
        return
    }
    let vivaldi = Process()
    vivaldi.executableURL = executable
    vivaldi.arguments = urls.map(\.absoluteString)
    do {
        try vivaldi.run()
        record("relayed to Vivaldi")
    } catch {
        record("relay failed: \(error.localizedDescription)")
    }
}

func dispatch(_ urls: [URL]) {
    guard let bundleURL = NSWorkspace.shared
        .urlForApplication(withBundleIdentifier: vivaldiBundleID) else {
        record("Vivaldi is not installed")
        return
    }
    relay(urls, to: bundleURL)
}

/// Leaves time for closely-following events before terminating the shim.
func scheduleExit() {
    DispatchQueue.main.asyncAfter(deadline: .now() + exitDelay) {
        NSApp.terminate(nil)
    }
}

final class ShimDelegate: NSObject, NSApplicationDelegate {
    /// Opens Vivaldi normally when launched without a URL, then exits.
    func applicationOpenUntitledFile(_ sender: NSApplication) -> Bool {
        record("received plain launch")
        guard let bundleURL = NSWorkspace.shared
            .urlForApplication(withBundleIdentifier: vivaldiBundleID) else {
            record("Vivaldi is not installed")
            scheduleExit()
            return false
        }
        NSWorkspace.shared.openApplication(
            at: bundleURL, configuration: NSWorkspace.OpenConfiguration()
        ) { _, error in
            DispatchQueue.main.async {
                if let error {
                    record("open failed: \(error.localizedDescription)")
                } else {
                    record("opened Vivaldi")
                }
                scheduleExit()
            }
        }
        return true
    }

    /// LaunchServices delivers one GURL Apple event per URL. The shim handles
    /// each one and exits after `exitDelay`, leaving no resident process.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            record("received \(url.absoluteString)")
        }
        dispatch(urls)
        scheduleExit()
    }
}

let delegate = ShimDelegate()
let app = NSApplication.shared
app.delegate = delegate
app.run()
