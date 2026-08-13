import XCTest
@testable import DockGestureCore

final class PermissionGuidanceTests: XCTestCase {
    func testMissingPermissionDescriptionsAreSpecific() {
        XCTAssertEqual(
            PermissionAvailability(accessibility: false, inputMonitoring: false)
                .missingPermissionsDescription,
            "缺少辅助功能和输入监控权限"
        )
        XCTAssertEqual(
            PermissionAvailability(accessibility: false, inputMonitoring: true)
                .missingPermissionsDescription,
            "缺少辅助功能权限"
        )
        XCTAssertEqual(
            PermissionAvailability(accessibility: true, inputMonitoring: false)
                .missingPermissionsDescription,
            "缺少输入监控权限"
        )
        XCTAssertNil(
            PermissionAvailability(accessibility: true, inputMonitoring: true)
                .missingPermissionsDescription
        )
    }

    func testAutomaticInputGuideAppearsOnlyBeforeItHasBeenShown() {
        let availability = PermissionAvailability(accessibility: true, inputMonitoring: false)

        let first = PermissionGuidancePlan.make(
            availability: availability,
            trigger: .automatic,
            automaticGuideAlreadyShown: false
        )
        let laterPoll = PermissionGuidancePlan.make(
            availability: availability,
            trigger: .automatic,
            automaticGuideAlreadyShown: true
        )

        XCTAssertTrue(first.showInputMonitoringGuide)
        XCTAssertTrue(first.markAutomaticGuideAsShown)
        XCTAssertFalse(laterPoll.showInputMonitoringGuide)
        XCTAssertFalse(laterPoll.markAutomaticGuideAsShown)
    }

    func testManualCheckCanShowInputGuideAgain() {
        let plan = PermissionGuidancePlan.make(
            availability: .init(accessibility: true, inputMonitoring: false),
            trigger: .manual,
            automaticGuideAlreadyShown: true
        )

        XCTAssertTrue(plan.showInputMonitoringGuide)
        XCTAssertFalse(plan.markAutomaticGuideAsShown)
    }

    func testManualCheckOpensAccessibilityWhenItIsOnlyMissingPermission() {
        let plan = PermissionGuidancePlan.make(
            availability: .init(accessibility: false, inputMonitoring: true),
            trigger: .manual,
            automaticGuideAlreadyShown: true
        )

        XCTAssertTrue(plan.requestAccessibility)
        XCTAssertTrue(plan.openAccessibilitySettings)
        XCTAssertFalse(plan.showInputMonitoringGuide)
    }

    func testReadyPermissionsDoNotOpenGuidance() {
        let plan = PermissionGuidancePlan.make(
            availability: .init(accessibility: true, inputMonitoring: true),
            trigger: .manual,
            automaticGuideAlreadyShown: false
        )

        XCTAssertTrue(plan.permissionsReady)
        XCTAssertFalse(plan.requestAccessibility)
        XCTAssertFalse(plan.openAccessibilitySettings)
        XCTAssertFalse(plan.showInputMonitoringGuide)
    }
}
