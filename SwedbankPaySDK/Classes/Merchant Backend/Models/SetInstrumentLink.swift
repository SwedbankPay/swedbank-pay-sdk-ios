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

struct SetInstrumentLink: Link {
    let href: URL
    
    /// - returns: function that cancels this operation
    func patch(
        api: MerchantBackendApi,
        instrument: SwedbankPaySDK.Instrument,
        userData: Any?,
        completion: @escaping (Result<PaymentOrderIn, SwedbankPaySDK.MerchantBackendError>) -> Void
    ) -> SwedbankPaySDKRequest? {
        let body = Body(instrument: instrument)
        return request(api: api, method: .patch, body: body, completion: completion) { decorator, request in
            decorator.decoratePaymentOrderSetInstrument(request: &request, instrument: instrument, userData: userData)
        }
    }
    
    private struct Body: Encodable {
        init(instrument: SwedbankPaySDK.Instrument) {
            paymentorder = PaymentOrder(instrument: instrument)
        }
        
        private let paymentorder: PaymentOrder
        private struct PaymentOrder: Encodable {
            let operation = "SetInstrument"
            let instrument: SwedbankPaySDK.Instrument
        }
    }
}
