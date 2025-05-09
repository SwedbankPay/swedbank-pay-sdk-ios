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

struct Endpoint {
    let router: EndpointRouter?
    let href: String?
    let method: String?
}

enum FailPaymentAttemptProblemType: String {
    case userCancelled = "UserCancelled"
    case technicalError = "TechnicalError"
    case clientAppLaunchFailed = "ClientAppLaunchFailed"
}

enum EndpointRouter {
    case expandMethod(instrument: SwedbankPaySDK.PaymentAttemptInstrument)
    case startPaymentAttempt(instrument: SwedbankPaySDK.PaymentAttemptInstrument, culture: String?)
    case createAuthentication(methodCompletionIndicator: String, notificationUrl: String)
    case completeAuthentication(cRes: String)
    case getPayment
    case preparePayment
    case acknowledgeFailedAttempt
    case abortPayment
    case attemptPayload(paymentPayload: String)
    case customizePayment(instrument: SwedbankPaySDK.PaymentAttemptInstrument?, paymentMethod: String?, restrictToPaymentMethods: [String]?)
    case failPaymentAttempt(problemType: FailPaymentAttemptProblemType, errorCode: String?)
}

protocol EndpointRouterProtocol {
    var body: [String: Any?]? { get }
    var requestTimeoutInterval: TimeInterval { get }
    var sessionTimeoutInterval: TimeInterval { get }
}

struct SwedbankPayAPIEndpointRouter: EndpointRouterProtocol {
    let endpoint: Endpoint
    let sessionStartTimestamp: Date

    var body: [String: Any?]? {
        switch endpoint.router {
        case .expandMethod(instrument: let instrument):
            return ["paymentMethod": instrument.paymentMethod]
        case .startPaymentAttempt(let instrument, let culture):
            switch instrument {
            case .swish(let msisdn):
                return ["culture": culture,
                        "msisdn": msisdn,
                        "client": client(withScreenInformation: true, withClientType: true)
                ]
            case .creditCard(let prefill):
                return ["culture": culture,
                        "paymentToken": prefill.paymentToken,
                        "client": client(withScreenInformation: true, withClientType: true)
                ]
            case .applePay:
                return ["culture": culture,
                        "client": client(withScreenInformation: true, withClientType: true)
                ]
            case .newCreditCard:
                return nil
            }
        case .preparePayment:
            return ["integration": "App",
                    "deviceAcceptedWallets": "ApplePay;ClickToPay",
                    "client": client(withScreenInformation: true),
                    "browser": browser(),
                    "service": ["name": "SwedbankPaySDK-iOS",
                                "version": SwedbankPaySDK.VersionReporter.currentVersion],
                    "presentationSdk": ["name": "iOS",
                                        "version": SwedbankPaySDK.VersionReporter.currentVersion]
            ]
        case .createAuthentication(let methodCompletionIndicator, let notificationUrl):
            return ["methodCompletionIndicator": methodCompletionIndicator,
                    "notificationUrl": notificationUrl,
                    "requestWindowSize": "FULLSCREEN",
                    "client": client(withScreenInformation: true),
                    "browser": browser()
            ]
        case .completeAuthentication(let cRes):
            return ["cRes": cRes,
                    "client": client(),
            ]
        case .attemptPayload(let paymentPayload):
            return ["paymentMethod": "ApplePay",
                    "paymentPayload": paymentPayload]
        case .customizePayment(let instrument, let paymentMethod, let restrictToPaymentMethods):

            switch (instrument, paymentMethod, restrictToPaymentMethods) {
            case (nil, nil, let restrictToPaymentMethods?):
                return ["paymentMethod": nil,
                        "restrictToPaymentMethods": restrictToPaymentMethods.isEmpty ? nil : restrictToPaymentMethods]
            case (.newCreditCard(let enabledPaymentDetailsConsentCheckbox), _, _):
                return ["paymentMethod": "CreditCard",
                        "restrictToPaymentMethods": nil,
                        "hideStoredPaymentOptions": true,
                        "showConsentAffirmation" : enabledPaymentDetailsConsentCheckbox,
                ]
            case (nil, let paymentMethod?, nil):
                return ["paymentMethod": paymentMethod,
                        "restrictToPaymentMethods": nil]
            case (let instrument?, nil, nil):
                return ["paymentMethod": instrument.paymentMethod,
                        "restrictToPaymentMethods": nil]
            default:
                return ["paymentMethod": nil,
                        "restrictToPaymentMethods": nil]
            }
        case .failPaymentAttempt(let problemType, let errorCode):
            return ["problemType": problemType.rawValue,
                    "errorCode": errorCode]
        default:
            return nil
        }
    }
    
    private func client(withScreenInformation: Bool = false, withClientType: Bool = false) -> [String: Any?] {
        var client = ["userAgent": SwedbankPaySDK.VersionReporter.userAgent]
        
        if withScreenInformation {
            client["screenHeight"] = String(Int32(UIScreen.main.nativeBounds.height))
            client["screenWidth"] = String(Int32(UIScreen.main.nativeBounds.width))
            client["screenColorDepth"] = String(24)
        }
        
        if withClientType {
            client["clientType"] = "Native"
        }
        
        return client
    }
    
    private func browser() -> [String: Any?] {
        var browser: [String: Any?] = ["acceptHeader": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                                       "timeZoneOffset": TimeZone.current.minutesFromGMT(),
                                       "javascriptEnabled": true]
        
        if #available(iOS 16, *) {
            browser["language"] = Locale.current.identifier(.bcp47)
        } else {
            browser["language"] = Locale.preferredLanguages[0]
        }
        
        return browser
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

extension SwedbankPayAPIEndpointRouter {
    func makeRequest(automaticRetry: Bool = true, handler: @escaping (Result<PaymentOutputModel?, Error>) -> Void) {
        requestWithDataResponse(automaticRetry: automaticRetry) { result in
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

    private func requestWithDataResponse(automaticRetry: Bool = true, handler: @escaping (Result<Data, Error>) -> Void) {
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

        let requestStartTimestamp = Date()

        URLSession.shared.dataTask(with: request) { data, response, error in

            var responseStatusCode: Int?
            if let response = response as? HTTPURLResponse {
                responseStatusCode = response.statusCode
            }

            var values: [String: String]?
            if let error = error as? NSError {
                values = ["errorDescription": error.localizedDescription,
                          "errorCode": String(error.code),
                          "errorDomain": error.domain]
            }

            BeaconService.shared.log(type: .httpRequest(duration: Int32((Date().timeIntervalSince(requestStartTimestamp) * 1000.0).rounded()),
                                                        requestUrl: endpoint.href ?? "",
                                                        method: endpoint.method ?? "",
                                                        responseStatusCode: responseStatusCode,
                                                        values: values))

            guard let response = response as? HTTPURLResponse, !(500...599 ~= response.statusCode) else {
                if automaticRetry {
                    handleServerErrorOrRetry(error ?? SwedbankPayAPIError.unknown, handler: handler)
                } else {
                    handler(.failure(error ?? SwedbankPayAPIError.unknown))
                }
                return
            }
            
            guard let data else {
                handler(.failure(error ?? SwedbankPayAPIError.unknown))
                return
            }
            
            switch response.statusCode {
            case 200...204:
                handler(.success(data))
            default:
                do {
                    let errorObject = try JSONDecoder().decode(SwedbankPayAPIError.ErrorObject.self, from: data)
                    handler(.failure(errorObject.apiError))
                } catch {
                    handler(.failure(SwedbankPayAPIError.unknown))
                }
            }
        }.resume()
    }
    
    private func handleServerErrorOrRetry(_ error: Error, handler: @escaping (Result<Data, Error>) -> Void) {
        guard Date().timeIntervalSince(sessionStartTimestamp) < sessionTimeoutInterval else {
            handler(.failure(error))
            return
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            requestWithDataResponse(handler: handler)
        }
    }
}
