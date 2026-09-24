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

func vivaldiIsRunning() -> Bool {
    !NSRunningApplication.runningApplications(withBundleIdentifier: vivaldiBundleID).isEmpty
}

/// Vivaldi's own binary relays the URL through Chromium's singleton socket,
/// which loads it even when Vivaldi has no open windows.
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
        record("relayed to running Vivaldi")
    } catch {
        record("relay failed: \(error.localizedDescription)")
    }
}

/// A cold start goes through LaunchServices, which loads the URL correctly and
/// leaves Vivaldi owned by launchd rather than parented to the shim.
func coldLaunch(_ urls: [URL], at bundleURL: URL) {
    NSWorkspace.shared.open(urls,
                            withApplicationAt: bundleURL,
                            configuration: NSWorkspace.OpenConfiguration())
    record("cold launched Vivaldi")
}

func dispatch(_ urls: [URL]) {
    guard let bundleURL = NSWorkspace.shared
        .urlForApplication(withBundleIdentifier: vivaldiBundleID) else {
        record("Vivaldi is not installed")
        return
    }
    if vivaldiIsRunning() {
        relay(urls, to: bundleURL)
    } else {
        coldLaunch(urls, at: bundleURL)
    }
}

final class ShimDelegate: NSObject, NSApplicationDelegate {
    /// LaunchServices delivers one GURL Apple event per URL. The shim handles
    /// each one and exits after `exitDelay`, leaving no resident process.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            record("received \(url.absoluteString)")
        }
        dispatch(urls)
        DispatchQueue.main.asyncAfter(deadline: .now() + exitDelay) {
            NSApp.terminate(nil)
        }
    }
}

let delegate = ShimDelegate()
let app = NSApplication.shared
app.delegate = delegate
app.run()
