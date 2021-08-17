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
import SwedbankPaySDK

public extension SwedbankPaySDK {
    ///
    /// Additional utilities supported by the Merchant Backend
    ///
    enum MerchantBackend {
        /// Retrieves the payment tokens owned by the given
        /// payerReference.
        ///
        /// Your backend must enable this functionality separately.
        ///
        /// - parameter configuration: the backend configuration
        /// - parameter payerReference: the reference to query
        /// - parameter extraHeaders: any headers you wish to append to the request
        /// - parameter completion: when the request completes, this is called with the result
        /// - returns: a handle that you can use to cancel the request
        public static func getPayerOwnedPaymentTokens(
            configuration: MerchantBackendConfiguration,
            payerReference: String,
            extraHeaders: [String: String]? = nil,
            completion: @escaping (Result<PayerOwnedPaymentTokensResponse, Error>) -> Void
        ) -> SwedbankPaySDKRequest? {
            var url = configuration.backendUrl
            url.appendPathComponent("payers", isDirectory: true)
            url.appendPathComponent(payerReference, isDirectory: true)
            url.appendPathComponent("paymentTokens", isDirectory: false)
                        
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
                    completion(result.mapError { $0 as Error })
                }
            )
        }
        
        /// Deletes the specified payment token.
        ///
        /// Your backend must enable this functionality separately.
        /// After you make this request, you should refresh your local list of tokens.
        ///
        /// - parameter configuration: the backend configuration
        /// - parameter paymentToken: the token to delete
        /// - parameter comment: the reason for the deletion
        /// - parameter extraHeaders: any headers you wish to append to the request
        /// - parameter completion: when the request completes, this is called with the result
        /// - returns: a handle that you can use to cancel the request
        public static func deletePayerOwnerPaymentToken(
            configuration: MerchantBackendConfiguration,
            paymentToken: PaymentTokenInfo,
            comment: String,
            extraHeaders: [String: String]? = nil,
            completion: @escaping (Result<Void, Error>) -> Void
        ) -> SwedbankPaySDKRequest? {
            guard let link = paymentToken.mobileSDK?.delete else {
                DispatchQueue.main.async {
                    completion(.failure(
                        SwedbankPaySDK.MerchantBackendError.missingRequiredOperation("delete-paymenttokens")
                    ))
                }
                return nil
            }
            return link.patch(api: configuration.api, comment: comment, extraHeaders: extraHeaders) {
                let result: Result<Void, Error>
                switch $0 {
                case .success: result = .success(())
                case .failure(let error): result = .failure(error)
                }
                completion(result)
            }
        }
    }
}
