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
    enum Language : String, Codable {
        case English = "en-US"
        case Norwegian = "nb-NO"
        case Swedish = "sv-SE"
    }
    
    ///  Consumer object for Swedbank Pay SDK
    struct Consumer: Codable {
        var operation: ConsumerOperation
        var language: Language
        var shippingAddressRestrictedToCountryCodes: [String]
        
        public init(
            operation: ConsumerOperation = .InitiateConsumerSession,
            language: Language = .English,
            shippingAddressRestrictedToCountryCodes: [String]
        ) {
            self.operation = operation
            self.language = language
            self.shippingAddressRestrictedToCountryCodes = shippingAddressRestrictedToCountryCodes
        }
    }
    
    enum ConsumerOperation : String, Codable {
        case InitiateConsumerSession = "initiate-consumer-session"
    }
}
