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

struct OperationsList: Mappable, Decodable {
    var operations: [Operation] = []
    var state: Operation.State = .Undefined
    var url: String = ""
    var message: String? = ""
    
    init?(map: Map) {
    }
    
    mutating func mapping(map: Map) {
        operations <- map["operations"]
        state <- (map["state"], EnumTransform<Operation.State>())
        url <- map["url"]
        message <- map["message"]
    }
}
