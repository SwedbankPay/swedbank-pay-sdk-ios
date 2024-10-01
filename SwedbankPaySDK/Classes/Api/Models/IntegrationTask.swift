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

struct IntegrationTask: Codable, Hashable {
    let rel: IntegrationTaskRel?
    let href: String?
    let method: String?
    let contentType: String?
    let expects: [ExpectationModel]?
}

enum IntegrationTaskRel: Codable, Equatable, Hashable {
    case scaMethodRequest
    case scaRedirect
    case launchClientApp
    case walletSdk

    case unknown(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let type = try container.decode(String.self)

        switch type {
        case Self.scaMethodRequest.rawValue:    self = .scaMethodRequest
        case Self.scaRedirect.rawValue:         self = .scaRedirect
        case Self.launchClientApp.rawValue:     self = .launchClientApp
        case Self.walletSdk.rawValue:           self = .walletSdk
        default:                                self = .unknown(type)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    var rawValue: String {
        switch self {
        case .scaMethodRequest:     "sca-method-request"
        case .scaRedirect:          "sca-redirect"
        case .launchClientApp:      "launch-client-app"
        case .walletSdk:            "wallet-sdk"
        case .unknown(let value):   value
        }
    }
}

enum ExpectationModel: Codable, Equatable, Hashable {
    case string(name: String?, value: String?)
    case stringArray(name: String?, value: [String]?)

    case unknown(String)

    var name: String? {
        switch self {
        case .string(let name, _):
            return name
        case .stringArray(let name, _):
            return name
        case .unknown:
            return "unknown"
        }
    }

    var value: String? {
        switch self {
        case .string(_, let value):
            return value
        case .stringArray:
            return nil
        case .unknown:
            return nil
        }
    }

    var stringArray: [String]? {
        switch self {
        case .string:
            return nil
        case .stringArray(_, let value):
            return value
        case .unknown:
            return nil
        }
    }


    private enum CodingKeys: String, CodingKey {
        case name, type, value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "string":
            self = .string(
                name: try? container.decode(String?.self, forKey: CodingKeys.name),
                value: try? container.decode(String?.self, forKey: CodingKeys.value)
            )
        case "string[]":
            self = .stringArray(
                name: try? container.decode(String?.self, forKey: CodingKeys.name),
                value: try? container.decode([String]?.self, forKey: CodingKeys.value)
            )
        default:
            self = .unknown(type)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let name, let value):
            try container.encode(name)
            try container.encode(value)
        case .stringArray(let name, let value):
            try container.encode(name)
            try container.encode(value)
        case .unknown(let type):
            try container.encode(type)
        }
    }
}

extension Array where Element == ExpectationModel {
    var httpBody: Data? {
        return self.compactMap({
            switch $0 {
            case .string(let name, let value):
                guard let name = name else {
                    return nil
                }

                let value = value?.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? ""

                return name + "=" + value
            default:
                return nil
            }
        })
        .joined(separator: "&")
        .data(using: .utf8)
    }
}
