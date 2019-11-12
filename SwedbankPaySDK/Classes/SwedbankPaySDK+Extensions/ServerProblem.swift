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

public extension SwedbankPaySDK {
    
    /// Any unexpected response where the HTTP status is outside 400-499 results in a `ServerProblem`; usually it means the status was in 500-599.
    enum ServerProblem {
        
        /// Base class for `ServerProblem` defined by the example backend.
        case MobileSDK(MobileSDKProblem)
        
        /// Base class for `ServerProblem` defined by the Swedbank Pay backend.
        ///
        /// [https://developer.payex.com/xwiki/wiki/developer/view/Main/ecommerce/technical-reference/#HProblems]
        case SwedbankPay(
            type: SwedbankPayProblem,
            title: String?,
            detail: String?,
            instance: String?,
            action: String?,
            problems: [SwedbankPaySubProblem]?,
            raw: String?
        )
        
        /// `ServerProblem` with an unrecognized type.
        case Unknown(
            type: String?,
            title: String?,
            status: Int,
            detail: String?,
            instance: String?,
            raw: String?
        )
        
        /// Pseudo-problem, not actually parsed from an application/problem+json response. This problem is emitted if the server response is in
        /// an unexpected format and the HTTP status is not in the Client Error range.
        case UnexpectedContent(
            status: Int,
            contentType: String?,
            body: String?
        )
        
        public enum MobileSDKProblem {
            
            /// The merchant backend timed out trying to connect to the Swedbank Pay backend.
            case BackendConnectionTimeout (
                message: String?,
                raw: String?
            )
            
            /// The merchant backend failed to connect to the Swedbank Pay backend.
            case BackendConnectionFailure (
                message: String?,
                raw: String?
            )
            
            /// The merchant backend received an invalid response from the Swedbank Pay backend.
            case InvalidBackendResponse (
                body: String?,
                raw: String?
            )
        }
        public enum SwedbankPayProblem {
            
            /// A generic error message. HTTP Status code 500.
            case SystemError
            
            /// An error relating to configuration issues. HTTP Status code 500.
            case ConfigurationError
        }
    }
}
