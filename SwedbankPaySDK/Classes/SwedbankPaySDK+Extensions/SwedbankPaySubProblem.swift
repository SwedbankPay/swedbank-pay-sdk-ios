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

public extension SwedbankPaySDK {
    
    /// Object detailing the reason for a `SwedbankPayProblem`.
    ///
    /// See [https://developer.payex.com/xwiki/wiki/developer/view/Main/ecommerce/technical-reference/#HProblems].
    struct SwedbankPaySubProblem: Mappable {
        public var name: String?
        public var description: String?
        
        public init?(map: Map) {
        }
        
        public mutating func mapping(map: Map) {
             name <- map["name"]
             description <- map["description"]
        }
    }
}