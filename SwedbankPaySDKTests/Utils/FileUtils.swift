import Foundation
import XCTest

enum FileUtils {
    private static var emptyBuffer: Void = ()
    private static func openData(_ content: Data) throws -> UnsafeMutablePointer<FILE> {
        try content.withUnsafeBytes {
            let size = $0.count
            XCTAssert(size > 0)
            let file = try XCTUnwrap(fmemopen(nil, size, "rb+"))
            XCTAssertEqual(fwrite($0.baseAddress, size, 1, file), 1)
            rewind(file)
            return file
        }
    }
    
    static func openString(_ content: String) throws -> UnsafeMutablePointer<FILE> {
        let data = try XCTUnwrap(content.data(using: .utf8))
        return try openData(data)
    }
    
    static func factory(_ content: String) -> () -> UnsafeMutablePointer<FILE>? {
        return {
            try? openString(content)
        }
    }
}
