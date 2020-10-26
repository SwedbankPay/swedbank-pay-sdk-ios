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
    /// Ways that the SwedbankPaySDK.MerchantBackendConfiguration
    /// can fail
    enum MerchantBackendError: Error {
        /// The Merchant Backend attempted to link to a domain that was not whitelisted
        /// (N.B! By default, only the domain of the Merchant Backend and its subdomains are whitelisted)
        case nonWhitelistedDomain(failingUrl: URL)
        /// There was a network error. You can examine the contained error value for details.
        case networkError(Error)
        /// There was a problem with the request. Please refer to the associated Problem value.
        case problem(Problem)
        /// Protocol error: a Merchant Backend response did not contain an operation that is required to continue
        case missingRequiredOperation(String)
        /// Attempt to set the instrument of a payment that is not in instrument mode
        case paymentNotInInstrumentMode
    }
}
