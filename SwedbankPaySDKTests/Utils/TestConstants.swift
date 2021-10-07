import Foundation
import Alamofire
import SwedbankPaySDK
@testable import SwedbankPaySDKMerchantBackend

enum TestConstants {
    static let callbackScheme = "testcallback"
    static let consumersUrl = "consumersurl"
    static let paymentordersUrl = "paymentordersurl"
    
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
    
    static let consumerCountryCode = "SE"
    static let consumerData = SwedbankPaySDK.Consumer(shippingAddressRestrictedToCountryCodes: [consumerCountryCode])
    
    static let consumerProfileRef = "consumerProfileRef"
}
