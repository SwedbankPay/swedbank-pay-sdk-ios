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

public extension SwedbankPaySDK {
    static func `continue`(userActivity: NSUserActivity) -> Bool {
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
            let url = userActivity.webpageURL {
            return continueWebBrowsingActivity(url: url)
        } else {
            return false
        }
    }
}

// needs to be @objc to be used as the type parameter of NSHashTable (!?)
@objc protocol ContinueWebBrowsingUserActivityDelegate {
    func continueWebBrowsingActivity(url: URL) -> Bool
}

extension SwedbankPaySDK {
    private static let delegates = NSHashTable<ContinueWebBrowsingUserActivityDelegate>(options: [.weakMemory, .objectPointerPersonality])
    
    static func addContinueWebBrowsingUserActivityDelegate(_ delegate: ContinueWebBrowsingUserActivityDelegate) {
        delegates.add(delegate)
    }
    static func removeContinueWebBrowsingUserActivityDelegate(_ delegate: ContinueWebBrowsingUserActivityDelegate) {
        delegates.remove(delegate)
    }
    private static func continueWebBrowsingActivity(url: URL) -> Bool {
        var result = false
        for delegate in IteratorSequence(NSFastEnumerationIterator(self.delegates)) {
            let handled = (delegate as? ContinueWebBrowsingUserActivityDelegate)?
                .continueWebBrowsingActivity(url: url) == true
            if handled {
                result = true
            }
        }
        return result
    }
}
