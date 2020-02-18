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

enum CallbackUrl {
    case reloadPaymentMenu(token: String)
}

extension CallbackUrl {
    init?(url: URL, prefix: URL) {
        let prefixString = prefix.absoluteString.ensureSuffix("/")
        let callbackPath = url.absoluteString.substringAfter(prefix: prefixString)
        let callbackComponents = callbackPath.map(String.init).flatMap(URLComponents.init(string:))
        switch callbackComponents?.path {
        case "reload":
            guard let token = callbackComponents?.queryItems?.first(where: { $0.name == "token" })?.value else {
                return nil
            }
            self = .reloadPaymentMenu(token: token)
            
        default:
            return nil
        }
    }
    
    func toUrl(prefix: URL, fallbackScheme: String) -> URL {
        switch self {
        case .reloadPaymentMenu(let token):
            var urlComponents = URLComponents()
            urlComponents.path = "reload"
            urlComponents.queryItems = [
                URLQueryItem(name: "token", value: token),
                URLQueryItem(name: "scheme", value: fallbackScheme)
            ]
            return urlComponents.url(relativeTo: prefix)!
        }
    }
}

private extension String {
    func ensureSuffix(_ suffix: String) -> String {
        return hasSuffix(suffix) ? self : self + suffix
    }
    func substringAfter(prefix: String) -> Substring? {
        return hasPrefix(prefix) ? self[prefix.endIndex...] : nil
    }
}
