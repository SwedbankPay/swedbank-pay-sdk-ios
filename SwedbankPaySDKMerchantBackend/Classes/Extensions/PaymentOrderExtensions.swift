//
// Copyright 2021 Swedbank AB
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import SwedbankPaySDK

public extension SwedbankPaySDK.PaymentOrderUrls {
    /// Convenience initializer that generates a set of urls
    /// for a payment using `MerchantBackendConfiguration`
    ///  - parameter configuration: the MerchantBackendConfiguration where this payment is to be used
    ///  - parameter language: the language of the payment
    ///  - parameter callbackUrl: the callbackUrl to set for the payment
    ///  - parameter termsOfServiceUrl: the Terms of Service url of the payment
    ///  - parameter identifier: an unique identifier that is used to identify this payment **inside this application**
    init(
        configuration: SwedbankPaySDK.MerchantBackendConfiguration,
        language: SwedbankPaySDK.Language,
        callbackUrl: URL? = nil,
        termsOfServiceUrl: URL? = nil,
        identifier: String = UUID().uuidString
    ) {
        self.init(
            configuration: configuration,
            language: language,
            hostUrl: configuration.backendUrl,
            callbackUrl: callbackUrl,
            termsOfServiceUrl: termsOfServiceUrl,
            identifier: identifier
        )
    }
    
    /// Convenience initializer that generates a set of urls
    /// for a payment using `MerchantBackendConfiguration`
    ///  - parameter configuration: the MerchantBackendConfiguration where this payment is to be used
    ///  - parameter language: the language of the payment
    ///  - parameter hostUrl: the url to set in the hostUrls of the payment.
    ///   This will also become the `webViewBaseURL` of the `ViewPaymentOrderInfo` created for this payment
    ///  - parameter callbackUrl: the callbackUrl to set for the payment
    ///  - parameter termsOfServiceUrl: the Terms of Service url of the payment
    ///  - parameter identifier: an unique identifier that is used to identify this payment **inside this application**
    init(
        configuration: SwedbankPaySDK.MerchantBackendConfiguration,
        language: SwedbankPaySDK.Language,
        hostUrl: URL,
        callbackUrl: URL? = nil,
        termsOfServiceUrl: URL? = nil,
        identifier: String = UUID().uuidString
    ) {
        self.init(
            hostUrls: [hostUrl],
            completeUrl: SwedbankPaySDK.PaymentOrderUrls.buildCompleteUrl(configuration: configuration),
            cancelUrl: SwedbankPaySDK.PaymentOrderUrls.buildCancelUrl(configuration: configuration),
            paymentUrl: SwedbankPaySDK.PaymentOrderUrls.buildPaymentUrl(configuration: configuration, language: language, id: identifier),
            callbackUrl: callbackUrl,
            termsOfServiceUrl: termsOfServiceUrl
        )
    }
}

private extension SwedbankPaySDK.PaymentOrderUrls {
    private static func buildCompleteUrl(configuration: SwedbankPaySDK.MerchantBackendConfiguration) -> URL {
        return URL(string: "complete", relativeTo: configuration.backendUrl)!
    }
    private static func buildCancelUrl(configuration: SwedbankPaySDK.MerchantBackendConfiguration) -> URL {
        return URL(string: "cancel", relativeTo: configuration.backendUrl)!
    }
    private static func buildPaymentUrl(configuration: SwedbankPaySDK.MerchantBackendConfiguration, language: SwedbankPaySDK.Language, id: String) -> URL {
        var components = URLComponents()
        components.path = "sdk-callback/ios-universal-link"
        var queryItems: [URLQueryItem] = [
            .init(name: "scheme", value: configuration.callbackScheme),
            .init(name: "language", value: language.rawValue),
            .init(name: "id", value: id)
        ]
        if let appName = getAppName() {
            queryItems.append(.init(name: "app", value: appName))
        }
        components.queryItems = queryItems
        return components.url(relativeTo: configuration.backendUrl)!
    }
    private static func getAppName() -> String? {
        let bundle = Bundle.main
        let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        return displayName ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
    }
}
