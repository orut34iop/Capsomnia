import AppKit
import Darwin

final class OpenSettingsObserver: NSObject {
    @objc func receive(_ notification: Notification) {
        (NSApp?.delegate as? Capsomnia)?.openSettings()
    }
}

let notifications = DistributedNotificationCenter.default()
let openSettingsObserver = OpenSettingsObserver()
// Subscribe before competing for the lock so a manual open can reach an instance still starting.
notifications.addObserver(
    openSettingsObserver,
    selector: #selector(OpenSettingsObserver.receive(_:)),
    name: openSettingsNotificationName,
    object: appLabel,
    suspensionBehavior: .deliverImmediately
)

do {
    try FileManager.default.createDirectory(at: logDirectoryURL, withIntermediateDirectories: true)
} catch {
    NSLog("Capsomnia could not create its instance lock directory: %@", error.localizedDescription)
    exit(EXIT_FAILURE)
}

let lockPath = logDirectoryURL.appendingPathComponent("\(appLabel).lock").path
let lockDescriptor = open(lockPath, O_CREAT | O_RDWR | O_CLOEXEC | O_NOFOLLOW, 0o600)
guard lockDescriptor >= 0 else {
    perror("Capsomnia could not open its instance lock")
    exit(EXIT_FAILURE)
}

var lockResult: Int32
repeat {
    lockResult = flock(lockDescriptor, LOCK_EX | LOCK_NB)
} while lockResult == -1 && errno == EINTR

if lockResult == -1 {
    guard errno == EWOULDBLOCK else {
        perror("Capsomnia could not acquire its instance lock")
        exit(EXIT_FAILURE)
    }

    if ProcessInfo.processInfo.environment["XPC_SERVICE_NAME"] != appLabel {
        notifications.post(name: openSettingsNotificationName, object: appLabel)
    }
    exit(EXIT_SUCCESS)
}

// Keep the descriptor open for the lifetime of the process. The OS releases the lock on exit.
let app = NSApplication.shared
let delegate = Capsomnia()
app.delegate = delegate
app.run()
notifications.removeObserver(openSettingsObserver)
