//
// Copyright 2022 Swedbank AB
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

extension SwedbankPaySDK {
    
    /// Keep track of current version and build user agent string
    public struct VersionReporter {
        
        /// This number must match git's release-tag, pre-releases should be marked with "-alpha"
        /// It can't be read from info.plist since SPM does not have those.
        public static var currentVersion = "4.0.2"
        
        /// User agent reports version and platform
        public static var userAgent: String = {
            "SwedbankPaySDK-iOS/\(currentVersion)"
        }()
    }
}
