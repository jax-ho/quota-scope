import XCTest
@testable import CodexWatcherCore

final class CodexWidgetLayoutMetricsTests: XCTestCase {
    func testSmallWidgetLayoutFitsSystemHeight() {
        XCTAssertLessThanOrEqual(
            CodexWidgetLayoutMetrics.smallEstimatedContentHeight,
            CodexWidgetLayoutMetrics.smallSystemHeight
        )
    }

    func testMediumWidgetLayoutFitsSystemHeight() {
        XCTAssertLessThanOrEqual(
            CodexWidgetLayoutMetrics.mediumEstimatedContentHeight,
            CodexWidgetLayoutMetrics.mediumSystemHeight
        )
    }
}
