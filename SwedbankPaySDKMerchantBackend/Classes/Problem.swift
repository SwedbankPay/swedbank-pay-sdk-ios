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

import SwedbankPaySDK

public extension SwedbankPaySDK {
    
    /// Base class for any problems encountered in the payment.
    ///
    /// All problems are either `Client` or `Server` problems. A Client problem is one where there was something wrong with the request
    /// the client app sent to the service. A Client problem always implies an HTTP response status in the Client Error range, 400-499.
    ///
    /// A Server problem is one where the service understood the request, but could not fulfill it. If the backend responds in an unexpected
    /// manner, the situation will be interpreted as a Server error, unless the response status is in 400-499 range, in which case it is still considered a
    /// Client error.
    ///
    /// This separation to Client and Server errors provides a crude but often effective way of distinguishing between temporary service unavailability
    /// and permanent configuration errors.
    ///
    /// Client and Server errors are further divided to specific types. See individual documentation for details.
    enum Problem {
        case client(ClientProblem)
        case server(ServerProblem)
    }
}
