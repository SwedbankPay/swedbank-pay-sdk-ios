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

public extension SwedbankPaySDK {
    
    ///  Consumer object for Swedbank Pay SDK
    struct Consumer: Codable {
        var consumerCountryCode: String?
        var msisdn: String?
        var email: String?
        var nationalIdentifier: NationalIdentifier?
        
        /// Initializer for `SwedbankPaySDK.Consumer`
        /// - parameter consumerCountryCode: String representing consumer's country code
        /// - parameter msisdn: String representing consumer's phone number
        /// - parameter email: String representing consumer's email address
        /// - parameter nationalIdentifier: `NationalIdentifier`object representing consumer's social security number and country code
        public init(consumerCountryCode: String?, msisdn: String?, email: String?, nationalIdentifier: NationalIdentifier?) {
            self.consumerCountryCode = consumerCountryCode
            self.msisdn = msisdn
            self.email = email
            self.nationalIdentifier = nationalIdentifier
        }
    }
}