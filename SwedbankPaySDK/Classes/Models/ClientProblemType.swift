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

/// `ClientProblemType` URLs
enum ClientProblemType: String {
    case BadRequest = "https://api.payex.com/psp/errordetail/mobilesdk/badrequest" // 400
    case Unauthorized = "https://api.payex.com/psp/errordetail/mobilesdk/unauthorized" // 401
    case InputError = "https://api.payex.com/psp/errordetail/inputerror"
    case Forbidden = "https://api.payex.com/psp/errordetail/forbidden"
    case NotFound = "https://api.payex.com/psp/errordetail/notfound"
}
