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
import UIKit

protocol BeaconEndpointRouterProtocol {
    var body: [String: Any?]? { get }
}

struct BeaconEndpointRouter: EndpointRouterProtocol {
    let href: String?
    let beacon: Beacon

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'Z"
        return formatter
    }()

    // MARK: - Body
    var body: [String: Any?]? {
        var body: [String: Any?] = ["client": ["userAgent": SwedbankPaySDK.VersionReporter.userAgent,
                                               "ipAddress": NetworkStatusProvider.getAddress(for: .wifi) ?? NetworkStatusProvider.getAddress(for: .cellular) ?? "",
                                               "screenHeight": String(Int32(UIScreen.main.nativeBounds.height)),
                                               "screenWidth": String(Int32(UIScreen.main.nativeBounds.width)),
                                               "screenColorDepth": String(24)],
                                    "service": ["name": "SwedbankPaySDK-iOS",
                                                "version": SwedbankPaySDK.VersionReporter.currentVersion],
                                    "event": ["created": dateFormatter.string(from: beacon.created),
                                              "action": beacon.actionType.action]]

        switch beacon.actionType {
        case .sdkMethodInvoked(name: let name, succeeded: let succeeded, values: let values):
            body["method"] = ["name": name,
                              "sdk": true,
                              "succeeded": succeeded]
            if let values = values {
                body["extensions"] = ["values": values]
            }
        case .sdkCallbackInvoked(name: let name, succeeded: let succeeded, values: let values):
            body["method"] = ["name": name,
                              "sdk": true,
                              "succeeded": succeeded]
            if let values = values {
                body["extensions"] = ["values": values]
            }
        case .httpRequest(duration: let duration, requestUrl: let requestUrl, method: let method, responseStatusCode: let responseStatusCode, values: let values):
            body["event"] = ["created": dateFormatter.string(from: beacon.created),
                             "action": beacon.actionType.action,
                             "duration": duration]

            var http: [String: Any] = ["requestUrl": requestUrl,
                                       "method": method]
            if let responseStatusCode = responseStatusCode {
                http["responseStatusCode"] = responseStatusCode
            }
            body["http"] = http

            if let values = values {
                body["extensions"] = ["values": values]
            }
        case .launchClientApp(values: let values):
            if let values = values {
                body["extensions"] = ["values": values]
            }
        case .clientAppCallback(values: let values):
            if let values = values {
                body["extensions"] = ["values": values]
            }
        }

        return body
    }
}

extension BeaconEndpointRouter {
    func makeRequest(handler: @escaping (Result<Void, Error>) -> Void) {
        let requestStartTimestamp: Date = Date()

        requestWithDataResponse { result in
            switch result {
            case .success(let data):
                handler(.success(()))
            case .failure(let error):
                handler(.failure(error))
            }
        }
    }

    private func requestWithDataResponse(handler: @escaping (Result<Void, Error>) -> Void) {
        guard let href = href,
              var components = URLComponents(string: href) else {
            handler(.failure(SwedbankPayAPIError.invalidUrl))
            return
        }

        if components.scheme == "http" {
            components.scheme = "https"
        }

        guard let url = components.url else {
            handler(.failure(SwedbankPayAPIError.invalidUrl))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = SwedbankPayAPIConstants.commonHeaders

        if let body = body, let jsonData = try? JSONSerialization.data(withJSONObject: body) {
            request.httpBody = jsonData
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let response = response as? HTTPURLResponse,
                  response.statusCode == 204 else {
                handler(.failure(error ?? SwedbankPayAPIError.unknown))

                return
            }

            handler(.success(()))
        }.resume()
    }
}
