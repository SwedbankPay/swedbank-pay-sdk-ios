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
    /// Payment instrument for an Instrument mode payment order.
    struct Instrument: RawRepresentable, Hashable, Codable {
        /// Credit or Debit Card
        public static let creditCard = Instrument(rawValue: "CreditCard")
        
        /// Swish
        public static let swish = Instrument(rawValue: "Swish")
        
        /// Vipps
        public static let vipps = Instrument(rawValue: "Vipps")
        
        /// Swedbank Pay Invoice (Sweden)
        public static let invoiceSE = Instrument(
            rawValue: "Invoice-PayExFinancingSe"
        )
        
        /// Swedbank Pay Invoice (Norway)
        public static let invoiceNO = Instrument(
            rawValue: "Invoice-PayExFinancingNo"
        )
        
        /// Swedbank Pay Monthly Invoice (Sweden)
        public static let monthlyInvoiceSE = Instrument(
            rawValue: "Invoice-PayExMonthlyInvoiceSe"
        )
        
        /// Volvofinans CarPay
        public static let carPay = Instrument(rawValue: "CarPay")
        
        /// Credit Account
        public static let creditAccount = Instrument(rawValue: "CreditAccount")
        
        public var rawValue: String
        
        public init(rawValue: String) {
            self.rawValue = rawValue
        }
    }
}

public extension SwedbankPaySDK.Instrument {
    @available(*, deprecated, message: "Use invoiceSE instead")
    static var invoice: Self {
        invoiceSE
    }
}
