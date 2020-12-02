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

struct ConsumersLink: Link {
    let href: URL
    
    func post(
        api: MerchantBackendApi,
        consumer: SwedbankPaySDK.Consumer,
        userData: Any?,
        completion: @escaping (Result<ConsumerSession, SwedbankPaySDK.MerchantBackendError>) -> Void
    ) {
        _ = request(api: api, method: .post, body: consumer, completion: completion) { decorator, request in
            decorator.decorateInitiateConsumerSession(request: &request, consumer: consumer, userData: userData)
        }
    }
}
