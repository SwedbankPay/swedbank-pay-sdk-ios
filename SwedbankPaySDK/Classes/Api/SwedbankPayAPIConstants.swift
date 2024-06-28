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

struct SwedbankPayAPIConstants {
    static var commonHeaders: [String: String] = [
        HTTPHeaderField.acceptType.rawValue: ContentType.json.rawValue,
        HTTPHeaderField.contentType.rawValue: ContentType.json.rawValue
    ]

    static var requestTimeoutInterval = 10.0
    static var sessionTimeoutInterval = 20.0
    static var creditCardTimoutInterval = 30.0

    static var notificationUrl = "https://fake.payex.com/notification"
}

private enum HTTPHeaderField: String {
    case acceptType = "Accept"
    case contentType = "Content-Type"
}

private enum ContentType: String {
    case json = "application/json"
}