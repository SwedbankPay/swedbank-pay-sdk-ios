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

private let callbackURLTypeKey = "com.swedbank.SwedbankPaySDK.callback"

public extension SwedbankPaySDK {
    
    /// Swedbank Pay SDK Configuration
    struct Configuration {
        var backendUrl: URL
        var callbackScheme: String
        var headers: Dictionary<String, String>?
        var domainWhitelist: [WhitelistedDomain]?
        var pinPublicKeys: [PinPublicKeys]?
        var additionalAllowedWebViewRedirects: [WebViewRedirect]?
        
        /// Initializer for `SwedbankPaySDK.Configuration`
        /// - parameter backendUrl: backend URL
        /// - paramerer callbackScheme: A custom scheme for callback urls. This scheme must be registered to your app.
        ///                             If nil, the Info.plist will be searched for a URL type
        ///                             with a com.swedbank.SwedbankPaySDK.callback property having
        ///                             a Boolean type and a YES value.
        /// - parameter headers: HTTP Request headers Dictionary in a form of 'apikey, access token' -pair
        /// - parameter domainWhitelist: Optional array of domains allowed to be connected to; defaults to `backendURL` if nil
        /// - parameter certificatePins: Optional array of domains for certification pinning, matched against any certificate found anywhere in the app bundle
        public init(backendUrl: URL, callbackScheme: String? = nil, headers: Dictionary<String, String>?, domainWhitelist: [WhitelistedDomain]? = nil, pinPublicKeys: [PinPublicKeys]? = nil, additionalAllowedWebViewRedirects: [WebViewRedirect]? = nil) {
            self.backendUrl = backendUrl
            self.callbackScheme = callbackScheme ?? Configuration.getDefaultCallbackScheme()
            self.headers = headers
            self.domainWhitelist = domainWhitelist
            self.pinPublicKeys = pinPublicKeys
            self.additionalAllowedWebViewRedirects = additionalAllowedWebViewRedirects
        }
        
        private static func getDefaultCallbackScheme() -> String {
            let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [Any]
            let urlTypeDicts = urlTypes?.lazy.compactMap { $0 as? [AnyHashable : Any] }
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
    }
}
