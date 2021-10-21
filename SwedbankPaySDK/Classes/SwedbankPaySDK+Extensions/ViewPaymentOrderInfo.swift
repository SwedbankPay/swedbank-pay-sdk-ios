//
// Copyright 2020 Swedbank AB
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

public extension SwedbankPaySDK {
    /// Data required to show the payment menu.
    ///
    /// If you provide a custom SwedbankPayConfiguration
    /// you must get the relevant data from your services
    /// and supply a ViewPaymentOrderInfo
    /// in your SwedbankPayConfiguration.postPaymentorders
    /// completion call.
    struct ViewPaymentOrderInfo {
        /// The url to use as the WKWebView page url
        /// when showing the payment menu.
        ///
        /// This should match your payment order's `hostUrls`.
        public var webViewBaseURL: URL?
        
        /// The `view-paymentorder` link from Swedbank Pay.
        public var viewPaymentorder: URL
        
        /// The `completeUrl` of the payment order
        ///
        /// This url will not be opened in normal operation,
        /// so it need not point to an actual web page,
        /// but it must be a valid url and it must be distinct
        /// form the other urls.
        public var completeUrl: URL

        /// The `cancelUrl` of the payment order
        ///
        /// This url will not be opened in normal operation,
        /// so it need not point to an actual web page,
        /// but it must be a valid url and it must be distinct
        /// form the other urls.
        public var cancelUrl: URL?

        /// The `paymentUrl` of the payment order
        ///
        /// The `paymentUrl` you set for your payment order must be a
        /// Universal Link to your app. When your app receives it in the
        /// `UIApplicationDelegate.application(_:continue:restorationHandler:)`
        /// method, you must forward it to the SDK by calling
        /// `SwedbankPaySDK.continue(userActivity:)`. If it is helpful for your
        /// systems, you may add extra query parameters to the `paymentUrl`;
        /// the SDK will ignore these when checking for equality to an ongoing
        /// payment's `paymentUrl` (the Merchant Backend example does this
        /// to work around a scenario where Universal Links are not routed
        /// the way we would wish on iOS 13.3 and below).
        ///
        /// Additionally, if your `paymentUrl` is opened in the browser, it must
        /// ultimately open a url that is otherwise equal to the `paymentUrl`, but
        /// it has the `callbackScheme` of your `SwedbankPaySDKConfiguration`.
        /// It may also have additional query parameters, similar to the above.
        /// When you receive this url in your
        /// `UIApplicationDelegate(_:open:options:)` method, you must
        /// forward it to the SDK by calling `SwedbankPaySDK.open(url:)`
        ///
        /// Example
        /// =======
        ///
        /// When using the `MerchantBackendConfiguration` and the
        /// related convenience constructors of `SwedbankPaySDK.PaymentOrderUrls`,
        /// the actual `paymentUrl`, i.e. this value, will look like this:
        ///  - https://example.com/sdk-callback/ios-universal-link?scheme=fallback&language=en-US&id=1234
        ///
        /// Your `UIApplicationDelegate.application(_:continue:restorationHandler:)`
        /// can be called either with that url; or if the page was opened in the browser, the
        /// call will have an extra parameter (this is added by the backend to prevent an infinite loop):
        ///  - https://example.com/sdk-callback/ios-universal-link?scheme=fallback&language=en-US&id=1234&fallback=true
        ///
        /// If neither of the above urls is routed to your app (perhaps because of a broken
        /// Universal Link configuration), then the page in the brower will instead open
        /// a url equal to the second one, with the scheme replaced. You will then receive
        /// an url in your `UIApplicationDelegate(_:open:options:)` method
        /// that looks like this:
        ///  - fallback://example.com/sdk-callback/ios-universal-link?scheme=fallback&language=en-US&id=1234&fallback=true
        public var paymentUrl: URL?

        /// The `termsOfServiceUrl` of the payment order
        ///
        /// By default, this url will be opened when the user
        /// taps on the Terms of Service link.
        /// You can override that behaviour in your
        /// `SwedbankPaySDKDelegate`.
        public var termsOfServiceUrl: URL?
        
        /// If the payment order is in instrument mode, the current instrument
        ///
        /// The SDK does not use this property for anything, so you need not set
        /// a value even if you are using instrument mode. But if you are implementing
        /// instrument mode payments, it is probably helpful if you set
        /// a value here. `MerchantBackendConfiguration` sets this property
        /// and `validInstruments` if the payment order it creates is in instrument mode.
        public var instrument: Instrument?
        
        /// If the payment order is in instrument mode, all the valid instruments for it
        ///
        /// The SDK does not use this property for anything, so you need not set
        /// a value even if you are using instrument mode. But if you are implementing
        /// instrument mode payments, it is probably helpful if you set
        /// a value here. `MerchantBackendConfiguration` sets this property
        /// and `instrument` if the payment order it creates is in instrument mode.
        public var availableInstruments: [Instrument]?
        
        /// Any data you need for the proper functioning of your `SwedbankPaySDKConfiguration`.
        public var userInfo: Any?

        public init(
            webViewBaseURL: URL?,
            viewPaymentorder: URL,
            completeUrl: URL,
            cancelUrl: URL?,
            paymentUrl: URL?,
            termsOfServiceUrl: URL?,
            instrument: Instrument? = nil,
            availableInstruments: [Instrument]? = nil,
            userInfo: Any? = nil
        ) {
            self.webViewBaseURL = webViewBaseURL
            self.viewPaymentorder = viewPaymentorder
            self.completeUrl = completeUrl
            self.cancelUrl = cancelUrl
            self.paymentUrl = paymentUrl
            self.termsOfServiceUrl = termsOfServiceUrl
            self.instrument = instrument
            self.availableInstruments = availableInstruments
            self.userInfo = userInfo
        }
    }
}

extension SwedbankPaySDK.ViewPaymentOrderInfo: Codable {
    private enum CodingKeys: String, CodingKey {
        case webViewBaseURL
        case viewPaymentorder
        case completeUrl
        case cancelUrl
        case paymentUrl
        case termsOfServiceUrl
        case instrument
        case availableInstruments
        case codableUserInfoType
        case userInfo
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            webViewBaseURL: container.decodeIfPresent(URL.self, forKey: .webViewBaseURL),
            viewPaymentorder: container.decode(URL.self, forKey: .viewPaymentorder),
            completeUrl: container.decode(URL.self, forKey: .completeUrl),
            cancelUrl: container.decodeIfPresent(URL.self, forKey: .cancelUrl),
            paymentUrl: container.decodeIfPresent(URL.self, forKey: .paymentUrl),
            termsOfServiceUrl: container.decodeIfPresent(URL.self, forKey: .termsOfServiceUrl),
            instrument: container.decodeIfPresent(SwedbankPaySDK.Instrument.self, forKey: .instrument),
            availableInstruments: container.decodeIfPresent([SwedbankPaySDK.Instrument].self, forKey: .availableInstruments),
            userInfo: container.decodeUserDataIfPresent(codableTypeKey: .codableUserInfoType, valueKey: .userInfo)
        )
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(webViewBaseURL, forKey: .webViewBaseURL)
        try container.encode(viewPaymentorder, forKey: .viewPaymentorder)
        try container.encode(completeUrl, forKey: .completeUrl)
        try container.encodeIfPresent(cancelUrl, forKey: .cancelUrl)
        try container.encodeIfPresent(paymentUrl, forKey: .paymentUrl)
        try container.encodeIfPresent(termsOfServiceUrl, forKey: .termsOfServiceUrl)
        try container.encodeIfPresent(instrument, forKey: .instrument)
        try container.encodeIfPresent(availableInstruments, forKey: .availableInstruments)
        try container.encodeIfPresent(userData: userInfo, codableTypeKey: .codableUserInfoType, valueKey: .userInfo)
    }
}
