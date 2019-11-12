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

import ObjectMapper

struct Operation: Mappable, Decodable {
    var contentType: String = ""
    var href: String?
    var method: Method = .GET
    var rel: String = ""
    
    init?(map: Map) {
    }
    
    mutating func mapping(map: Map) {
        contentType <- map["contentType"]
        href <- map["href"]
        method <- (map["method"], EnumTransform<Method>())
        rel <- map["rel"]
    }
    
    enum State: String, Decodable {
        case Undefined
        case Ready
        case Pending
        case Failed
        case Aborted
    }

    enum Method: String, Decodable {
        case GET
        case POST
        case PATCH
        case PUT
        case UPDATE
        case DELETE
    }

    enum TypeString: String {
        case viewConsumerIdentification = "view-consumer-identification"
        case viewPaymentOrder = "view-paymentorder"
    }
}
