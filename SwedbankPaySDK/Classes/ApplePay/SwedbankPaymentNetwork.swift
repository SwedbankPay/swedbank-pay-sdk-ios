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

import Foundation
import PassKit

enum SwedbankPaymentNetwork: String, Hashable, Equatable {
    case amex = "amex"
    case carteBancaires = "cartebancaires"
    case chinaUnionPay = "chinaunionpay"
    case discover = "discover"
    case interac = "interac"
    case idCredit = "id"
    case JCB = "jcb"
    case masterCard = "mastercard"
    case quicPay = "quicpay"
    case suica = "suica"
    case visa = "visa"

    var pkPaymentNetwork: PKPaymentNetwork {
        switch self {
        case .amex:
            return .amex
        case .carteBancaires:
            return .carteBancaires
        case .chinaUnionPay:
            return .chinaUnionPay
        case .discover:
            return .discover
        case .interac:
            return .interac
        case .idCredit:
            return .idCredit
        case .JCB:
            return .JCB
        case .masterCard:
            return .masterCard
        case .quicPay:
            return .quicPay
        case .suica:
            return .suica
        case .visa:
            return .visa
        }
    }

    init?(pkPaymentNetwork: PKPaymentNetwork) {
        switch pkPaymentNetwork {
        case .amex:
            self = .amex
        case .carteBancaires:
            self = .carteBancaires
        case .chinaUnionPay:
            self = .chinaUnionPay
        case .discover:
            self = .discover
        case .interac:
            self = .interac
        case .idCredit:
            self = .idCredit
        case .JCB:
            self = .JCB
        case .masterCard:
            self = .masterCard
        case .quicPay:
            self = .quicPay
        case .suica:
            self = .suica
        case .visa:
            self = .visa
        default:
            return nil
        }
    }
    
    init?(rawValueIgnoringCase network: String) {
        self.init(rawValue: network.lowercased())
    }
}

enum SwedbankMerchantCapability: String, Hashable, Equatable {
    case supports3DS
    case supportsDebit
    case supportsCredit
}

extension Collection where Element == SwedbankMerchantCapability {
    func pkMerchantCapabilities() -> PKMerchantCapability {
        var capabilities: PKMerchantCapability = []
        
        for capability in self {
            switch capability {
            case .supports3DS:
                capabilities.insert(.threeDSecure)
            case .supportsDebit:
                capabilities.insert(.debit)
            case .supportsCredit:
                capabilities.insert(.credit)
            }
        }
        
        return capabilities
    }
}
