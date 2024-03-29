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

import SwedbankPaySDK
import Foundation

struct PaymentOrderIn: Decodable {
    var paymentOrder: PaymentOrder?
    var operations: [SwedbankPaySDK.Operation]
    var mobileSDK: MobileSDK?
    
    struct PaymentOrder: Decodable {
        var id: String?
        var payer: PayerIn?
        var instrument: SwedbankPaySDK.Instrument?
        var availableInstruments: [SwedbankPaySDK.Instrument]?
    }
    
    struct MobileSDK: Decodable {
        var setInstrument: SetInstrumentLink?
    }
    
    struct PayerIn: Decodable {
        var id: URL
        var name: String?
        var email: String?
        var msisdn: String?
        var shippingAddress: ShippingAddress?
    }
}

struct ShippingAddress: Decodable {
    var addressee: String
    var coAddress: String
    var streetAddress: String
    var zipCode: String
    var city: String
    var countryCode: String
}
