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
    /// Call from your `UIApplicationDelegate.application(_:open:options:)`
    /// implementation to forward paymentUrls to the SDK
    ///
    /// - parameter url: the URL to forward
    /// - returns: `true` if the url was successfully processed by the SDK,
    ///  `false` otherwise (e.g. if the url was not an active payment url)
    static func open(url: URL) -> Bool {
        return handleCallbackUrl(url)
    }
 
    /// Call from your
    /// `UIApplicationDelegate.application(_:continue:restorationHandler:)`
    /// implementation to forward paymentUrls to the SDK
    ///
    /// - parameter userActivity: the NSUserActivity to forward to the SDK
    /// - returns: `true` if `userActivity` was successfully processed by the SDK,
    ///  `false` otherwise (e.g. if it was not a navigation to an active payment url)
    static func `continue`(userActivity: NSUserActivity) -> Bool {
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
            let url = userActivity.webpageURL {
            return handleCallbackUrl(url)
        } else {
            return false
        }
    }
}

// needs to be @objc to be used as the type parameter of NSHashTable (!?)
@objc protocol CallbackUrlDelegate {
    func handleCallbackUrl(_ url: URL) -> Bool
}

extension SwedbankPaySDK {
    private static let delegates = NSHashTable<CallbackUrlDelegate>(options: [.weakMemory, .objectPointerPersonality])
    
    static func addCallbackUrlDelegate(_ delegate: CallbackUrlDelegate) {
        delegates.add(delegate)
    }
    static func removeCallbackUrlDelegate(_ delegate: CallbackUrlDelegate) {
        delegates.remove(delegate)
    }
    private static func handleCallbackUrl(_ url: URL) -> Bool {
        var result = false
        for delegate in IteratorSequence(NSFastEnumerationIterator(self.delegates)) {
            let handled = (delegate as? CallbackUrlDelegate)?
                .handleCallbackUrl(url) == true
            if handled {
                result = true
            }
        }
        return result
    }
}
