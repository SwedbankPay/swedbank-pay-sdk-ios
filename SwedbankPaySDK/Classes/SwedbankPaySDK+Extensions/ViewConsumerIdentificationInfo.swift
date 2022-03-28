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
    
    /// To allow switching between v2 and v3 we use an enum to describe how to behave when identifyingConsumer
    enum IdentifyingVersion: Codable {
        case v2(SwedbankPaySDK.ViewConsumerIdentificationInfo)
        case v3(SwedbankPaySDK.ViewPaymentOrderInfo)
    }
    
    /// Data required to show the checkin view.
    ///
    /// If you provide a custom SwedbankPayConfiguration
    /// you must get the relevant data from your services
    /// and supply a ViewConsumerIdentificationInfo
    /// in your SwedbankPayConfiguration.postConsumers
    /// completion call.
    struct ViewConsumerIdentificationInfo: Codable {
        /// The url to use as the WKWebView page url
        /// when showing the checkin UI.
        public var webViewBaseURL: URL?
        
        /// The `view-consumer-identification` link from Swedbank Pay.
        public var viewConsumerIdentification: URL
        
        public init(
            webViewBaseURL: URL?,
            viewConsumerIdentification: URL
        ) {
            self.webViewBaseURL = webViewBaseURL
            self.viewConsumerIdentification = viewConsumerIdentification
        }
    }
}
