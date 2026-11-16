import Foundation

/// Restore sleep prevention at launch, then track explicit mode changes.
struct AwakeSessionState {
    private(set) var requested: Bool?

    mutating func restore(sleepDisabled: Bool?) {
        if requested == nil { requested = sleepDisabled }
    }

    mutating func recordCommand(_ result: CapsLockToggleResult) {
        if case let .changed(target) = result { requested = target }
    }
}
