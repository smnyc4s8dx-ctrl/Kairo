import XCTest
@testable import KairoCore

final class TimeIntervalFormatTests: XCTestCase {

    func testMMSSFormatsWholeSeconds() {
        XCTAssertEqual(TimeInterval(0).mmss, "0:00")
        XCTAssertEqual(TimeInterval(5).mmss, "0:05")
        XCTAssertEqual(TimeInterval(59).mmss, "0:59")
        XCTAssertEqual(TimeInterval(60).mmss, "1:00")
        XCTAssertEqual(TimeInterval(125).mmss, "2:05")
        XCTAssertEqual(TimeInterval(1500).mmss, "25:00")
        XCTAssertEqual(TimeInterval(3599).mmss, "59:59")
    }

    func testMMSSRoundsFractionalSecondsToNearest() {
        XCTAssertEqual(TimeInterval(59.4).mmss, "0:59")
        XCTAssertEqual(TimeInterval(59.6).mmss, "1:00")
        XCTAssertEqual(TimeInterval(0.4).mmss, "0:00")
        XCTAssertEqual(TimeInterval(0.5).mmss, "0:01")
    }
}
