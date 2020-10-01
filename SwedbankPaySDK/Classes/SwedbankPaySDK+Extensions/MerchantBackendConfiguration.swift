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
import WebKit
import Alamofire

private let callbackURLTypeKey = "com.swedbank.SwedbankPaySDK.callback"

public extension SwedbankPaySDK {
    /// A SwedbankPaySDKConfiguration for integrating with a backend
    /// implementing the Merchant Backend API.
    struct MerchantBackendConfiguration: SwedbankPaySDKConfiguration {
        internal let api: MerchantBackendApi
        internal let rootLink: RootLink
        
        /// The url of the Merchant Backend
        public var backendUrl: URL {
            rootLink.href
        }
        public let callbackScheme: String
        
        let additionalAllowedWebViewRedirects: [WebViewRedirect]?
        
        /// Initializer for `SwedbankPaySDK.Configuration`
        /// - parameter backendUrl: backend URL
        /// - paramerer callbackScheme: A custom scheme for callback urls. This scheme must be registered to your app.
        ///                             If nil, the Info.plist will be searched for a URL type
        ///                             with a com.swedbank.SwedbankPaySDK.callback property having
        ///                             a Boolean type and a YES value.
        /// - parameter headers: HTTP Request headers Dictionary in a form of 'apikey, access token' -pair
        /// - parameter domainWhitelist: Optional array of domains allowed to be connected to; defaults to `backendURL` if nil
        /// - parameter certificatePins: Optional array of domains for certification pinning, matched against any certificate found anywhere in the app bundle
        public init(
            backendUrl: URL,
            callbackScheme: String? = nil,
            headers: [String: String]?,
            domainWhitelist: [WhitelistedDomain]? = nil,
            pinPublicKeys: [PinPublicKeys]? = nil,
            additionalAllowedWebViewRedirects: [WebViewRedirect]? = nil
        ) {
            let session = MerchantBackendConfiguration.makeSession(pinPublicKeys: pinPublicKeys)
            self.init(
                session: session,
                backendUrl: backendUrl,
                callbackScheme: callbackScheme,
                headers: headers,
                domainWhitelist: domainWhitelist,
                additionalAllowedWebViewRedirects: additionalAllowedWebViewRedirects
            )
        }
        
        internal init(
            session: Alamofire.Session,
            backendUrl: URL,
            callbackScheme: String?,
            headers: [String: String]?,
            domainWhitelist: [WhitelistedDomain]?,
            additionalAllowedWebViewRedirects: [WebViewRedirect]?
        ) {
            api = MerchantBackendApi(
                session: session,
                domainWhitelist: MerchantBackendConfiguration.makeDomainWhitelist(
                    backendUrl: backendUrl, domainWhitelist: domainWhitelist
                ),
                requestDecorator: headers.map(SimpleRequestDecorator.init(headers:))
            )
            rootLink = RootLink(href: backendUrl)
            
            self.callbackScheme = callbackScheme ?? MerchantBackendConfiguration.getDefaultCallbackScheme()
            self.additionalAllowedWebViewRedirects = additionalAllowedWebViewRedirects
        }
        
        private static func makeSession(pinPublicKeys: [PinPublicKeys]?) -> Session {
            if let pinPublicKeys = pinPublicKeys, !pinPublicKeys.isEmpty {
                var pinEvaluators: [String: PublicKeysTrustEvaluator] = [:]
                for certificate in pinPublicKeys {
                    pinEvaluators[certificate.pattern] = PublicKeysTrustEvaluator(
                        keys: certificate.publicKeys,
                        performDefaultValidation: true,
                        validateHost: true
                    )
                }
                return Session(
                    configuration: URLSessionConfiguration.default,
                    serverTrustManager: ServerTrustManager(
                        evaluators: pinEvaluators
                    )
                )
            } else {
                return Session()
            }
        }
        
        private static func makeDomainWhitelist(
            backendUrl: URL,
            domainWhitelist: [WhitelistedDomain]?
        ) -> [WhitelistedDomain] {
            if let domainWhitelist = domainWhitelist, !domainWhitelist.isEmpty {
                return domainWhitelist
            } else {
                let domain = WhitelistedDomain.init(
                    domain: backendUrl.host,
                    includeSubdomains: true
                )
                return [domain]
            }
        }
        
        private static func getDefaultCallbackScheme() -> String {
            let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [Any]
            let urlTypeDicts = urlTypes?.lazy.compactMap { $0 as? [AnyHashable: Any] }
            guard let callbackUrlType = urlTypeDicts?.filter({
                $0[callbackURLTypeKey] as? Bool == true
            }).first else {
                fatalError("Unable to infer callback scheme: No URL type marked as Swedbank Pay callback. Please add a URL type with a unique name, a single unique scheme, and an additional property with the key \(callbackURLTypeKey), type Boolean, and value YES")
            }
            guard let schemes = callbackUrlType["CFBundleURLSchemes"] as? [Any],
                schemes.count == 1,
                let scheme = schemes[0] as? String
                else {
                    fatalError("Unable to infer callback scheme: URL type marked as Swedbank Pay SDK callback does not have exactly one scheme: \(callbackUrlType)")
            }
            return scheme
        }
                
        private func withTopLevelResources<T>(
            _ onFailure: @escaping (Result<T, Error>) -> Void,
            f: @escaping (TopLevelResources) -> Void
        ) {
            rootLink.get(api: api) {
                switch $0 {
                case .success(let topLevelResources):
                    f(topLevelResources)
                case .failure(let error):
                    onFailure(.failure(error))
                }
            }
        }
        
        public func postConsumers(
            consumer: SwedbankPaySDK.Consumer?,
            userData: Any?,
            completion: @escaping (Result<SwedbankPaySDK.ViewConsumerIdentificationInfo, Error>) -> Void
        ) {
            guard let consumer = consumer else {
                fatalError("MerchantBackendConfiguration requires use of Consumer for checkin")
            }
            withTopLevelResources(completion) { topLevelResources in
                topLevelResources.consumers.post(
                    api: self.api,
                    consumer: consumer,
                    userData: userData
                ) {
                    do {
                        let viewConsumerIdentification = try $0.get().requireOperation(
                            rel: Operation.TypeString.viewConsumerIdentification.rawValue
                        )
                        let info = ViewConsumerIdentificationInfo(
                            webViewBaseURL: self.backendUrl,
                            viewConsumerIdentification: viewConsumerIdentification
                        )
                        completion(.success(info))
                    } catch let error {
                        completion(.failure(error))
                    }
                }
            }
        }
        
        public func postPaymentorders(
            paymentOrder: SwedbankPaySDK.PaymentOrder?,
            userData: Any?,
            consumerProfileRef: String?,
            completion: @escaping (Result<SwedbankPaySDK.ViewPaymentOrderInfo, Error>) -> Void
        ) {
            guard var paymentOrder = paymentOrder else {
                fatalError("MerchantBackendConfiguration requires use of PaymentOrder")
            }
            if let consumerProfileRef = consumerProfileRef {
                paymentOrder.payer = .init(consumerProfileRef: consumerProfileRef)
            }
            withTopLevelResources(completion) { topLevelResources in
                topLevelResources.paymentorders.post(
                    api: self.api,
                    paymentOrder: paymentOrder,
                    userData: userData
                ) {
                    do {
                        let viewPaymentorder = try $0.get().requireOperation(
                            rel: Operation.TypeString.viewPaymentOrder.rawValue
                        )
                        let info = ViewPaymentOrderInfo(
                            webViewBaseURL: paymentOrder.urls.hostUrls.first ?? self.backendUrl,
                            viewPaymentorder: viewPaymentorder,
                            completeUrl: paymentOrder.urls.completeUrl,
                            cancelUrl: paymentOrder.urls.cancelUrl,
                            paymentUrl: paymentOrder.urls.paymentUrl,
                            termsOfServiceUrl: paymentOrder.urls.termsOfServiceUrl
                        )
                        completion(.success(info))
                    } catch let error {
                        completion(.failure(error))
                    }
                }
            }
        }
        
        public func decidePolicyForPaymentMenuRedirect(
            navigationAction: WKNavigationAction,
            completion: @escaping (SwedbankPaySDK.PaymentMenuRedirectPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                completion(.openInWebView)
                return
            }
            let allowedByUser = additionalAllowedWebViewRedirects?.contains(
                where: { $0.allows(url: url) }
            ) == true
            if allowedByUser {
                completion(.openInWebView)
            } else {
                urlMatchesListOfGoodRedirects(url) { matches in
                    completion(matches ? .openInWebView : .openInBrowser)
                }
            }
        }
    }
}
