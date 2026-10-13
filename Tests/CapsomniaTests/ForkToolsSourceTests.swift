import XCTest
@testable import Capsomnia

final class ForkToolsSourceTests: XCTestCase {
    func testConfiguredPackageBelongsToFork() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("resources/Info.plist"))
        let plist = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        XCTAssertEqual(plist["CapsomniaToolsPackageURL"] as? String, ForkToolsSource.packageURL.absoluteString)
        XCTAssertTrue(ForkToolsSource.allowsReleaseURL(ForkToolsSource.packageURL))
    }

    func testUpstreamAndUnrelatedDownloadLocationsAreRejected() {
        for value in [
            "https://github.com/fuji-mak/cpsm/releases/latest/download/Capsomnia-Tools.pkg",
            "https://github.com/fuji-mak/Capsomnia/releases/latest/download/Capsomnia-Tools.pkg",
            "https://github.com/orut34iop/Capsomnia-other/releases/latest/download/Capsomnia-Tools.pkg",
            "https://github.com/orut34iop/Capsomnia/releases/latest/download/Other.pkg",
            "http://github.com/orut34iop/Capsomnia/releases/latest/download/Capsomnia-Tools.pkg",
            "https://github.com.example.com/orut34iop/Capsomnia/releases/latest/download/Capsomnia-Tools.pkg"
        ] {
            let url = URL(string: value)!
            XCTAssertFalse(ForkToolsSource.allowsReleaseURL(url), value)
            XCTAssertFalse(ForkToolsSource.allowsDownloadURL(url), value)
        }
    }

    func testReleaseAssetRedirectAllowedButUpstreamRedirectBlocked() {
        let delegate = ForkToolsSource()
        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        let task = session.downloadTask(with: ForkToolsSource.packageURL)
        let response = HTTPURLResponse(url: ForkToolsSource.packageURL, statusCode: 302, httpVersion: nil, headerFields: nil)!
        for (value, expected) in [
            ("https://release-assets.githubusercontent.com/github-production-release-asset/test?signature=fixture", true),
            ("https://github.com/orut34iop/Capsomnia/releases/download/tools-v1/Capsomnia-Tools.pkg", true),
            ("https://github.com/fuji-mak/cpsm/releases/latest/download/Capsomnia-Tools.pkg", false),
            ("https://example.com/tools.pkg", false)
        ] {
            let request = URLRequest(url: URL(string: value)!)
            delegate.urlSession(session, task: task, willPerformHTTPRedirection: response, newRequest: request) { redirected in
                XCTAssertEqual(redirected != nil, expected, value)
            }
        }
    }

    func testUpstreamSourceFailsBeforeDownload() {
        let done = expectation(description: "Reject upstream without network access")
        ToolsDownloadController.downloadPackage(from: URL(string: "https://github.com/fuji-mak/cpsm/releases/latest/download/Capsomnia-Tools.pkg")!) { result in
            guard case .failure(let error) = result,
                  case ToolsDownloadController.DownloadError.invalidSource = error else {
                XCTFail("An upstream request must be rejected"); done.fulfill(); return
            }
            done.fulfill()
        }
        wait(for: [done], timeout: 1)
    }

    func testUpstreamInstallerTeamIsNoLongerTrusted() {
        let output = "Status: signed\n1. Developer ID Installer: Upstream (ZJZ8627852)"
        XCTAssertFalse(PackageSignature.installerSignatureIsTrusted(exitStatus: 0, output: output, teamID: developerTeamID))
        let forkOutput = "Status: signed\n1. Developer ID Installer: Fork (B829A49G4D)"
        XCTAssertTrue(PackageSignature.installerSignatureIsTrusted(exitStatus: 0, output: forkOutput, teamID: developerTeamID))
    }
}
