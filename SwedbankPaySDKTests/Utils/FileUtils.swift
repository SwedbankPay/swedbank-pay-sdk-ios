import Foundation
import XCTest

enum FileUtils {
    internal static var emptyBuffer: Void = ()
    internal static func openData(_ content: Data) throws -> UnsafeMutablePointer<FILE> {
        try content.withUnsafeBytes { buffer in
            let file = try XCTUnwrap(tmpfile())
            XCTAssertEqual(fwrite(buffer.baseAddress, buffer.count, 1, file), 1)
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
