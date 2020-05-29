import Foundation
import SwedbankPaySDK

enum TestConstants {
    static let callbackScheme = "testcallback"
    static let backendUrl = URL(string: "\(MockURLProtocol.scheme)://backendurl.invalid/")!
    static let consumersUrl = "consumersurl"
    static let absoluteConsumersUrl = URL(string: "\(MockURLProtocol.scheme)://backendurl.invalid/consumersurl")!
    static let paymentordersUrl = "paymentordersurl"
    static let absolutePaymentordersUrl = URL(string: "\(MockURLProtocol.scheme)://backendurl.invalid/paymentordersurl")!
    
    static let viewConsumerSessionLink = "data:,/*consumerLink*/"
    static let viewPaymentorderLink = "data:,/*paymentorderLink*/"
    
    static let rootBody = [
        "consumers": consumersUrl,
        "paymentorders": paymentordersUrl
    ]
    static let consumersBody = [
        "operations": [
            [
                "rel": "view-consumer-identification",
                "contentType": "application/javascript",
                "href": viewConsumerSessionLink
            ]
        ]
    ]
    static let paymentordersBody = [
        "operations": [
            [
                "rel": "view-paymentorder",
                "contentType": "application/javascript",
                "href": viewPaymentorderLink
            ]
        ]
    ]
    
    static let configuration = SwedbankPaySDK.Configuration(backendUrl: TestConstants.backendUrl, callbackScheme: callbackScheme, headers: [:])

    static let consumerCountryCode = "SE"
    static let consumerData = SwedbankPaySDK.Consumer(shippingAddressRestrictedToCountryCodes: [consumerCountryCode])
    
    static let consumerProfileRef = "consumerProfileRef"
    static let paymentOrder = SwedbankPaySDK.PaymentOrder(
        currency: "SEK",
        amount: 1,
        vatAmount: 0,
        description: "",
        urls: .init(configuration: configuration, language: .English)
    )
}
