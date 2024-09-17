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

struct PaymentSessionModel: Codable, Hashable {
    let culture: String?
    let methods: [MethodBaseModel]?
    let urls: UrlsModel?
    let instrumentModePaymentMethod: String?
}

extension PaymentSessionModel {
    var allMethodOperations: [OperationOutputModel] {
        guard let methods = methods else {
            return []
        }

        var allOperations = [OperationOutputModel]()

        for method in methods {
            if let operations = method.operations {
                allOperations.append(contentsOf: operations)
            }
        }

        return allOperations
    }
}

struct UrlsModel: Codable, Hashable {
    let completeUrl: URL?
    let cancelUrl: URL?
    let paymentUrl: URL?
    let hostUrls: [URL]?
    let termsOfServiceUrl: URL?
}
