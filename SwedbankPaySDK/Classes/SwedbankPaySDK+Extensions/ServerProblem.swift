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
    
    /// Any unexpected response where the HTTP status is outside 400-499 results in a `ServerProblem`; usually it means the status was in 500-599.
    enum ServerProblem {
        
        /// Base class for `ServerProblem` defined by the example backend.
        case mobileSDK(MobileSDKProblem)
        
        /// Base class for `ServerProblem` defined by the Swedbank Pay backend.
        ///
        /// [https://developer.payex.com/xwiki/wiki/developer/view/Main/ecommerce/technical-reference/#HProblems]
        case swedbankPay(
            type: SwedbankPayProblem,
            title: String?,
            status: Int,
            detail: String?,
            instance: String?,
            action: String?,
            problems: [SwedbankPaySubProblem]?,
            raw: [String: Any]
        )
        
        /// `ServerProblem` with an unrecognized type.
        case unknown(
            type: String,
            title: String?,
            status: Int,
            detail: String?,
            instance: String?,
            raw: [String: Any]
        )
        
        /// Pseudo-problem, not actually parsed from an application/problem+json response. This problem is emitted if the server response is in
        /// an unexpected format and the HTTP status is not in the Client Error range.
        case unexpectedContent(
            status: Int,
            contentType: String?,
            body: Data?
        )
        
        public enum MobileSDKProblem {
            
            /// The merchant backend timed out trying to connect to the Swedbank Pay backend.
            case backendConnectionTimeout (
                message: String?,
                raw: [String: Any]
            )
            
            /// The merchant backend failed to connect to the Swedbank Pay backend.
            case backendConnectionFailure (
                message: String?,
                raw: [String: Any]
            )
            
            /// The merchant backend received an invalid response from the Swedbank Pay backend.
            case invalidBackendResponse (
                status: Int,
                gatewayStatus: Int,
                body: String?,
                raw: [String: Any]
            )
        }
        public enum SwedbankPayProblem {
            
            /// A generic error message. HTTP Status code 500.
            case systemError
            
            /// An error relating to configuration issues. HTTP Status code 500.
            case configurationError
        }
    }
}
