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

    case unknown(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let type = try container.decode(String.self)

        switch type {
        case Self.scaMethodRequest.rawValue:    self = .scaMethodRequest
        case Self.scaRedirect.rawValue:         self = .scaRedirect
        case Self.launchClientApp.rawValue:     self = .launchClientApp
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
        case .unknown(let value):   value
        }
    }
}

struct ExpectationModel: Codable, Hashable {
    let name: String?
    let type: String?
    let value: String?
}

extension Array where Element == ExpectationModel {
    var httpBody: Data? {
        return self.filter({ $0.type == "string" })
            .compactMap({
                guard let name = $0.name else {
                    return nil
                }

                let value = $0.value?.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? ""

                return name + "=" + value
            })
            .joined(separator: "&")
            .data(using: .utf8)
    }
}
