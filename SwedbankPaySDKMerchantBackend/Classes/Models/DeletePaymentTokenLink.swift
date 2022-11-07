// Copyright 2021 Swedbank AB
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

struct DeletePaymentTokenLink: Link {
    let href: URL

    /// - returns: function that cancels this operation
    func patch(
        api: MerchantBackendApi,
        comment: String,
        extraHeaders: [String: String]?,
        completion: @escaping (
            Result<EmptyJsonResponse, SwedbankPaySDK.MerchantBackendError>
        ) -> Void
    ) -> SwedbankPaySDKRequest? {
        let body = Body(comment: comment)
        return request(
            api: api,
            method: .patch,
            body: body,
            completion: completion
        ) { _, request in
            if let extraHeaders = extraHeaders {
                for (key, value) in extraHeaders {
                    request.addValue(value, forHTTPHeaderField: key)
                }
            }
        }
    }
    
    private struct Body: Encodable {
        let state = "Deleted"
        let comment: String
    }
}
