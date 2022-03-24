//
// Copyright 2020 Swedbank AB
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
import SwedbankPaySDK

public extension SwedbankPaySDK {
    struct SimpleRequestDecorator: SwedbankPaySDKRequestDecorator {
        public var headers: [String: String]
        
        public init(headers: [String: String]) {
            self.headers = headers
        }
        
        public func decorateAny(request: inout URLRequest) {
            request.allHTTPHeaderFields = headers
        }
    }
}

public protocol SwedbankPaySDKRequestDecorator {
    func decorateAny(request: inout URLRequest)
    
    func decorateGetTopLevelResources(request: inout URLRequest)
    
    func decorateInitiateConsumerSession(
        request: inout URLRequest,
        consumer: SwedbankPaySDK.Consumer,
        userData: Any?
    )
    
    func decorateCreatePaymentOrder(
        request: inout URLRequest,
        paymentOrder: SwedbankPaySDK.PaymentOrder,
        userData: Any?
    )
    
    func decoratePaymentOrderSetInstrument(
        request: inout URLRequest,
        instrument: SwedbankPaySDK.Instrument,
        userData: Any?
    )
    
    /// A general method for decorating requests
    func decorateOperation(
        request: inout URLRequest,
        operation: SwedbankPaySDK.OperationRelation,
        userData: Any?
    )
}

public extension SwedbankPaySDKRequestDecorator {
    func decorateAny(request: inout URLRequest) {}
    
    func decorateGetTopLevelResources(request: inout URLRequest) {}
    
    func decorateInitiateConsumerSession(
        request: inout URLRequest,
        consumer: SwedbankPaySDK.Consumer,
        userData: Any?
    ) {}
    
    func decorateCreatePaymentOrder(
        request: inout URLRequest,
        paymentOrder: SwedbankPaySDK.PaymentOrder,
        userData: Any?
    ) {}
    
    func decoratePaymentOrderSetInstrument(
        request: inout URLRequest,
        instrument: SwedbankPaySDK.Instrument,
        userData: Any?
    ) {}
    
    func decorateOperation(
        request: inout URLRequest,
        operation: SwedbankPaySDK.OperationRelation,
        userData: Any?
    ) {}
}
