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

enum SDKProblemString: String {
    case endPointsListEmpty = "Server returned empty endpoints list"
    case consumersEndpointMissing = "Requested consumers endpoint is missing"
    case paymentordersEndpointIsMissing = "Requested paymentorders endpoint is missing"
    case merchantDataSerializationFailed = "Error serializing merchantData"
    case consumerIdentificationWebviewCreationFailed = "Failed to create consumer identification webview"
    case paymentWebviewCreationFailed = "Failed to create payment webview"
    case consumerDataEncodingFailed = "Failed to encode consumerData"
    
    case backendUrlMissing = "BackendUrl is missing"
    case domainWhitelistError = "Non-whitelisted domain: "
    case backendRequestUrlCreationFailed = "Failed to create backend request URL"
    case merchantDataMissing = "MerchantData is missing"
    case consumerDataMissing = "ConsumerData is missing"
}
