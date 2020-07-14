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

public extension SwedbankPaySDK {
    enum WebViewRedirect {
        case Domain(name: String)
        case DomainOrSubdomain(suffix: String, allowNestedSubdomains: Bool = false)
    }
}

internal extension SwedbankPaySDK.WebViewRedirect {
    func allows(url: URL) -> Bool {
        switch self {
        case .Domain(let name):
            return url.host == name
            
        case .DomainOrSubdomain(let suffix, allowNestedSubdomains: false):
            guard let host = url.host else {
                return false
            }
            if host == suffix {
                return true
            } else if let subdomainSeparatorIndex = host.firstIndex(of: ".") {
                let parentDomain = host[subdomainSeparatorIndex...].dropFirst()
                return parentDomain == suffix
            } else {
                return false
            }
            
        case .DomainOrSubdomain(let suffix, allowNestedSubdomains: true):
            return url.host?.hasSuffix(suffix) == true
        }
    }
}
