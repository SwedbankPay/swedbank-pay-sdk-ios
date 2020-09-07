import XCTest
import Foundation
@testable import SwedbankPaySDK

class FileLinesTests: XCTestCase {
    private func checkThatFile(with content: String, parsesTo lines: String...) throws {
        let file = try FileUtils.openString(content)
        defer {
            fclose(file)
        }
        file.getLines().assertElementsEqual(lines)
    }
    
    func testItShouldAcceptSingleLine() throws {
        try checkThatFile(with: "line", parsesTo: "line")
    }
    
    func testItShouldAcceptFinalNewline() throws {
        try checkThatFile(with: "line\n", parsesTo: "line\n")
    }
    
    func testItShouldSplitIntoLines() throws {
        try checkThatFile(with: """
first
second
third
""", parsesTo: "first\n", "second\n", "third")
    }
    
    func testItShouldAcceptEmptyLines() throws {
        try checkThatFile(with: """
first

second

third

""", parsesTo: "first\n", "\n", "second\n", "\n", "third\n")
    }
    
    func testTrimmedResultsShouldMatchStringSplit() throws {
        let text = """
first
second

third

fourth


fifth
"""
        let file = try FileUtils.openString(text)
        defer {
            fclose(file)
        }
        
        let lines = file.getLines().lazy.map { $0.trimmingCharacters(in: .newlines) }
        let split = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        lines.assertElementsEqual(split)
    }
}

private extension Sequence where Element: Equatable {
    func assertElementsEqual(_ expectedElements: [Element]) {
        var iterator = self.makeIterator()
        var expectedIterator = expectedElements.makeIterator()
        var count = 0
        while let element = iterator.next() {
            if let expected = expectedIterator.next() {
                XCTAssertEqual(element, expected, "Unexpected element at index \(count).")
            }
            count += 1
        }
        let expectedCount = expectedElements.count
        XCTAssertEqual(count, expectedCount, "Wrong number of elements: \(count).")
    }
}
