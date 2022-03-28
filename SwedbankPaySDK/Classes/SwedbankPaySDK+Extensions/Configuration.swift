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

/// A handle to a request started by a call to SwedbankPaySDKConfiguration.
public protocol SwedbankPaySDKRequest {
    /// Cancels the request. If should not call its completion block
    /// after this method returns.
    func cancel()
}

/// A SwedbankPaySDKConfiguration is responsible for
/// creating and manipulating Consumer Identification Sessions
/// and Payment Orders as required by the SwedbankPaySDKController.
///
/// See SwedbankPaySDK.MerchantBackendConfiguration for
/// a configuration that integrates with a backend implementing
/// the Merchant Backend API.
public protocol SwedbankPaySDKConfiguration {
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
        options: SwedbankPaySDK.VersionOptions,
        completion: @escaping (Result<SwedbankPaySDK.ViewPaymentOrderInfo, Error>) -> Void
    )
    
    /// Called by SwedbankPaySDKController when it needs to update the
    /// ongoing payment order.
    ///
    /// As the update could be cancelled, you must also return a request handle
    /// that allows the request to cancelled.
    ///
    /// - parameter paymentOrder: the SwedbankPaySDK.PaymentOrder
    ///  the SwedbankPaySDKController was created with
    /// - parameter userData: the user data the SwedbankPaySDKController was created with
    /// - parameter viewPaymentOrderInfo: the current ViewPaymentOrderInfo
    ///  as returned from a call to this or postPaymentorders
    /// - parameter updateInfo: the updateInfo value from the `updatePaymentOrder` call
    /// As you are in control of both the configuration and the update call, you can
    /// coordinate the actual type used here.
    /// - parameter completion: callback you must invoke to supply the result
    /// - returns: a cancellation handle to the request started by this call
    func updatePaymentOrder(
        paymentOrder: SwedbankPaySDK.PaymentOrder?,
        options: SwedbankPaySDK.VersionOptions,
        userData: Any?,
        viewPaymentOrderInfo: SwedbankPaySDK.ViewPaymentOrderInfo,
        updateInfo: Any,
        completion: @escaping (Result<SwedbankPaySDK.ViewPaymentOrderInfo, Error>) -> Void
    ) -> SwedbankPaySDKRequest?
    
    /// Abort payment in response to user actions, to permamently close a payment session.
    ///
    func abortPayment(
        paymentInfo: SwedbankPaySDK.ViewPaymentOrderInfo,
        userData: Any?,
        completion: @escaping (Result<Void, Error>) -> Void
    )
    
    /// Route a general get request towards one of the resources, like /psp/paymentorders<id>/paid
    /// Implement this to create tests or verify statuses with your backend
    /// - Parameters:
    ///   - paymentID: the id of to expand, in this case full path: /psp/paymentorders<id>
    ///   - expand: the expanded resource to ask for, in this case paid
    ///   - endpoint: the specialized endpoint to use, in our Merchant Backend example implementation, "expand" is used.
    /// - Returns: a cancellation handle to the request started by this call
    func expandOperation<ResultJSON:Decodable>(
        paymentId: String,
        expand: [SwedbankPaySDK.ExpandResource],
        endpoint: String,
        completion: @escaping (Result<ResultJSON, Error>) -> Void
    ) -> SwedbankPaySDKRequest?
    
    /// Called by SwedbankPaySDKController when the payment menu is about to navigate
    /// to a different page.
    ///
    /// Testing has shown that some pages are incompatible with WKWebView.
    /// The SDK attempts to detect when that happens and allows the user to retry
    /// the payment with all redirects going to the browser instead. You may, however,
    /// control the handling of redirects in the initial attempt by implementing this method.
    ///
    /// The default implementation calls completion with `.openInWebView`.
    ///
    /// - parameter navigationAction: the navigation that is about to happen
    /// - parameter completion: callback you must invoke to supply the result
    func decidePolicyForPaymentMenuRedirect(
        navigationAction: WKNavigationAction,
        completion: @escaping (SwedbankPaySDK.PaymentMenuRedirectPolicy) -> Void
    )
    
    /// Called by SwedbankPaySDKController when it needs to check if a given url
    /// is equivalent to a `paymentUrl` of a payment order.
    /// This method has a default implementation. In advanced scenarios you
    /// may wish to provide your own implementation instead.
    ///
    /// The default implementation from allows for the scheme to change,
    /// and for extra query parameters to be added to the paymentUrl.
    /// I.e. if the paymentUrl is https://example.com/?a=1,
    /// then all of the following match:
    ///  - https://example.com/?a=1
    ///  - https://example.com/?a=1&b=2
    ///  - com.example.my.app://example.com/?a=1
    ///  - com.example.my.app://example.com/?a=1&b=2
    ///
    /// The need for this method merits some discussion.
    /// When a 3D-Secure flow starts an external application, such as
    /// BankID, that application will in turn continue the flow by opening
    /// some url. Usually that url will be a url of the card issuer, and therefore
    /// not routed back to our app. Instead, it will be opened in Safari. Of course,
    /// ultimately that page will navigate to the paymentUrl of the payment order
    /// in progress. Assuming both your backend and your app are configured correctly,
    /// the paymentUrl should be a Universal Link to your app, and you should
    /// receive the url your
    /// `UIApplicationDelegate.application(_:continue:restorationHandler:)`.
    /// You will then forward the url to the SDK by calling
    /// `SwedbankPaySDK.continue(userActivity:)`. The url there is then equal
    /// to the payment order's paymentUrl (which you reported to the SDK in the
    /// `ViewPaymentOrderInfo`), the SDK recognizes this, and the payment menu is reloaded.
    ///
    /// However, the mechanics of Universal Links make them unreliable. To work around
    /// their limitations, we must allow for alternate urls to also match the paymentUrl.
    /// To see why, consider the following flow of events:
    ///  1. The card issuer page navigates to `paymentUrl`. This is our first opportunity;
    ///     Here the url is equal to `paymentUrl`.
    ///  2. Assume `paymentUrl` is opened in Safari. We must show some html content to the user.
    ///     Show them a page with a "continue" button, which links back to the `paymentUrl`,
    ///     but with an extra parameter (this is needed for the next step).
    ///     This is our second opportunity; here the url is `paymentUrl` with an extra query
    ///     parameter.
    ///  3. Assume the `paymentUrl` with extra parameter is *also* opened in Safari.
    ///     (N.B! This should not happen with if all parts of your system are configured
    ///     correctly, but in principle it is possible that iOS has not yet successfully
    ///     retrieved your apple-app-site-association file. Also this scenario is prone to
    ///     occuring during development, so it is nice not to get stuck here.) We show the same
    ///     html content, except the "continue" button now links to `paymentUrl` with the scheme
    ///     changed to a scheme unique to your app.
    ///  4. There is nowhere else for the custom-scheme link to go except your app, so
    ///     here is our final possibility of getting the url. Now the url is `paymentUrl`
    ///     but with a different scheme. (In our Merchant Backend example implementation,
    ///     it is actually `paymentUrl` with both an extra query parameter and a different
    ///     scheme, to simplify the implementation.) Note that in this case we get the url
    ///     in our `UIApplicationDelegate.application(_:open:options:)` method instead.
    func url(_ url: URL, matchesPaymentUrl paymentUrl: URL) -> Bool
}

public struct NotImplementedError: Error {
    
    var description: String {
        "Not implemented default functions should not be called."
    }
}

public extension SwedbankPaySDKConfiguration {
    
    
    
    // default functions for optional methods
    func updatePaymentOrder(
        paymentOrder: SwedbankPaySDK.PaymentOrder?,
        options: SwedbankPaySDK.VersionOptions,
        userData: Any?,
        viewPaymentOrderInfo: SwedbankPaySDK.ViewPaymentOrderInfo,
        updateInfo: Any,
        completion: @escaping (Result<SwedbankPaySDK.ViewPaymentOrderInfo, Error>) -> Void
    ) -> SwedbankPaySDKRequest? {
        completion(.success(viewPaymentOrderInfo))
        return nil
    }
    
    func abortPayment(
        paymentInfo: SwedbankPaySDK.ViewPaymentOrderInfo,
        userData: Any?,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        completion(.failure(NotImplementedError()))
    }
    
    /// Expand the payer info from a payment after being identified, to allow for calculating shipping costs.
    /// NOTE: This is not used in PaymentsOnly, and thus kept here only for future reference and not for actual usage (yet).
    ///
    /// - Parameters:
    ///   - paymentInfo: The payment order to expand
    ///   - completion: Supply your own type depending on your backend implementation.
    /// - Returns: a cancellation handle to the request started by this
    func expandPayerAfterIdentified (
        paymentInfo: SwedbankPaySDK.ViewPaymentOrderInfo,
        completion: @escaping (Result<Void, Error>) -> Void
    ) -> SwedbankPaySDKRequest? {
        completion(.failure(NotImplementedError()))
        return nil
    }
    
    func expandOperation<ResultJSON:Decodable>(
        paymentId: String,
        expand: [SwedbankPaySDK.ExpandResource],
        endpoint: String = "expand",
        completion: @escaping (Result<ResultJSON, Error>) -> Void
    ) -> SwedbankPaySDKRequest? {
        
        completion(.failure(NotImplementedError()))
        return nil
    }
}

public extension SwedbankPaySDKConfiguration {
    /// Check if the given url matches the built-in list of known-good
    /// payment menu redirects. The completion callback is always called
    /// on the main thread.
    ///
    /// - parameter url: the URL to check
    /// - parameter completion: called with `true` if url matches the list, called with `false` otherwise
    @available(*, deprecated, message: "no longer maintained")
    func urlMatchesListOfGoodRedirects(_ url: URL, completion: @escaping (Bool) -> Void) {
        GoodWebViewRedirects.instance.allows(url: url, completion: completion)
    }
    
    func decidePolicyForPaymentMenuRedirect(
        navigationAction: WKNavigationAction,
        completion: @escaping (SwedbankPaySDK.PaymentMenuRedirectPolicy) -> Void
    ) {
        completion(.openInWebView)
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

/// A refinement of SwedbankPaySDKConfiguration.
/// SwedbankPaySDKConfigurationWithCallbackScheme uses knowledge of the
/// custom scheme used for `paymentUrl` to only accept
/// `paymentUrl` with the original scheme or the specified scheme.
public protocol SwedbankPaySDKConfigurationWithCallbackScheme : SwedbankPaySDKConfiguration {
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
}

public extension SwedbankPaySDKConfiguration {
    func url(_ url: URL, matchesPaymentUrl paymentUrl: URL) -> Bool {
        return prospectivePaymentUrl(
            url: url,
            matches: paymentUrl,
            callbackScheme: nil
        )
    }
}

public extension SwedbankPaySDKConfigurationWithCallbackScheme {
    func url(_ url: URL, matchesPaymentUrl paymentUrl: URL) -> Bool {
        return prospectivePaymentUrl(
            url: url,
            matches: paymentUrl,
            callbackScheme: callbackScheme
        )
    }
}

private extension SwedbankPaySDKConfiguration {
    func prospectivePaymentUrl(
        url: URL,
        matches paymentUrl: URL,
        callbackScheme: String?
    ) -> Bool {
        // Because of the interaction between how Universal Links work
        // (first, they will only be followed if the navigation started
        // from a user interaction; and second, they will only be followed
        // if their domain is different to the current page), and how many
        // 3DS pages are designed (i.e. they have a timeout that navigates
        // to the payment url), we have to perform some gymnastics to get
        // back to the app while maintaining a nice user experience.
        //
        // How this works is:
        //  - paymentUrl is a Universal Link
        //    - if stars align, this will get routed to our app. Usually not the case. (See below for note)
        //  - in browser, paymentUrl redirects to a page different domain
        //  - that page has a button
        //  - pressing the button navigates back to paymentUrl but with an extra query parameter
        //    - in most cases, this will be routed to our app
        //  - in browser, paymentUrl with the extra parameter redirects to the same url but with a custom scheme
        //
        // We don't do the last one immediately, because doing that will show a
        // popup that we have no control over. It is included as a final fallback mechanism.
        //
        // N.B! iOS version 13.4 has slightly changed how Universal Links
        // work, and it seems that it is now more likely that already
        // the first universal link will be routed to our app.
        //
        // All of the above means, that if paymentUrl is https://<foo>,
        // then all of the following are equal in this sense:
        //  - https://<foo>
        //  - https://<foo>&fallback=true
        //  - <customscheme>://<foo>&fallback=true
        //  (the following won't be used by the example backend, but your custom one may)
        //  - https://<foo>?fallback=true
        //  - <customscheme>://foo
        //  - <customscheme>://<foo>?fallback=true
        //
        // For simplicity, we require the URL to be parseable to URLComponents,
        // i.e. that if conforms to RFC 3986. This should never be a problem in practice.
        
        guard
            let paymentUrlComponents = URLComponents(
                url: paymentUrl,
                resolvingAgainstBaseURL: true
            ),
            var componentsToCompare = URLComponents(
                url: url,
                resolvingAgainstBaseURL: true
            )
            else {
                return false
        }
        
        // Treat fallback scheme as equal to the original scheme
        if callbackScheme == nil || componentsToCompare.scheme == callbackScheme {
            componentsToCompare.scheme = paymentUrlComponents.scheme
        }
        
        // Check that all the original query items are in place
        if !callback(queryItems: componentsToCompare.queryItems, match: paymentUrlComponents.queryItems) {
            return false
        }
        
        // Check that everything else is equal
        var paymentUrlComponentsToCompare = paymentUrlComponents
        componentsToCompare.queryItems = nil
        paymentUrlComponentsToCompare.queryItems = nil
        return componentsToCompare == paymentUrlComponentsToCompare
    }
    
    private func callback(queryItems: [URLQueryItem]?, match requiredItems: [URLQueryItem]?) -> Bool {
        // Backend is allowed to add query items to the url.
        // It must not remove or modify any.
        var items = queryItems ?? []
        for requiredItem in requiredItems ?? [] {
            guard let index = items.firstIndex(of: requiredItem) else {
                return false
            }
            items.remove(at: index)
        }
        return true
    }
}
