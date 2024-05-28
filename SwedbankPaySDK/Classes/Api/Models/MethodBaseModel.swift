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
    public enum MethodBaseModel: Codable, Equatable, Hashable {
        case swish(prefills: [SwishMethodPrefillModel]?, operations: [OperationOutputModel]?)
        case creditCard(prefills: [CreditCardMethodPrefillModel]?, operations: [OperationOutputModel]?, cardBrands: [String]?)

        case unknown(String)

        private enum CodingKeys: String, CodingKey {
            case instrument, prefills, operations, cardBrands
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            let type = try container.decode(String.self, forKey: .instrument)
            switch type {
            case "Swish":
                self = .swish(
                    prefills: try? container.decode([SwishMethodPrefillModel]?.self, forKey: CodingKeys.prefills),
                    operations: try? container.decode([OperationOutputModel]?.self, forKey: CodingKeys.operations)
                )
            case "CreditCard":
                self = .creditCard(
                    prefills: try? container.decode([CreditCardMethodPrefillModel].self, forKey: CodingKeys.prefills),
                    operations: try? container.decode([OperationOutputModel]?.self, forKey: CodingKeys.operations),
                    cardBrands: try? container.decode([String]?.self, forKey: CodingKeys.cardBrands)
                )
            default:
                self = .unknown(type)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .swish(let prefills, let operations):
                try container.encode(prefills)
                try container.encode(operations)
            case .creditCard(let prefills, let operations, let cardBrands):
                try container.encode(prefills)
                try container.encode(operations)
                try container.encode(cardBrands)
            case .unknown(let type):
                try container.encode(type)
            }
        }

        var name: String {
            switch self {
            case .swish:
                return "Swish"
            case .creditCard:
                return "CreditCard"
            case .unknown:
                return "Unknown"
            }
        }

        var operations: [OperationOutputModel]? {
            switch self {
            case .swish(_, let opertations):
                return opertations
            case .creditCard(_, let opertations, _):
                return opertations
            case .unknown:
                return nil
            }
        }

        var isUnknown: Bool {
            if case .unknown = self { return true }

            return false
        }
    }

    public struct SwishMethodPrefillModel: Codable, Hashable {
        let rank: Int32?
        public let msisdn: String?
    }

    public struct CreditCardMethodPrefillModel: Codable, Hashable {
        let rank: Int32?
        let paymentToken: String?
        let cardBrand: String?
        let maskedPan: String?
        let expiryDate: String?
    }
}
