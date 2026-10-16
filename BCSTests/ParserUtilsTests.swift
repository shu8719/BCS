import XCTest
@testable import BCS

final class ParserUtilsTests: XCTestCase {
    func testJobTitleMatchesWholeWordsOnly() {
        XCTAssertTrue(isJobTitleLine("sales manager"))
        XCTAssertTrue(isJobTitleLine("vice president, engineering"))
        XCTAssertTrue(isJobTitleLine("john smith, md"))

        XCTAssertFalse(isJobTitleLine("fred repton"))       // "rep" inside a surname
        XCTAssertFalse(isJobTitleLine("camden supplies"))   // "md" inside a word
        XCTAssertFalse(isJobTitleLine("salesforce tower"))  // "sales" inside a word
    }

    func testContactKeywordMatchesWholeWordsOnly() {
        XCTAssertTrue(containsContactKeyword("tel: 408-555-1234"))
        XCTAssertTrue(containsContactKeyword("e-mail"))
        XCTAssertTrue(containsContactKeyword("www.example.com"))
        XCTAssertTrue(containsContactKeyword("ext. 204"))

        XCTAssertFalse(containsContactKeyword("hans weber"))          // "web"
        XCTAssertFalse(containsContactKeyword("123 webster avenue"))  // "web"
        XCTAssertFalse(containsContactKeyword("extron"))              // "ext"
        XCTAssertFalse(containsContactKeyword("1 telford road"))      // "tel"
    }
}
