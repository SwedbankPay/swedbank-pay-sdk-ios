import Foundation
import XCTest
import Alamofire
import SwedbankPaySDK
@testable import SwedbankPaySDKMerchantBackend

enum MockMerchantBackend {}
extension MockMerchantBackend {
    static func backendUrl(for testCase: XCTestCase) -> URL {
        URL(string: "\(MockURLProtocol.scheme)://backendurl.invalid/\(testCase.name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!)/")!
    }
    static func absoluteConsumersUrl(for testCase: XCTestCase) -> URL {
        backendUrl(for: testCase).appendingPathComponent(TestConstants.consumersUrl)
    }
    static func absolutePaymentordersUrl(for testCase: XCTestCase) -> URL {
        backendUrl(for: testCase).appendingPathComponent(TestConstants.paymentordersUrl)
    }
    
    static func configuration(for testCase: XCTestCase) -> SwedbankPaySDK.MerchantBackendConfiguration {
        SwedbankPaySDK.MerchantBackendConfiguration(
            session: Session(configuration: MockURLProtocol.urlSessionConfiguration),
            backendUrl: backendUrl(for: testCase),
            callbackScheme: TestConstants.callbackScheme,
            headers: nil,
            domainWhitelist: nil
        )
    }
    
    static func paymentOrder(for testCase: XCTestCase) -> SwedbankPaySDK.PaymentOrder{
        
        SwedbankPaySDK.PaymentOrder(
            
            currency: "SEK",
            amount: 1,
            vatAmount: 0,
            description: "",
            urls: .init(configuration: configuration(for: testCase), language: .English, identifier: "test"),
            payer: .init(requireConsumerInfo: true, digitalProducts: false, shippingAddressRestrictedToCountryCodes: ["no"]
        )
    }
}
