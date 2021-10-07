import SwedbankPaySDK
import XCTest

enum TestConfiguration {
    case merchantBackend
    
#if swift(>=5.5)
    @available(iOS 15.0, *)
    case async
#endif // swift(>=5.5)
}

extension TestConfiguration {
    func sdkConfiguration(for testCase: XCTestCase) -> SwedbankPaySDKConfiguration {
        switch self {
        case .merchantBackend:
            return MockMerchantBackend.configuration(for: testCase)
            
#if swift(>=5.5)
        case .async:
            if #available(iOS 15.0, *) {
                return AsyncTestConfiguration()
            } else {
                fatalError("\(self) is not available before iOS 15")
            }
#endif // swift(>=5.5)
            
        }
    }
}

extension TestConfiguration {
    static func getAsyncConfigOrSkipTest() throws -> TestConfiguration {
#if swift(>=5.5)
        if #available(iOS 15.0, *) {
            return .async
        }
#endif // swift(>=5.5)
        throw XCTSkip()
    }
}
