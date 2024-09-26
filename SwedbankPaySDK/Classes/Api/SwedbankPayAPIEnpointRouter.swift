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
import PassKit

struct Endpoint {
    let router: EnpointRouter?
    let href: String?
    let method: String?
}

enum EnpointRouter {
    case expandMethod(instrument: SwedbankPaySDK.PaymentAttemptInstrument)
    case startPaymentAttempt(instrument: SwedbankPaySDK.PaymentAttemptInstrument, culture: String?)
    case createAuthentication(methodCompletionIndicator: String, notificationUrl: String)
    case completeAuthentication(cRes: String)
    case getPayment
    case preparePayment
    case acknowledgeFailedAttempt
    case abortPayment
    case applePay(paymentPayload: String)
}

protocol EndpointRouterProtocol {
    var body: [String: Any?]? { get }
    var requestTimeoutInterval: TimeInterval { get }
    var sessionTimeoutInterval: TimeInterval { get }
}

struct SwedbankPayAPIEnpointRouter: EndpointRouterProtocol {
    let endpoint: Endpoint
    let sessionStartTimestamp: Date

    var body: [String: Any?]? {
        switch endpoint.router {
        case .expandMethod(instrument: let instrument):
            return ["instrumentName": instrument.identifier]
        case .startPaymentAttempt(let instrument, let culture):
            switch instrument {
            case .swish(let msisdn):
                return ["culture": culture,
                        "msisdn": msisdn,
                        "client": ["userAgent": SwedbankPaySDK.VersionReporter.userAgent,
                                   "ipAddress": NetworkStatusProvider.getAddress(for: .wifi) ?? NetworkStatusProvider.getAddress(for: .cellular) ?? "",
                                   "screenHeight": String(Int32(UIScreen.main.nativeBounds.height)),
                                   "screenWidth": String(Int32(UIScreen.main.nativeBounds.width)),
                                   "screenColorDepth": String(24)]
                ]
            case .creditCard(let prefill):
                return ["culture": culture,
                        "paymentToken": prefill.paymentToken,
                        "cardNumber": prefill.maskedPan,
                        "cardExpiryMonth": prefill.expiryMonth,
                        "cardExpiryYear": prefill.expiryYear,
                        "client": ["userAgent": SwedbankPaySDK.VersionReporter.userAgent,
                                   "ipAddress": NetworkStatusProvider.getAddress(for: .wifi) ?? NetworkStatusProvider.getAddress(for: .cellular) ?? "",
                                   "screenHeight": String(Int32(UIScreen.main.nativeBounds.height)),
                                   "screenWidth": String(Int32(UIScreen.main.nativeBounds.width)),
                                   "screenColorDepth": String(24)]
                ]
            case .applePay:
                return ["culture": culture,
                        "client": ["userAgent": SwedbankPaySDK.VersionReporter.userAgent,
                                   "ipAddress": NetworkStatusProvider.getAddress(for: .wifi) ?? NetworkStatusProvider.getAddress(for: .cellular) ?? "",
                                   "screenHeight": String(Int32(UIScreen.main.nativeBounds.height)),
                                   "screenWidth": String(Int32(UIScreen.main.nativeBounds.width)),
                                   "screenColorDepth": String(24)]
                ]
            }
        case .preparePayment:
            return ["integration": "HostedView",
                    "deviceAcceptedWallets": PKPaymentAuthorizationController.canMakePayments() ? "ApplePay" : "",
                    "client": ["userAgent": SwedbankPaySDK.VersionReporter.userAgent,
                               "ipAddress": NetworkStatusProvider.getAddress(for: .wifi) ?? NetworkStatusProvider.getAddress(for: .cellular) ?? "",
                               "screenHeight": String(Int32(UIScreen.main.nativeBounds.height)),
                               "screenWidth": String(Int32(UIScreen.main.nativeBounds.width)),
                               "screenColorDepth": String(24)],
                    "browser": ["acceptHeader": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                                "languageHeader": Locale.current.identifier.replacingOccurrences(of: "_", with: "-"),
                                "timeZoneOffset": TimeZone.current.minutesFromGMT(),
                                "javascriptEnabled": true],
                    "service": ["name": "SwedbankPaySDK-iOS",
                                "version": SwedbankPaySDK.VersionReporter.currentVersion]
            ]
        case .createAuthentication(let methodCompletionIndicator, let notificationUrl):
            return ["methodCompletionIndicator": methodCompletionIndicator,
                    "notificationUrl": notificationUrl,
                    "requestWindowSize": "FULLSCREEN",
                    "client": ["userAgent": SwedbankPaySDK.VersionReporter.userAgent,
                               "ipAddress": NetworkStatusProvider.getAddress(for: .wifi) ?? NetworkStatusProvider.getAddress(for: .cellular) ?? "",
                               "screenHeight": String(Int32(UIScreen.main.nativeBounds.height)),
                               "screenWidth": String(Int32(UIScreen.main.nativeBounds.width)),
                               "screenColorDepth": String(24)],
                    "browser": ["acceptHeader": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                                "languageHeader": Locale.current.identifier.replacingOccurrences(of: "_", with: "-"),
                                "timeZoneOffset": TimeZone.current.minutesFromGMT(),
                                "javascriptEnabled": true]
            ]
        case .completeAuthentication(let cRes):
            return ["cRes": cRes,
                    "client": ["userAgent": SwedbankPaySDK.VersionReporter.userAgent,
                               "ipAddress": NetworkStatusProvider.getAddress(for: .wifi) ?? NetworkStatusProvider.getAddress(for: .cellular) ?? ""],
            ]
        case .applePay(let paymentPayload):
            return ["instrument": "ApplePay",
                    "paymentPayload": paymentPayload]
        default:
            return nil
        }
    }

    var requestTimeoutInterval: TimeInterval {
        switch endpoint.router {
        case .startPaymentAttempt(let instrument, _):
            switch instrument {
            case .creditCard:
                return SwedbankPayAPIConstants.creditCardTimoutInterval
            default:
                return SwedbankPayAPIConstants.requestTimeoutInterval
            }
        case .createAuthentication,
             .completeAuthentication:
            return SwedbankPayAPIConstants.creditCardTimoutInterval
        default:
            return SwedbankPayAPIConstants.requestTimeoutInterval
        }
    }

    var sessionTimeoutInterval: TimeInterval {
        switch endpoint.router {
        case .startPaymentAttempt(let instrument, _):
            switch instrument {
            case .creditCard:
                return SwedbankPayAPIConstants.creditCardTimoutInterval
            default:
                return SwedbankPayAPIConstants.sessionTimeoutInterval
            }
        case .createAuthentication,
             .completeAuthentication:
            return SwedbankPayAPIConstants.creditCardTimoutInterval
        default:
            return SwedbankPayAPIConstants.sessionTimeoutInterval
        }
    }
}

extension SwedbankPayAPIEnpointRouter {
    func makeRequest(handler: @escaping (Result<PaymentOutputModel?, Error>) -> Void) {
        let requestStartTimestamp: Date = Date()

        requestWithDataResponse(requestStartTimestamp: requestStartTimestamp) { result in
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
            decodedData = try CustomDateDecoder().decode(T.self, from: data)
        } catch {
            throw error
        }

        return decodedData
    }

    private func requestWithDataResponse(requestStartTimestamp: Date, handler: @escaping (Result<Data, Error>) -> Void) {
        guard let href = endpoint.href,
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
        request.httpMethod = endpoint.method
        request.allHTTPHeaderFields = SwedbankPayAPIConstants.commonHeaders
        request.timeoutInterval = requestTimeoutInterval

        if let body = body, let jsonData = try? JSONSerialization.data(withJSONObject: body) {
            request.httpBody = jsonData
        }

        URLSession.shared.dataTask(with: request) { data, response, error in

            var responseStatusCode: Int?
            if let response = response as? HTTPURLResponse {
                responseStatusCode = response.statusCode
            }

            var values: [String: Any]?
            if let error = error as? NSError {
                values = ["errorDescription": error.localizedDescription,
                          "errorCode": error.code,
                          "errorDomain": error.domain]
            }

            BeaconService.shared.log(type: .httpRequest(duration: Int32((Date().timeIntervalSince(requestStartTimestamp) * 1000.0).rounded()),
                                                        requestUrl: endpoint.href ?? "",
                                                        method: endpoint.method ?? "",
                                                        responseStatusCode: responseStatusCode,
                                                        values: values))

            guard let response = response as? HTTPURLResponse, !(500...599 ~= response.statusCode) else {
                guard Date().timeIntervalSince(requestStartTimestamp) < requestTimeoutInterval &&
                        Date().timeIntervalSince(sessionStartTimestamp) < sessionTimeoutInterval else {
                    handler(.failure(error ?? SwedbankPayAPIError.unknown))
                    return
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    let requestStartTimestamp: Date = Date()

                    requestWithDataResponse(requestStartTimestamp: requestStartTimestamp, handler: handler)
                }

                return
            }

            guard let data, 200...204 ~= response.statusCode else {
                handler(.failure(error ?? SwedbankPayAPIError.unknown))

                return
            }

            handler(.success(data))
        }.resume()
    }
}
