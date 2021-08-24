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
    static let instance = GoodWebViewRedirects(openDataFile: {
        let path = getResourceBundle()
            .path(forResource: "good_redirects", ofType: nil)
        return path.flatMap { fopen($0, "r") }
    })
    
    private let queue = DispatchQueue(label: "GoodWebViewRedirects", qos: .userInitiated)
    private var cache: [SwedbankPaySDK.WebViewRedirect]?
    
    // Overridable for tests.
    // Swift has no native "read lines" function so we use the C library.
    private let openDataFile: () -> UnsafeMutablePointer<FILE>?
    
    init(openDataFile: @escaping () -> UnsafeMutablePointer<FILE>?) {
        self.openDataFile = openDataFile
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
    
    private static func getResourceBundle() -> Bundle {
        #if SWIFT_PACKAGE_MANAGER
        return Bundle.module
        #else
        return Bundle(for: GoodWebViewRedirects.self)
        #endif
    }
    
    private func getData() -> [SwedbankPaySDK.WebViewRedirect]? {
        let cache = self.cache
        let data = cache ?? readFromFile()
        if cache == nil {
            self.cache = data
        }
        return data
    }
    
    private func readFromFile() -> [SwedbankPaySDK.WebViewRedirect]? {
        guard let file = openDataFile() else {
            return nil
        }
        defer {
            fclose(file)
        }
        return read(from: file)
    }
    
    private func read(from file: UnsafeMutablePointer<FILE>) -> [SwedbankPaySDK.WebViewRedirect] {
        return file.getLines().lazy
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .compactMap(parse(line:))
    }
    
    private func parse(line: String) -> SwedbankPaySDK.WebViewRedirect? {
        switch line.first {
        case "#", nil:
            return nil
            
        case "*":
            return parseWildcard(line: line)
            
        default:
            return .Domain(name: line)
        }
    }
    
    private func parseWildcard(line: String) -> SwedbankPaySDK.WebViewRedirect? {
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
