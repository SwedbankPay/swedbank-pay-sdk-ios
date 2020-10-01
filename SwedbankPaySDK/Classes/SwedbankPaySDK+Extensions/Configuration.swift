//
// Copyright 2019 Swedbank AB
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

private let callbackURLTypeKey = "com.swedbank.SwedbankPaySDK.callback"

/// A SwedbankPaySDKConfiguration is responsible for
/// creating and manipulating Consumer Identification Sessions
/// and Payment Orders as required by the SwedbankPaySDKController.
///
/// See SwedbankPaySDK.MerchantBackendConfiguration for
/// a configuration that integrates with a backend implementing
/// the Merchant Backend API.
public protocol SwedbankPaySDKConfiguration {
    /// The URL scheme to be used as fallback to route paymentUrls to this app
    ///
    /// This scheme must be registered to the application.
    /// If your paymentUrl ends up being opened in a browser,
    /// it should have such content that ultimately it will navigate to a url
    /// that is otherwise equal to the original paymentUrl, but its scheme
    /// is this scheme, and it may optionally have additional query
    /// parameters (these parameters will be ignored by the SDK, but can be
    /// used to control the behaviour of your backend).
    var callbackScheme: String { get }
    
    /// Called by SwedbankPaySDKController when it needs to start a consumer identification
    /// session. Your implementation must ultimately make the call to Swedbank Pay API
    /// and call completion with a SwedbankPaySDK.ViewConsumerIdentificationInfo describing the result.
    /// - parameter consumer: he SwedbankPaySDK.Consumer the SwedbankPaySDKController was created with
    /// - parameter userData: the user data the SwedbankPaySDKController was created with
    /// - parameter completion: callback you must invoke to supply the result
    func postConsumers(
        consumer: SwedbankPaySDK.Consumer?,
        userData: Any?,
        completion: @escaping (Result<SwedbankPaySDK.ViewConsumerIdentificationInfo, Error>) -> Void
    )
    
    /// Called by SwedbankPaySDKController when it needs to create a payment order.
    /// Your implementation must ultimately make the call to Swedbank Pay API
    /// and call completion with a SwedbankPaySDK.ViewPaymentOrderInfo describing the result.
    ///
    /// - parameter paymentOrder: the SwedbankPaySDK.PaymentOrder the SwedbankPaySDKController was created with
    /// - parameter userData: the user data the SwedbankPaySDKController was created with
    /// - parameter consumerProfileRef: if a checkin was performed first, the `consumerProfileRef` from checkin
    /// - parameter completion: callback you must invoke to supply the result
    func postPaymentorders(
        paymentOrder: SwedbankPaySDK.PaymentOrder?,
        userData: Any?,
        consumerProfileRef: String?,
        completion: @escaping (Result<SwedbankPaySDK.ViewPaymentOrderInfo, Error>) -> Void
    )
    
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
    /// - completion: callback you must invoke to supply the result
    func decidePolicyForPaymentMenuRedirect(
        navigationAction: WKNavigationAction,
        completion: @escaping (SwedbankPaySDK.PaymentMenuRedirectPolicy) -> Void
    )
}

public extension SwedbankPaySDKConfiguration {
    /// Check if the given url matches the built-in list of known-good
    /// payment menu redirects. The completion callback is always called
    /// on the main thread.
    ///
    /// - parameter url: the URL to check
    /// - parameter completion: called with `true` if url matches the list, called with `false` otherwise
    func urlMatchesListOfGoodRedirects(_ url: URL, completion: @escaping (Bool) -> Void) {
        GoodWebViewRedirects.instance.allows(url: url, completion: completion)
    }
    
    func decidePolicyForPaymentMenuRedirect(
        navigationAction: WKNavigationAction,
        completion: @escaping (SwedbankPaySDK.PaymentMenuRedirectPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            completion(.openInWebView)
            return
        }
        urlMatchesListOfGoodRedirects(url) { matches in
            completion(matches ? .openInWebView : .openInBrowser)
        }
    }
}

public extension SwedbankPaySDK {
    /// Possible ways of handling a payment menu redirect
    enum PaymentMenuRedirectPolicy {
        /// open the redirect in the web view
        case openInWebView
        /// open the redirect in the web browser app
        case openInBrowser
    }
}
