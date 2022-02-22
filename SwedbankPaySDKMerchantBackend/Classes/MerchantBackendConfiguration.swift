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
import SwedbankPaySDK
import Alamofire

private let callbackURLTypeKey = "com.swedbank.SwedbankPaySDK.callback"

private enum OperationRel {
    static let viewConsumerIdentification = "view-consumer-identification"
    static let viewPaymentOrder = "view-paymentorder"
    static let viewPaymentLink = "view-checkout"
}

private extension Array where Element == SwedbankPaySDK.Operation {
    func find(rel: String) -> URL? {
        let operation = first { $0.rel == rel }
        let href = (operation?.href).flatMap(URL.init(string:))
        return href
    }
    
    func require(rel: String) throws -> URL {
        guard let href = find(rel: rel) else {
            throw SwedbankPaySDK.MerchantBackendError.missingRequiredOperation(rel)
        }
        return href
    }
}

public extension SwedbankPaySDK {
    /// A SwedbankPaySDKConfiguration for integrating with a backend
    /// implementing the Merchant Backend API.
    ///
    /// When using this configuration, you can use `updatePaymentOrder`
    /// to set the instrument of an instrument mode payment by calling
    /// it with the desired instrument,
    /// e.g. `updatePaymentOrder(updateInfo: SwedbankPaySDK.Instrument.creditCard)`.
    struct MerchantBackendConfiguration: SwedbankPaySDKConfiguration {
        
        internal let api: MerchantBackendApi
        internal let rootLink: RootLink
        
        /// The url of the Merchant Backend
        public var backendUrl: URL {
            rootLink.href
        }
        public let callbackScheme: String
        
        @available(*, deprecated, message: "no longer used")
        var additionalAllowedWebViewRedirects: [WebViewRedirect]? {
            return nil
        }
        
        /// Initializer for `SwedbankPaySDK.MerchantBackendConfiguration`
        /// - parameter backendUrl: backend URL
        /// - parameter callbackScheme: A custom scheme for callback urls. This scheme must be registered to your app.
        ///                             If nil, the Info.plist will be searched for a URL type
        ///                             with a com.swedbank.SwedbankPaySDK.callback property having
        ///                             a Boolean type and a YES value.
        /// - parameter headers: HTTP Request headers Dictionary in a form of 'apikey, access token' -pair
        /// - parameter domainWhitelist: Optional array of domains allowed to be connected to;
        ///  defaults to `backendURL` if nil
        /// - parameter pinPublicKeys: Optional array of domains for certification pinning,
        ///  matched against any certificate found anywhere in the app bundle
        public init(
            backendUrl: URL,
            callbackScheme: String? = nil,
            headers: [String: String]?,
            domainWhitelist: [WhitelistedDomain]? = nil,
            pinPublicKeys: [PinPublicKeys]? = nil
        ) {
            let session = MerchantBackendConfiguration.makeSession(pinPublicKeys: pinPublicKeys)
            self.init(
                session: session,
                backendUrl: backendUrl,
                callbackScheme: callbackScheme,
                headers: headers,
                domainWhitelist: domainWhitelist
            )
        }
        
        @available(*, deprecated, message: "additionalAllowedWebViewRedirects is ignored")
        public init(
            backendUrl: URL,
            callbackScheme: String? = nil,
            headers: [String: String]?,
            domainWhitelist: [WhitelistedDomain]? = nil,
            pinPublicKeys: [PinPublicKeys]? = nil,
            additionalAllowedWebViewRedirects: [WebViewRedirect]? = nil
        ) {
            self.init(
                backendUrl: backendUrl,
                callbackScheme: callbackScheme,
                headers: headers,
                domainWhitelist: domainWhitelist,
                pinPublicKeys: pinPublicKeys
            )
        }

        
        internal init(
            session: Alamofire.Session,
            backendUrl: URL,
            callbackScheme: String?,
            headers: [String: String]?,
            domainWhitelist: [WhitelistedDomain]?
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
                        let viewConsumerIdentification = try $0.get().operations.require(
                            rel: OperationRel.viewConsumerIdentification
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
            options: SwedbankPaySDK.VersionOptions,
            completion: @escaping (Result<SwedbankPaySDK.ViewPaymentLinkInfo, Error>) -> Void
        ) {
            guard var paymentOrder = paymentOrder else {
                fatalError("MerchantBackendConfiguration requires use of PaymentOrder")
            }
            let isV3 = options.contains(.isV3)
            paymentOrder.isV3 = isV3
            
            if let consumerProfileRef = consumerProfileRef {
                paymentOrder.payer = .init(consumerProfileRef: consumerProfileRef)
            }
            else if options.contains([.useCheckin, .isV3]) {
                
                if paymentOrder.payer == nil {
                    // Asuming digital products if you have not supplied (for the starter integration requireConsumerInfo is always true)
                    paymentOrder.payer = .init(requireConsumerInfo: true)
                }
            } else if options.contains(.isV3) == false && paymentOrder.payer != nil {
                paymentOrder.payer = nil
            }
            withTopLevelResources(completion) { topLevelResources in
                topLevelResources.paymentorders.post(
                    api: self.api,
                    paymentOrder: paymentOrder,
                    userData: userData
                ) {
                    do {
                        let paymentOrderIn = try $0.get()
                        
                        let viewLink = try paymentOrderIn.operations.require(
                            rel: isV3 ? OperationRel.viewPaymentLink : OperationRel.viewPaymentOrder
                        )
                        let setInstrument = paymentOrderIn.mobileSDK?.setInstrument
                        let availableInstruments = setInstrument != nil
                            ? paymentOrderIn.paymentOrder?.availableInstruments
                            : nil
                        let instrument = availableInstruments != nil
                            ? paymentOrderIn.paymentOrder?.instrument
                            : nil
                        
                        let info = ViewPaymentLinkInfo(
                            paymentId: paymentOrderIn.paymentOrder?.id,
                            isV3: isV3,
                            webViewBaseURL: paymentOrder.urls.hostUrls.first ?? self.backendUrl,
                            viewPaymentLink: viewLink,
                            completeUrl: paymentOrder.urls.completeUrl,
                            cancelUrl: paymentOrder.urls.cancelUrl,
                            paymentUrl: paymentOrder.urls.paymentUrl,
                            termsOfServiceUrl: paymentOrder.urls.termsOfServiceUrl,
                            instrument: instrument,
                            availableInstruments: availableInstruments,
                            userInfo: setInstrument
                        )
                        completion(.success(info))
                    } catch let error {
                        
                        completion(.failure(error))
                    }
                }
            }
        }
        
        public func updatePaymentOrder(
            paymentOrder: SwedbankPaySDK.PaymentOrder?,
            userData: Any?,
            viewPaymenLinkInfo: SwedbankPaySDK.ViewPaymentLinkInfo,
            updateInfo: Any,
            completion: @escaping (Result<SwedbankPaySDK.ViewPaymentLinkInfo, Error>
            ) -> Void
        ) -> SwedbankPaySDKRequest? {
            guard let instrument = updateInfo as? SwedbankPaySDK.Instrument else {
                fatalError("Invalid updateInfo: \(updateInfo) (expected SwedbankPaySDK.Instrument)")
            }
            
            guard let link = viewPaymenLinkInfo.userInfo as? SetInstrumentLink else {
                completion(.failure(SwedbankPaySDK.MerchantBackendError.paymentNotInInstrumentMode))
                return nil
            }
            
            let request = link.patch(api: self.api, instrument: instrument, userData: userData) {
                do {
                    let paymentOrderIn = try $0.get()
                    
                    var newInfo = viewPaymenLinkInfo
                    
                    // supporting v2
                    if viewPaymenLinkInfo.isV3 == false, let viewPaymentorder = paymentOrderIn.operations.find(
                        rel: OperationRel.viewPaymentOrder
                    ) {
                        newInfo.viewPaymentLink = viewPaymentorder
                    }
                    else if viewPaymenLinkInfo.isV3, let viewPaymentLink = paymentOrderIn.operations.find(
                        rel: OperationRel.viewPaymentLink
                    ) {
                        // regular v3
                        newInfo.viewPaymentLink = viewPaymentLink
                    }
                    
                    if let availableInstruments = paymentOrderIn.paymentOrder?.availableInstruments {
                        newInfo.availableInstruments = availableInstruments
                    }
                    
                    newInfo.instrument = paymentOrderIn.paymentOrder?.instrument ?? instrument
                    
                    if let setInstrument = paymentOrderIn.mobileSDK?.setInstrument {
                        newInfo.userInfo = setInstrument
                    }
                    
                    completion(.success(newInfo))
                } catch let error {
                    if case MerchantBackendError.networkError(AFError.explicitlyCancelled) = error {
                        // no callback after cancellation
                    } else {
                        completion(.failure(error))
                    }
                }
            }
            return request
        }
        
        /// The configuration can handle any Codable type (you are free to expand it), the basic
        /// implementation just require any result. Then its up to you to present
        /// shipping options and update the paymentOrder accordingly.
        ///
        /// As you are in control of both the configuration and the update call, you can
        /// coordinate the actual type used here.
        public func expandPayerAfterIdentified(
            paymentInfo: SwedbankPaySDK.ViewPaymentLinkInfo,
            completion: @escaping (Result<Void, Error>) -> Void
        ) -> SwedbankPaySDKRequest? {
            
            guard let paymentId = paymentInfo.paymentId else {
                completion(.failure(MerchantBackendError.missingRequiredOperation("paymentInfo.paymentId is missing")))
                return nil
            }
            
            return getExpandPayer(configuration: self, paymentOrderId: paymentId, extraHeaders: nil) { (result: Result<EmptyJsonResponse, SwedbankPaySDK.MerchantBackendError>) in
                do {
                    
                    _ = try result.get()
                    completion(.success(()))
                } catch let error {
                    
                    if case MerchantBackendError.networkError(AFError.explicitlyCancelled) = error {
                        // no callback after cancellation
                    } else {
                        completion(.failure(error))
                    }
                }
            }
        }
        
        public func getExpandPayer<T:Decodable>(
            configuration: MerchantBackendConfiguration,
            paymentOrderId: String,
            extraHeaders: [String: String]? = nil,
            completion: @escaping (Result<T, SwedbankPaySDK.MerchantBackendError>) -> Void
        ) -> SwedbankPaySDKRequest? {
            var url = configuration.backendUrl
            url.appendPathComponent("payer")
            url.appendPathComponent(paymentOrderId)
                        
            return configuration.api.request(
                method: .get,
                url: url,
                body: nil as String?,
                decoratorCall: { _, request in
                    if let extraHeaders = extraHeaders {
                        for (key, value) in extraHeaders {
                            request.addValue(value, forHTTPHeaderField: key)
                        }
                    }
                },
                completion: { result in
                    completion(result.mapError { $0 as SwedbankPaySDK.MerchantBackendError })
                }
            )
        }
    }
}
