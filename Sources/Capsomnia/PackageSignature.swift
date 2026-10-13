import Foundation

/// Trust check for the optional CLI & Skill installer.
enum PackageSignature {
    /// Whether `pkgutil --check-signature` output proves the package is
    /// signed by the expected Developer ID team. Requires a clean exit, a
    /// signed status, and the team ID on a "Developer ID Installer"
    /// certificate line — a team ID appearing anywhere else does not count.
    static func installerSignatureIsTrusted(exitStatus: Int32, output: String, teamID: String) -> Bool {
        guard exitStatus == 0 else {
            return false
        }
        guard output.contains("Status: signed") else {
            return false
        }
        return output
            .split(separator: "\n")
            .contains { line in
                line.contains("Developer ID Installer") && line.contains("(\(teamID))")
            }
    }
}
