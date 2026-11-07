import IOKit.pwr_mgt
import XCTest

final class KeepAwakeModuleTests: XCTestCase {
    func testRepeatedEnableAndDisableOwnOneAssertion() {
        var creations = 0
        var released: [IOPMAssertionID] = []
        let assertion = KeepAwakeAssertion(create: {
            creations += 1
            return (kIOReturnSuccess, 42)
        }, release: {
            released.append($0)
            return kIOReturnSuccess
        })
        XCTAssertEqual(assertion.setEnabled(true), kIOReturnSuccess)
        XCTAssertEqual(assertion.setEnabled(true), kIOReturnSuccess)
        XCTAssertTrue(assertion.active)
        XCTAssertEqual(creations, 1)
        XCTAssertEqual(assertion.setEnabled(false), kIOReturnSuccess)
        XCTAssertEqual(assertion.setEnabled(false), kIOReturnSuccess)
        XCTAssertFalse(assertion.active)
        XCTAssertEqual(released, [42])
    }

    func testCreationFailureDoesNotClaimToBeActive() {
        let assertion = KeepAwakeAssertion(create: { (kIOReturnError, 42) }, release: { _ in
            XCTFail("Failed creation must not release an assertion")
            return kIOReturnSuccess
        })
        XCTAssertEqual(assertion.setEnabled(true), kIOReturnError)
        XCTAssertFalse(assertion.active)
    }

    func testReleaseFailureRetainsAssertionForRetry() {
        var attempts = 0
        let assertion = KeepAwakeAssertion(create: { (kIOReturnSuccess, 42) }, release: { _ in
            attempts += 1
            return attempts == 1 ? kIOReturnError : kIOReturnSuccess
        })
        XCTAssertEqual(assertion.setEnabled(true), kIOReturnSuccess)
        XCTAssertEqual(assertion.setEnabled(false), kIOReturnError)
        XCTAssertTrue(assertion.active)
        XCTAssertEqual(assertion.setEnabled(false), kIOReturnSuccess)
        XCTAssertFalse(assertion.active)
    }

    func testDeinitializationReleasesOwnedAssertion() {
        var released: [IOPMAssertionID] = []
        var assertion: KeepAwakeAssertion? = KeepAwakeAssertion(
            create: { (kIOReturnSuccess, 7) }, release: {
                released.append($0)
                return kIOReturnSuccess
            }
        )
        XCTAssertEqual(assertion?.setEnabled(true), kIOReturnSuccess)
        assertion = nil
        XCTAssertEqual(released, [7])
    }
}
