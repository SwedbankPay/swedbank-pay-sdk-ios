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

public extension SwedbankPaySDK {
    /// Swedbank Pay Operation. Operations are invoked by making an HTTP request.
    ///
    /// Please refer to the Swedbank Pay documentation
    /// (https://developer.swedbankpay.com/checkout-v3/payments-only/features/technical-reference/operations).
     struct Operation: Codable {
         /// The purpose of the operation. The exact meaning is dependent on the Operation context.
         public var rel: String?
         /// The request method
         public var method: String?
         /// The request URL
         public var href: String?
         /// The Content-Type of the response
         public var contentType: String?
          
         public var url: URL? {
             href.flatMap(URL.init(string:))
         }
    }
    
    struct OperationRelation: RawRepresentable, Hashable, Codable {
        
        public var rawValue: String
        public init(rawValue: String) {
            self.rawValue = rawValue
        }
        
        public static let viewConsumerIdentification = OperationRelation(rawValue: "view-consumer-identification")
        public static let viewPaymentOrder = OperationRelation(rawValue: "view-paymentorder")
        public static let viewPaymentLink = OperationRelation(rawValue: "view-checkout")
        public static let setInstrumentLink = OperationRelation(rawValue: "set-instrument")
        public static let abort = OperationRelation(rawValue: "abort")
    }
}

public extension Array where Element == SwedbankPaySDK.Operation {
    func findOperation(rel: SwedbankPaySDK.OperationRelation) -> SwedbankPaySDK.Operation? {
        first { $0.rel == rel.rawValue }
    }
}
