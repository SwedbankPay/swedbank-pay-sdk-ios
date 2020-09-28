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
    
    /// A `ClientProblem` always implies a HTTP status in 400-499.
    enum ClientProblem {
        
        /// Base class for `ClientProblem` defined by the example backend
        case mobileSDK(MobileSDKProblem)
        
        /// Base class for `ClientProblem` defined by the Swedbank Pay backend.
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
        
        /// `ClientProblem` with an unrecognized type.
        case unknown(
            type: String,
            title: String?,
            status: Int,
            detail: String?,
            instance: String?,
            raw: [String: Any]
        )
        
        /// Pseudo-problem, not actually parsed from an application/problem+json response. This problem is emitted if the server response is in
        /// an unexpected format and the HTTP status is in the Client Error range (400-499).
        case unexpectedContent(
            status: Int,
            contentType: String?,
            body: Data?
        )
        
        public enum MobileSDKProblem {
            
            /// The merchant backend rejected the request because its authentication headers were invalid.
            case unauthorized (
                message: String?,
                raw: [String: Any]
            )
            
            /// The merchant backend did not understand the request.
            case invalidRequest (
                message: String?,
                raw: [String: Any]
            )
        }
        public enum SwedbankPayProblem {
            
            /// The request could not be handled because the request was malformed somehow (e.g. an invalid field value).
            case inputError
            
            /// The request was understood, but the service is refusing to fulfill it. You may not have access to the requested resource.
            case forbidden
            
            /// The requested resource was not found.
            case notFound
        }
    }
}
