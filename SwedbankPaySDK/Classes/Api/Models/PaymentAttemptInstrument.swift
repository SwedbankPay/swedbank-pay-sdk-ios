//
// Copyright 2024 Swedbank AB
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

extension SwedbankPaySDK {
    /// Instrument with needed values to make a payment attempt.
    public enum PaymentAttemptInstrument: Equatable {
        case swish(msisdn: String?)
        case creditCard(prefill: CreditCardMethodPrefillModel)
        case applePay(merchantIdentifier: String)
        case newCreditCard(enabledPaymentDetailsConsentCheckbox: Bool)

        var paymentMethod: String {
            switch self {
            case .swish:
                return "Swish"
            case .creditCard,
                 .newCreditCard:
                return "CreditCard"
            case .applePay:
                return "ApplePay"
            }
        }
        
        var instrumentModeRequired: Bool {
            switch self {
            case .newCreditCard:
                return true
            case .swish, .applePay, .creditCard:
                return false
            }
        }
    }
}
