import XCTest
import CapsomniaControl
@testable import Capsomnia

/// Opt-in installed-app integration test. Changes only physical Caps Lock;
/// never issues CLI off (which requests sleep). Requires an open lid and a
/// running app, and restores the original hardware state on every exit.
final class RunningAppSessionTests: XCTestCase {
    func testCapsLockChangesPreserveConfirmedAwakeState() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["CAPSOMNIA_SESSION_HARDWARE_TEST"] == "1")
        try XCTSkipUnless(ClamshellStateReader.isClosed() == false, "Open lid required")
        let client = try ControlClient(bundleIdentifier: "com.github.fuji-mak.capsomnia")
        func status() throws -> [String: JSONValue] {
            let response = try client.send(ControlRequest(arguments: ["status"]))
            guard response.ok, case let .object(value) = response.result else {
                throw ExplicitAwakeCommand.Failure("Installed app status unavailable")
            }
            return value
        }
        let initial = try status()
        guard case let .bool(awake)? = initial["caps_lock"] else {
            throw XCTSkip("Start with a confirmed awake state")
        }
        try XCTSkipUnless(initial["sleep_disabled"] == .bool(awake), "Wait for the current transition")
        let physical = try XCTUnwrap(SystemCapsLockStateReader().currentState())
        defer { _ = SystemCapsLockController.set(physical) }
        for cycle in 1...5 {
            XCTAssertEqual(SystemCapsLockController.set(!awake), .changed(to: !awake))
            for _ in 0..<12 {
                Thread.sleep(forTimeInterval: 0.25)
                let value = try status()
                guard value["caps_lock"] == .bool(awake), value["sleep_disabled"] == .bool(awake) else {
                    XCTFail("Caps Lock changed the awake state at cycle \(cycle): \(value)")
                    return
                }
            }
            XCTAssertEqual(SystemCapsLockController.set(awake), .changed(to: awake))
        }
    }
}
