//
//  Copyright © 2022 Swedbank. All rights reserved.
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
    /// Options to use for each purchase, to switch between versions or utilize different functions
    struct VersionOptions: OptionSet, Codable {
        public let rawValue: Int
        
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
        
        public static let isV3 = VersionOptions(rawValue: 1 << 0)
        public static let useCheckin = VersionOptions(rawValue: 1 << 1)
    }
}
