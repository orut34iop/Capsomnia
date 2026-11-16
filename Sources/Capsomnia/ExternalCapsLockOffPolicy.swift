enum ExternalCapsLockOffPolicy {
    /// Restore the keyboard indicator during a closed-lid session when requested.
    static func shouldReassert(
        preferenceEnabled: Bool,
        sleepPreventionActive: Bool,
        recentUserAction: Bool,
        autoOffInProgress: Bool,
        clamshellClosed: @autoclosure () -> Bool?
    ) -> Bool {
        preferenceEnabled
            && sleepPreventionActive
            && !recentUserAction
            && !autoOffInProgress
            && clamshellClosed() == true
    }
}
