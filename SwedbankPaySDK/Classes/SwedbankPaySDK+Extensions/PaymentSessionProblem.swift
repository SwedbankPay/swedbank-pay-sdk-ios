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

public extension SwedbankPaySDK {
    /// Payment session problem returned with `sdkProblemOccurred`
    enum PaymentSessionProblem {
        case paymentSessionEndStateReached
        case paymentSessionAPIRequestFailed(error: Error, retry: (()->Void)?)
        case paymentControllerPaymentFailed(error: Error, retry: (()->Void)?)
        case paymentSession3DSecureViewControllerLoadFailed(error: Error, retry: (()->Void)?)
        case internalInconsistencyError
        case automaticConfigurationFailed

        var rawValue: String {
            switch self {
            case .paymentSessionEndStateReached:                    "paymentSessionEndStateReached"
            case .paymentSessionAPIRequestFailed:                   "paymentSessionAPIRequestFailed"
            case .paymentControllerPaymentFailed:                   "paymentControllerPaymentFailed"
            case .paymentSession3DSecureViewControllerLoadFailed:   "paymentSession3DSecureViewControllerLoadFailed"
            case .internalInconsistencyError:                       "internalInconsistencyError"
            case .automaticConfigurationFailed:                     "automaticConfigurationFailed"
            }
        }
    }
}
