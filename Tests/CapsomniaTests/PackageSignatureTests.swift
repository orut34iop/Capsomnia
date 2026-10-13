import XCTest
@testable import Capsomnia

final class PackageSignatureTests: XCTestCase {
    private let signedPkgutilOutput = """
    Package "Capsomnia-3.5.0.pkg":
       Status: signed by a developer certificate issued by Apple for distribution
       Notarization: trusted by the Apple notary service
       Certificate Chain:
        1. Developer ID Installer: Taketo Fujimaki (ZJZ8627852)
           Expires: 2027-02-01 22:12:15 +0000
        2. Developer ID Certification Authority
        3. Apple Root CA
    """

    func testInstallerSignatureTrustedForMatchingTeamID() {
        XCTAssertTrue(PackageSignature.installerSignatureIsTrusted(
            exitStatus: 0,
            output: signedPkgutilOutput,
            teamID: "ZJZ8627852"
        ))
    }

    func testInstallerSignatureRejectedForOtherTeamID() {
        XCTAssertFalse(PackageSignature.installerSignatureIsTrusted(
            exitStatus: 0,
            output: signedPkgutilOutput,
            teamID: "AAAA000000"
        ))
    }

    func testInstallerSignatureRejectedWhenUnsignedOrFailed() {
        let unsigned = """
        Package "Capsomnia-3.5.0.pkg":
           Status: no signature
        """

        XCTAssertFalse(PackageSignature.installerSignatureIsTrusted(
            exitStatus: 0,
            output: unsigned,
            teamID: "ZJZ8627852"
        ))
        XCTAssertFalse(PackageSignature.installerSignatureIsTrusted(
            exitStatus: 1,
            output: signedPkgutilOutput,
            teamID: "ZJZ8627852"
        ))
        XCTAssertFalse(PackageSignature.installerSignatureIsTrusted(
            exitStatus: 0,
            output: "",
            teamID: "ZJZ8627852"
        ))
    }

    func testInstallerSignatureRejectsTeamIDOutsideInstallerCertificateLine() {
        let mismatched = """
        Package "Capsomnia-3.5.0.pkg":
           Status: signed by a developer certificate issued by Apple for distribution
           Certificate Chain:
            1. Developer ID Installer: Someone Else (AAAA000000)
               Notes: ZJZ8627852
        """

        XCTAssertFalse(PackageSignature.installerSignatureIsTrusted(
            exitStatus: 0,
            output: mismatched,
            teamID: "ZJZ8627852"
        ))
    }
}
