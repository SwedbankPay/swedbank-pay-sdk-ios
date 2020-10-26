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

import Foundation

struct Operation: Decodable {
    var href: String?
    var rel: String?
    
    enum TypeString: String {
        case viewConsumerIdentification = "view-consumer-identification"
        case viewPaymentOrder = "view-paymentorder"
    }
}

extension Array where Element == Operation {
    func find(rel: String) -> URL? {
        let operation = first { $0.rel == rel }
        let href = (operation?.href).flatMap(URL.init(string:))
        return href
    }
    
    func require(rel: String) throws -> URL {
        guard let href = find(rel: rel) else {
            throw SwedbankPaySDK.MerchantBackendError.missingRequiredOperation(rel)
        }
        return href
    }
}
