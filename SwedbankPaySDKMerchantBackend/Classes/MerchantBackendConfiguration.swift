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
    static let setInstrumentLink = "set-instrument"
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
                        
                        //set instrument is a link that we need, how is it constructed?
                        let instrument: Instrument?
                        let availableInstruments: [Instrument]?
                        //setInstrument is always nil in V3
                        let setInstrument: SetInstrumentLink? = paymentOrderIn.mobileSDK?.setInstrument
                        if isV3 {
                            // Instead of building all operations individually, bring them into the linkInfo and build what we need
                            // but we need instrument, and populate the user info with the set instrument.
                            availableInstruments = paymentOrderIn.paymentOrder?.availableInstruments
                            if let currentInstrument = paymentOrder.instrument, availableInstruments?.contains(currentInstrument) ?? false {
                                instrument = currentInstrument
                            } else {
                                instrument = nil
                            }
                        } else {
                            //In v2 it was a special feature only available to some
                            availableInstruments = setInstrument != nil
                                ? paymentOrderIn.paymentOrder?.availableInstruments
                                : nil
                            instrument = availableInstruments != nil
                                ? paymentOrderIn.paymentOrder?.instrument
                                : nil
                        }
                        
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
                            userInfo: setInstrument,
                            operations: paymentOrderIn.operations
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
            options: VersionOptions,
            userData: Any?,
            viewPaymentOrderInfo: SwedbankPaySDK.ViewPaymentLinkInfo,
            updateInfo: Any,
            completion: @escaping (Result<SwedbankPaySDK.ViewPaymentLinkInfo, Error>
            ) -> Void
        ) -> SwedbankPaySDKRequest? {
            
            if let instrument = updateInfo as? SwedbankPaySDK.Instrument {
                return updatePayment(with: instrument, paymentOrder: paymentOrder, options: options, userData: userData, viewPaymentOrderInfo: viewPaymentOrderInfo, completion: completion)
            }
            else {
                fatalError("Invalid updateInfo: \(updateInfo) (expected SwedbankPaySDK.Instrument)")
            }
        }
        
        public func updatePayment(with instrument: SwedbankPaySDK.Instrument,
            paymentOrder: SwedbankPaySDK.PaymentOrder?,
            options: VersionOptions,
            userData: Any?,
            viewPaymentOrderInfo: SwedbankPaySDK.ViewPaymentLinkInfo,
            completion: @escaping (Result<SwedbankPaySDK.ViewPaymentLinkInfo, Error>
            ) -> Void
        ) -> SwedbankPaySDKRequest? {
            
            // when using v3 we have setInstrumentLink inside the operations array
            if options.contains(.isV3),
                let operation = viewPaymentOrderInfo.operations?.findOperation(rel: .setInstrumentLink),
                let href = operation.url {
                
                return SetInstrumentOperation(href: href).patch(api: api, url: backendUrl.appendingPathComponent("patch"), instrument: instrument, userData: userData) {
                    do {
                        let paymentOrderIn = try $0.get()
                        var newInfo = viewPaymentOrderInfo
                        if let viewPaymentLink = paymentOrderIn.operations.findOperation(rel: .viewPaymentLink)?.url {
                            newInfo.viewPaymentLink = viewPaymentLink
                        }
                        
                        if let availableInstruments = paymentOrderIn.paymentOrder?.availableInstruments {
                            newInfo.availableInstruments = availableInstruments
                        }
                        
                        newInfo.instrument = paymentOrderIn.paymentOrder?.instrument ?? instrument
                        newInfo.operations = paymentOrderIn.operations
                        
                        completion(.success(newInfo))
                    } catch let error {
                        if case MerchantBackendError.networkError(AFError.explicitlyCancelled) = error {
                            // no callback after cancellation
                        } else {
                            completion(.failure(error))
                        }
                    }
                }
            }
            
            //in V2 we used userInfo to store the instrumentLink
            guard let link = viewPaymentOrderInfo.userInfo as? SetInstrumentLink else {
                completion(.failure(SwedbankPaySDK.MerchantBackendError.paymentNotInInstrumentMode))
                return nil
            }
            
            let request = link.patch(api: self.api, instrument: instrument, userData: userData) {
                do {
                    let paymentOrderIn = try $0.get()
                    
                    var newInfo = viewPaymentOrderInfo
                    
                    // supporting v2
                    if viewPaymentOrderInfo.isV3 == false, let viewPaymentorder = paymentOrderIn.operations.find(
                        rel: OperationRel.viewPaymentOrder
                    ) {
                        newInfo.viewPaymentLink = viewPaymentorder
                    }
                    else if viewPaymentOrderInfo.isV3, let viewPaymentLink = paymentOrderIn.operations.find(
                        rel: OperationRel.viewPaymentLink
                    ) {
                        // regular v3
                        newInfo.viewPaymentLink = viewPaymentLink
                    }
                    
                    if let availableInstruments = paymentOrderIn.paymentOrder?.availableInstruments {
                        newInfo.availableInstruments = availableInstruments
                    }
                    
                    newInfo.instrument = paymentOrderIn.paymentOrder?.instrument ?? instrument
                    
                    //V2 uses a mobileSDK property, but in V3 we get the instrument link from the operation array.
                    if let setInstrument = paymentOrderIn.mobileSDK?.setInstrument {
                        newInfo.userInfo = setInstrument
                    } else if let instrumentURL = paymentOrderIn.operations.find(rel: OperationRel.setInstrumentLink) {
                        newInfo.userInfo = SetInstrumentLink(href: instrumentURL)
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
        
        public func abortPayment(
            paymentInfo: SwedbankPaySDK.ViewPaymentLinkInfo,
            userData: Any?,
            completion: @escaping (Result<Void, Error>) -> Void
        ) {
            guard let operation = AbortPaymentOperation.create(paymentInfo: paymentInfo) else {
                completion(.failure(MerchantBackendError.missingRequiredOperation("abort operation is missing from paymentInfo")))
                return
            }
            _ = operation.patch(api: api, url: backendUrl.appendingPathComponent("patch"), userData: userData) { result in
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
            
            return expandPayer(configuration: self, paymentOrderId: paymentId, extraHeaders: nil) { (result: Result<EmptyJsonResponse, SwedbankPaySDK.MerchantBackendError>) in
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
        
        private struct ExpandBody: Encodable {
            let resource: String
            let expand: String
        }
        
        public func expandPayer<T:Decodable>(
            configuration: MerchantBackendConfiguration,
            paymentOrderId: String,
            extraHeaders: [String: String]? = nil,
            completion: @escaping (Result<T, SwedbankPaySDK.MerchantBackendError>) -> Void
        ) -> SwedbankPaySDKRequest? {
            var url = configuration.backendUrl
            url.appendPathComponent("expand")
            
            let body = ExpandBody(resource: paymentOrderId, expand: "payer")
            return configuration.api.request(
                method: .post,
                url: url,
                body: body,
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
