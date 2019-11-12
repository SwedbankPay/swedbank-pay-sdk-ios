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
    
    ///  Whitelisted domains
    struct WhitelistedDomain {
        var domain: String?
        var includeSubdomains: Bool

        /// Initializer for `SwedbankPaySDK.WhitelistedDomain`
        /// - parameter domain: URL of the domain as a String
        /// - parameter includeSubdomains: if `true`, means any subdomain of `domain` is valid
        public init(domain: String?, includeSubdomains: Bool) {
            self.domain = domain
            self.includeSubdomains = includeSubdomains
        }
    }
}
