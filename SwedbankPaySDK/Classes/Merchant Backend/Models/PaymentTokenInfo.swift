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
    /// Information about a payment token
    struct PaymentTokenInfo: Decodable {
        /// The actual paymentToken
        public var paymentToken: String
        /// Payment instrument type of this token
        public var instrument: Instrument?
        /// User-friendly description of the payment instrument
        public var instrumentDisplayName: String?
        /// Instrument-specific parameters.
        public var instrumentParameters: [String: String]?
        /// Operations you can perform on this token.
        ///
        /// Note that you generally cannot call these from your mobile app.
        public var operations: [Operation]?
    }
}
