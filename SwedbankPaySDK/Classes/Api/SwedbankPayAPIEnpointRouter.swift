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

protocol EndpointRouterProtocol {
    var body: [String: Any?]? { get }
}

struct SwedbankPayAPIEnpointRouter: EndpointRouterProtocol {
    let model: OperationOutputModel
    let culture: String?
    let instrument: SwedbankPaySDK.PaymentAttemptInstrument?

    var body: [String: Any?]? {
        switch model.rel {
        case .expandMethod:
            return ["instrumentName": instrument?.name]
        case .startPaymentAttempt:
            switch instrument {
            case .swish(let msisdn):
                return ["culture": culture,
                        "msisdn": msisdn,
                        "client": ["ipAddress": NetworkStatusProvider.getAddress(for: .wifi) ?? NetworkStatusProvider.getAddress(for: .cellular) ?? ""]]
            case .creditCard(let paymentToken):
                return ["culture": culture,
                        "paymentToken": paymentToken,
                        "client": ["ipAddress": NetworkStatusProvider.getAddress(for: .wifi) ?? NetworkStatusProvider.getAddress(for: .cellular) ?? ""]]
            case .none:
                return ["culture": culture,
                        "client": ["ipAddress": NetworkStatusProvider.getAddress(for: .wifi) ?? NetworkStatusProvider.getAddress(for: .cellular) ?? ""]]
            }
        case .preparePayment:
            return ["integration": "HostedView",
                    "deviceAcceptedWallets": "",
                    "client": ["userAgent": SwedbankPaySDK.VersionReporter.userAgent,
                               "ipAddress": NetworkStatusProvider.getAddress(for: .wifi) ?? NetworkStatusProvider.getAddress(for: .cellular) ?? "",
                               "screenHeight": String(Int32(UIScreen.main.nativeBounds.height)),
                               "screenWidth": String(Int32(UIScreen.main.nativeBounds.width)),
                               "screenColorDepth": String(24)],
                    "browser": ["acceptHeader": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                                "languageHeader": Locale.current.identifier,
                                "timeZoneOffset": TimeZone.current.offsetFromGMT(),
                                "javascriptEnabled": true],
                    "service": ["name": "SwedbankPaySDK-iOS",
                                "version": SwedbankPaySDK.VersionReporter.currentVersion]
            ]
        default:
            return nil
        }
    }
}

extension SwedbankPayAPIEnpointRouter {
    func makeRequest(handler: @escaping (Result<PaymentOutputModel?, Error>) -> Void) {
        requestWithDataResponse { result in
            switch result {
            case .success(let data):
                do {
                    let result: PaymentOutputModel = try Self.parseData(data: data)
                    handler(.success(result))
                } catch {
                    handler(.success(nil))
                }
            case .failure(let error):
                handler(.failure(error))
            }
        }
    }


    private static func parseData<T: Decodable>(data: Data) throws -> T {
        let decodedData: T

        do {
            decodedData = try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw error
        }

        return decodedData
    }

    private func requestWithDataResponse(handler: @escaping (Result<Data, Error>) -> Void) {
        guard let href = model.href,
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
        request.httpMethod = model.method
        request.allHTTPHeaderFields = SwedbankPayAPIConstants.commonHeaders

        if let body = body, let jsonData = try? JSONSerialization.data(withJSONObject: body) {
            request.httpBody = jsonData
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let response = response as? HTTPURLResponse, 200...299 ~= response.statusCode else {
                handler(.failure(error ?? SwedbankPayAPIError.unknown))
                return
            }

            guard let data else {
                handler(.failure(error ?? SwedbankPayAPIError.unknown))
                return
            }

            handler(.success(data))
        }.resume()
    }
}
