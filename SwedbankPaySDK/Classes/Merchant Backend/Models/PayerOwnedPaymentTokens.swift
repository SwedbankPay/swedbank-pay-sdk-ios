//
//  PayerOwnedPaymentTokens.swift
//  SwedbankPaySDK
//
//  Created by Pertti Kroger on 1.12.2020.
//  Copyright © 2020 Swedbank. All rights reserved.
//

import Foundation

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
    /// Payload of PayerOwnedPaymentTokensResponse
    struct PayerOwnedPaymentTokens: Decodable {
        /// The id (url) of this resource.
        ///
        /// Note that you generally cannot dereference this from your mobile app.
        public var id: String
        /// The payerReference associated with these tokens
        public var payerReference: String
        /// The list of tokens and associated information
        public var paymentTokens: [PaymentTokenInfo]?
    }
}
