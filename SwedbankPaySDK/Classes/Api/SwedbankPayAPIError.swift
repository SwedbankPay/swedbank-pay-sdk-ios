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

enum SwedbankPayAPIError: Error {
    case invalidUrl
    case operationNotAllowed
    case genericOperationError
    case unknown
}

extension SwedbankPayAPIError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidUrl:
            return SwedbankPaySDKResources.localizedString(key: "swedbankpaysdk_native_invalid_url")
        case .operationNotAllowed:
            return SwedbankPaySDKResources.localizedString(key: "swedbankpaysdk_native_abort_payment_not_allowed")
        case .genericOperationError, .unknown:
            return SwedbankPaySDKResources.localizedString(key: "swedbankpaysdk_native_unknown")
        }
    }
}

extension SwedbankPayAPIError {
    struct ErrorObject: Decodable {
        let type: String
        let status: Int
        let title: String?
        let detail: String?
        
        var apiError: SwedbankPayAPIError {
            switch status {
            case 409:
                if type == "https://api.payex.com/psp/errordetail/paymentsessions/operationnotallowed" {
                    return .operationNotAllowed
                } else {
                    return .genericOperationError
                }
            default:
                return .unknown
            }
        }
    }
}
