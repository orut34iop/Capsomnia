import XCTest
import CoreGraphics
@testable import Capsomnia

final class AwakeSessionStateTests: XCTestCase {
    func testStartupAdoptsFirstAvailableStateOnly() {
        var state = AwakeSessionState()
        state.restore(sleepDisabled: nil)
        XCTAssertNil(state.requested)
        state.restore(sleepDisabled: false)
        state.restore(sleepDisabled: true)
        XCTAssertEqual(state.requested, false)
    }

    func testActiveSessionRetainsTimerDeadlineAfterTwoHours() {
        var state = AwakeSessionState()
        state.recordCommand(.changed(to: true))
        var timer = SessionAutoOffTimer()
        let start = Date(timeIntervalSince1970: 1000)
        XCTAssertFalse(timer.evaluate(capsLockOn: state.requested!, defaultMinutes: 180, now: start))
        let deadline = timer.deadline
        for second in stride(from: 7200, through: 9000, by: 1) {
            XCTAssertEqual(state.requested, true)
            XCTAssertFalse(timer.evaluate(capsLockOn: state.requested!, defaultMinutes: 180,
                                          now: start.addingTimeInterval(Double(second))))
            XCTAssertEqual(timer.deadline, deadline)
        }
        XCTAssertTrue(timer.evaluate(capsLockOn: state.requested!, defaultMinutes: 180, now: deadline!))
        state.recordCommand(.changed(to: false))
        state.restore(sleepDisabled: true)
        XCTAssertEqual(state.requested, false)
    }

    func testConfirmedManualOffWinsOverDriftAndStaleObservations() {
        var state = AwakeSessionState()
        state.recordCommand(.changed(to: true))
        state.restore(sleepDisabled: false)
        state.recordCommand(.changed(to: false))
        for observed in [true, false, nil] as [Bool?] { state.restore(sleepDisabled: observed) }
        XCTAssertEqual(state.requested, false)
    }

    func testFailedCommandsDoNotChangeRequestedSession() {
        for active in [false, true] {
            var state = AwakeSessionState()
            state.recordCommand(.changed(to: active))
            for failure in [CapsLockToggleResult.unavailable, .writeFailed(target: !active),
                            .verificationFailed(target: !active, actual: !active)] {
                state.recordCommand(failure)
                XCTAssertEqual(state.requested, active)
            }
        }
    }

    func testDedicatedFilterSuppressesCapsLockAndPreservesOtherKeys() throws {
        let filter = DedicatedCapsLockFilter()
        let event = try XCTUnwrap(CGEvent(keyboardEventSource: nil, virtualKey: 57, keyDown: true))
        event.setIntegerValueField(.keyboardEventKeycode, value: 57)
        event.flags = [.maskAlphaShift]
        XCTAssertNil(filter.handle(type: .flagsChanged, event: event))
        event.flags = []
        XCTAssertNil(filter.handle(type: .flagsChanged, event: event))
        event.setIntegerValueField(.keyboardEventKeycode, value: 0)
        event.flags = [.maskAlphaShift, .maskShift]
        XCTAssertNotNil(filter.handle(type: .keyDown, event: event))
        XCTAssertFalse(event.flags.contains(.maskAlphaShift))
        XCTAssertTrue(event.flags.contains(.maskShift))
    }
}
