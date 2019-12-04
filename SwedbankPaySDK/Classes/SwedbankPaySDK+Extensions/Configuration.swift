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

public extension SwedbankPaySDK {
    
    /// Swedbank Pay SDK Configuration
    struct Configuration {
        var backendUrl: URL
        var callbackPrefix: URL
        var headers: Dictionary<String, String>?
        var domainWhitelist: [WhitelistedDomain]?
        var pinPublicKeys: [PinPublicKeys]?
        
        /// Initializer for `SwedbankPaySDK.Configuration`
        /// - parameter backendUrl: backend URL
        /// - parameter headers: HTTP Request headers Dictionary in a form of 'apikey, access token' -pair
        /// - parameter domainWhitelist: Optional array of domains allowed to be connected to; defaults to `backendURL` if nil
        /// - parameter certificatePins: Optional array of domains for certification pinning, matched against any certificate found anywhere in the app bundle
        public init(backendUrl: URL, callbackPrefix: URL? = nil, headers: Dictionary<String, String>?, domainWhitelist: [WhitelistedDomain]? = nil, pinPublicKeys: [PinPublicKeys]? = nil) {
            self.backendUrl = backendUrl
            self.callbackPrefix = callbackPrefix ?? Configuration.getDefaultCallbackPrefix(backendUrl: backendUrl)
            self.headers = headers
            self.domainWhitelist = domainWhitelist
            self.pinPublicKeys = pinPublicKeys
        }
        
        private static func getDefaultCallbackPrefix(backendUrl: URL) -> URL {
            return URL(string: "sdk-callback", relativeTo: backendUrl)!
        }
    }
}
