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

import Foundation

enum SwedbankPaySDKResources {}
private extension SwedbankPaySDKResources {
    #if SWIFT_PACKAGE_MANAGER
    static let bundle = Bundle.module
    #else
    static let bundle = Bundle(for: SwedbankPaySDK.self)
    #endif
}
extension SwedbankPaySDKResources {
    static func path(forResource name: String?, ofType ext: String?) -> String? {
        return bundle.path(forResource: name, ofType: ext)
    }
}
extension SwedbankPaySDKResources {
    static func localizedString(key: String) -> String {
        return bundle.localizedString(forKey: key, value: nil, table: "SwedbankPaySDKLocalizable")
    }
}
