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

#if swift(>=5.5)

import WebKit

@available(iOS 15.0, *)
extension Task: SwedbankPaySDKRequest {}

/// The `SwedbankPaySDKConfigurationAsync` protocol allows you to implement your
/// `SwedbankPaySDKConfiguration` in terms of `async` functions.
///
/// For each function in `SwedbankPaySDKConfiguration` that takes a completion callback,
/// `SwedbankPaySDKConfigurationAsync` contains a corresponding `async` function.
/// Implement these instead of the callback-taking ones.
///
/// E.g.
///
/// Legacy style:
///
/// ```
/// func postPaymentorders(
///     paymentOrder: SwedbankPaySDK.PaymentOrder?,
///     userData: Any?,
///     consumerProfileRef: String?,
///     completion: @escaping (Result<SwedbankPaySDK.ViewPaymentOrderInfo, Error>) -> Void
/// ) {
///     let task = URLSession.dataTask(with: url) { (data, _, error) in
///         if let error = error {
///             completion(.failure(error))
///         } else {
///             let viewPaymentOrderInfo = process(data)
///             completion(.success(viewPaymentOrderInfo))
///         }
///     }
///     task.resume()
/// }
/// ```
///
/// Async style:
///
/// ```
/// func postPaymentorders(
///     paymentOrder: SwedbankPaySDK.PaymentOrder?,
///     userData: Any?,
///     consumerProfileRef: String?
/// ) async throws -> SwedbankPaySDK.ViewPaymentOrderInfo {
///     let (data, _) = try await URLSession.data(from: url)
///     return process(data)
/// }
/// ```
@available(iOS 15.0.0, *)
public protocol SwedbankPaySDKConfigurationAsync: SwedbankPaySDKConfiguration {
    /// Called by SwedbankPaySDKController when it needs to start a consumer identification
    /// session. Your implementation must make the call to Swedbank Pay API
    /// and return a SwedbankPaySDK.ViewConsumerIdentificationInfo describing the result.
    /// - parameter consumer: the SwedbankPaySDK.Consumer the SwedbankPaySDKController was created with
    /// - parameter userData: the user data the SwedbankPaySDKController was created with
    /// - returns: SwedbankPaySDK.ViewConsumerIdentificationInfo describing the created identification session
    func postConsumers(
        consumer: SwedbankPaySDK.Consumer?,
        userData: Any?
    ) async throws -> SwedbankPaySDK.ViewConsumerIdentificationInfo
    
    /// Called by SwedbankPaySDKController when it needs to create a payment order.
    /// Your implementation must make the call to Swedbank Pay API
    /// and return a SwedbankPaySDK.ViewPaymentOrderInfo describing the result.
    ///
    /// - parameter paymentOrder: the SwedbankPaySDK.PaymentOrder the SwedbankPaySDKController was created with
    /// - parameter userData: the user data the SwedbankPaySDKController was created with
    /// - parameter consumerProfileRef: if a checkin was performed first, the `consumerProfileRef` from checkin
    /// - returns: SwedbankPaySDK.ViewPaymentOrderInfo describing the created payment order
    func postPaymentorders(
        paymentOrder: SwedbankPaySDK.PaymentOrder?,
        userData: Any?,
        consumerProfileRef: String?,
        options: SwedbankPaySDK.VersionOptions
    ) async throws -> SwedbankPaySDK.ViewPaymentOrderInfo
    
    /// Called by SwedbankPaySDKController when it needs to update the
    /// ongoing payment order.
    ///
    /// Your implementation should support cancellation.
    ///
    /// - parameter paymentOrder: the SwedbankPaySDK.PaymentOrder
    ///  the SwedbankPaySDKController was created with
    /// - parameter userData: the user data the SwedbankPaySDKController was created with
    /// - parameter viewPaymentOrderInfo: the current ViewPaymentOrderInfo
    ///  as returned from a call to this or postPaymentorders
    /// - parameter updateInfo: the updateInfo value from the `updatePaymentOrder` call
    /// As you are in control of both the configuration and the update call, you can
    /// coordinate the actual type used here.
    /// - returns: updated SwedbankPaySDK.ViewPaymentOrderInfo for the payment
    func updatePaymentOrder(
        paymentOrder: SwedbankPaySDK.PaymentOrder?,
        options: SwedbankPaySDK.VersionOptions,
        userData: Any?,
        viewPaymentOrderInfo: SwedbankPaySDK.ViewPaymentOrderInfo,
        updateInfo: Any
    ) async throws -> SwedbankPaySDK.ViewPaymentOrderInfo
    
    /// Called by SwedbankPaySDKController when it needs to get payer information
    ///
    /// - parameter paymentInfo: the current SwedbankPaySDK.ViewPaymentLinkInfo show to the user
    /// - throws if error, otherwise success
    func expandPayerAfterIdentified(
        paymentInfo: SwedbankPaySDK.ViewPaymentOrderInfo
    ) async throws
    
    func expandOperation<ResultJSON:Decodable>(
        paymentId: String,
        expand: [SwedbankPaySDK.ExpandResource],
        endpoint: String
    ) async throws -> ResultJSON
    
    /// Abort payment in response to user actions, to permamently close a payment session.
    ///
    func abortPayment(
        paymentInfo: SwedbankPaySDK.ViewPaymentOrderInfo,
        userData: Any?
    ) async throws
    
    /// Called by SwedbankPaySDKController when the payment menu is about to navigate
    /// to a different page. Testing has shown that some pages are incompatible with
    /// WKWebView. The SDK contains a list of redirects tested to be working, but you
    /// can customize the behaviour by providing a custom implementation of this method.
    ///
    /// The default implementation returns .openInWebView if the url of the navigation
    /// matches the built-in list, and .openInBrowser otherwise.
    /// If you override this method, but wish to access the built-in list of known-good
    /// redirects, call urlMatchesListOfGoodRedirects.
    ///
    /// - parameter navigationAction: the navigation that is about to happen
    /// - parameter completion: callback you must invoke to supply the result
    func decidePolicyForPaymentMenuRedirect(
        navigationAction: WKNavigationAction
    ) async -> SwedbankPaySDK.PaymentMenuRedirectPolicy
}

@available(iOS 15.0.0, *)
public extension SwedbankPaySDKConfigurationAsync {
    func updatePaymentOrder(
        paymentOrder: SwedbankPaySDK.PaymentOrder?,
        options: SwedbankPaySDK.VersionOptions,
        userData: Any?,
        viewPaymentOrderInfo: SwedbankPaySDK.ViewPaymentOrderInfo,
        updateInfo: Any
    ) async throws -> SwedbankPaySDK.ViewPaymentOrderInfo {
        return viewPaymentOrderInfo
    }
    
    func expandPayerAfterIdentified(
        paymentInfo: SwedbankPaySDK.ViewPaymentOrderInfo
    ) async throws {
        
        throw NotImplementedError()
    }
    
    func expandOperation<ResultJSON:Decodable>(
        paymentId: String,
        expand: [SwedbankPaySDK.ExpandResource],
        endpoint: String
    ) async throws -> ResultJSON {
        
        throw NotImplementedError()
    }
    
    func abortPayment(
        paymentInfo: SwedbankPaySDK.ViewPaymentOrderInfo,
        userData: Any?
    ) async throws {
        
        throw NotImplementedError()
    }
}

@available(iOS 15.0.0, *)
public extension SwedbankPaySDKConfigurationAsync {
    /// Check if the given url matches the built-in list of known-good
    /// payment menu redirects.
    /// - parameter url: the URL to check
    /// - returns: `true` if url matches the list, `false` otherwise
    @available(*, deprecated, message: "no longer maintained")
    func urlMatchesListOfGoodRedirects(_ url: URL) async -> Bool {
        return await withUnsafeContinuation { continuation in
            urlMatchesListOfGoodRedirects(url, completion: continuation.resume(returning:))
        }
    }
    
    func decidePolicyForPaymentMenuRedirect(
        navigationAction: WKNavigationAction
    ) async -> SwedbankPaySDK.PaymentMenuRedirectPolicy {
        return await withUnsafeContinuation { continuation in
            decidePolicyForPaymentMenuRedirect(navigationAction: navigationAction, completion: continuation.resume(returning:))
        }
    }
}

@available(iOS 15.0.0, *)
public extension SwedbankPaySDKConfigurationAsync {
    @discardableResult
    private func bridge<T>(
        _ completion: @escaping (Result<T, Error>) -> Void,
        f: @escaping () async throws -> T
    ) -> Task<Void, Never> {
        return Task {
            let result: Result<T, Error>
            do {
                result = .success(try await f())
            } catch {
                result = .failure(error)
            }
            if !Task.isCancelled {
                completion(result)
            }
        }
    }
    
    func postConsumers(
        consumer: SwedbankPaySDK.Consumer?,
        userData: Any?,
        completion: @escaping (Result<SwedbankPaySDK.ViewConsumerIdentificationInfo, Error>) -> Void
    ) {
        bridge(completion) {
            try await postConsumers(consumer: consumer, userData: userData)
        }
    }
    
    func postPaymentorders(
        paymentOrder: SwedbankPaySDK.PaymentOrder?,
        userData: Any?,
        consumerProfileRef: String?,
        options: SwedbankPaySDK.VersionOptions,
        completion: @escaping (Result<SwedbankPaySDK.ViewPaymentOrderInfo, Error>) -> Void
    ) {
        bridge(completion) {
            try await postPaymentorders(paymentOrder: paymentOrder, userData: userData, consumerProfileRef: consumerProfileRef, options: options)
        }
    }
    
    func updatePaymentOrder(
        paymentOrder: SwedbankPaySDK.PaymentOrder?,
        options: SwedbankPaySDK.VersionOptions,
        userData: Any?,
        viewPaymentOrderInfo: SwedbankPaySDK.ViewPaymentOrderInfo,
        updateInfo: Any,
        completion: @escaping (Result<SwedbankPaySDK.ViewPaymentOrderInfo, Error>) -> Void
    ) -> SwedbankPaySDKRequest {
        return bridge(completion) {
            try await updatePaymentOrder(paymentOrder: paymentOrder, options: options, userData: userData, viewPaymentOrderInfo: viewPaymentOrderInfo, updateInfo: updateInfo)
        }
    }
    
    func expandPayerAfterIdentified(
        paymentInfo: SwedbankPaySDK.ViewPaymentOrderInfo,
        completion: @escaping (Result<Void, Error>) -> Void
    ) -> SwedbankPaySDKRequest? {
        return bridge(completion) {
            try await expandPayerAfterIdentified(paymentInfo: paymentInfo)
        }
    }
    
    func expandOperation<ResultJSON:Decodable>(
        paymentId: String,
        expand: [SwedbankPaySDK.ExpandResource],
        endpoint: String = "expand",
        completion: @escaping (Result<ResultJSON, Error>) -> Void
    ) -> SwedbankPaySDKRequest? {
        
        return bridge(completion) {
            try await expandOperation(paymentId: paymentId, expand: expand, endpoint: endpoint)
        }
    }
    
    func abortPayment(
        paymentInfo: SwedbankPaySDK.ViewPaymentOrderInfo,
        userData: Any?,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        
    }
    
    func decidePolicyForPaymentMenuRedirect(
        navigationAction: WKNavigationAction,
        completion: @escaping (SwedbankPaySDK.PaymentMenuRedirectPolicy) -> Void
    ) {
        Task {
            completion(await decidePolicyForPaymentMenuRedirect(navigationAction: navigationAction))
        }
    }
}

#endif // swift(>=5.5)
