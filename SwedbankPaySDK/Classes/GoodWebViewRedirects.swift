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
import UIKit

class GoodWebViewRedirects {
    static let instance = GoodWebViewRedirects()
    
    private let queue = DispatchQueue(label: "GoodWebViewRedirects", qos: .userInitiated)
    private let url: URL?
    private var cache: [SwedbankPaySDK.WebViewRedirect]?
    
    private init() {
        url = SwedbankPaySDK.resourceBundle?.url(forResource: "good_redirects", withExtension: nil)
    }
    
    func allows(url: URL, completion: @escaping (Bool) -> Void) {
        queue.async {
            let data = self.getData()
            let allow = data?.contains { $0.allows(url: url) } == true
            DispatchQueue.main.async {
                completion(allow)
            }
        }
    }
    
    private func getData() -> [SwedbankPaySDK.WebViewRedirect]? {
        let cache = self.cache
        let data = cache ?? readFromUrl()
        if cache == nil {
            self.cache = data
        }
        return data
    }
    
    private func readFromUrl() -> [SwedbankPaySDK.WebViewRedirect]? {
        // Only naive implementation is easy to write in Swift.
        // Do something better when the length of the file
        // becomes too large for this.
        let text = url.flatMap {
            try? String(contentsOf: $0, encoding: .utf8)
        }
        let lines = text?.split(separator: "\n")
        
        return lines?.compactMap(parse(line:))
    }
    
    private func parse(line: Substring) -> SwedbankPaySDK.WebViewRedirect? {
        switch line.first {
        case "#", nil:
            return nil
            
        case "*":
            return parseWildcard(line: line)
            
        default:
            return .Domain(name: String(line))
        }
    }
    
    private func parseWildcard(line: Substring) -> SwedbankPaySDK.WebViewRedirect? {
        let suffix: Substring
        let allowNestedSubdomains: Bool
        if line.hasPrefix("**.") {
            suffix = line.dropFirst(3)
            allowNestedSubdomains = true
        } else if line.hasPrefix("*.") {
            suffix = line.dropFirst(2)
            allowNestedSubdomains = false
        } else {
            return nil
        }
        
        return suffix.isEmpty
            ? nil
            : .DomainOrSubdomain(suffix: String(suffix), allowNestedSubdomains: allowNestedSubdomains)
    }
}
