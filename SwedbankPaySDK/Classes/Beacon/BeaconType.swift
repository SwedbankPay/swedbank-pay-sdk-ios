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

enum BeaconType {
    case sdkMethodInvoked(name: String, succeeded: Bool, values: [String: String?]?)
    case sdkCallbackInvoked(name: String, succeeded: Bool, values: [String: String?]?)
    case httpRequest(duration: Int32, requestUrl: String, method: String, responseStatusCode: Int?, values: [String: String?]?)
    case launchClientApp(values: [String: String?]?)
    case clientAppCallback(values: [String: String?]?)

    var action: String {
        switch self {
        case .sdkMethodInvoked:
            return "SDKMethodInvoked"
        case .sdkCallbackInvoked:
            return "SDKCallbackInvoked"
        case .httpRequest:
            return "HttpRequest"
        case .launchClientApp:
            return "LaunchClientApp"
        case .clientAppCallback:
            return "ClientAppCallback"
        }
    }
}
