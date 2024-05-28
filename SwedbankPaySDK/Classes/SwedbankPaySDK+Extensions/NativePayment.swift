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

public extension SwedbankPaySDK {
    class NativePayment: CallbackUrlDelegate {
        /// Order information that provides `NativePayment` with callback URLs.
        public var orderInfo: SwedbankPaySDK.ViewPaymentOrderInfo

        /// A delegate to receive callbacks as the state of SwedbankPaySDKController changes.
        public weak var delegate: SwedbankPaySDKDelegate?

        private var ongoingModel: PaymentOutputModel? = nil
        private var sessionIsOngoing: Bool = false
        private var instrument: SwedbankPaySDK.PaymentAttemptInstrument? = nil

        private var hasLaunchClientAppURLs: [URL] = []
        private var hasShownProblemDetails: [ProblemDetails] = []

        private var sessionStartTimestamp = Date()

        public init(orderInfo: SwedbankPaySDK.ViewPaymentOrderInfo) {
            self.orderInfo = orderInfo

            SwedbankPaySDK.addCallbackUrlDelegate(self)
        }

        deinit {
            SwedbankPaySDK.removeCallbackUrlDelegate(self)
        }

        public func startPaymentSession(with sessionApi: String) {
            sessionIsOngoing = true
            instrument = nil
            ongoingModel = nil
            hasLaunchClientAppURLs = []
            hasShownProblemDetails = []

            let model = OperationOutputModel(rel: nil,
                                             href: sessionApi,
                                             method: "GET",
                                             next: nil,
                                             tasks: nil)

            sessionStartTimestamp = Date()
            makeRequest(model: model)

            BeaconService.shared.clear()
            BeaconService.shared.log(type: .sdkMethodInvoked(name: "startPaymentSession",
                                                             succeeded: true,
                                                             values: nil))
        }

        public func makePaymentAttempt(with instrument: SwedbankPaySDK.PaymentAttemptInstrument) {
            guard let ongoingModel = ongoingModel else {
                self.delegate?.sdkProblemOccurred(problem: .internalInconsistencyError)

                return
            }

            self.instrument = instrument

            var succeeded = false
            if let operation = ongoingModel.paymentSession.methods?
                .first(where: { $0.name == instrument.name })?.operations?
                .first(where: { $0.rel == .expandMethod || $0.rel == .startPaymentAttempt || $0.rel == .getPayment }) {
                sessionStartTimestamp = Date()
                makeRequest(model: operation, culture: ongoingModel.paymentSession.culture)
                succeeded = true
            }

            switch instrument {
            case .swish(let msisdn):
                BeaconService.shared.log(type: .sdkMethodInvoked(name: "makePaymentAttempt",
                                                                 succeeded: succeeded,
                                                                 values: ["instrument": "Swish",
                                                                          "msisdn": msisdn]))
            case .creditCard(let paymentToken):
                BeaconService.shared.log(type: .sdkMethodInvoked(name: "makePaymentAttempt",
                                                                 succeeded: succeeded,
                                                                 values: ["instrument": "CreditCard",
                                                                          "paymentToken": paymentToken]))
            }

        }

        public func abortPaymentSession() {
            guard let ongoingModel = ongoingModel else {
                self.delegate?.sdkProblemOccurred(problem: .internalInconsistencyError)

                return
            }

            var succeeded = false
            if let operation = ongoingModel.operations?
                .first(where: { $0.rel == .abortPayment }) {
                sessionStartTimestamp = Date()
                makeRequest(model: operation, culture: ongoingModel.paymentSession.culture)
                succeeded = true
            }

            BeaconService.shared.log(type: .sdkMethodInvoked(name: "abortPaymentSession",
                                                             succeeded: succeeded,
                                                             values: nil))
        }

        private func makeRequest(model: OperationOutputModel, culture: String? = nil) {
            SwedbankPayAPIEnpointRouter(model: model, culture: culture, instrument: instrument, sessionStartTimestamp: sessionStartTimestamp).makeRequest { result in
                switch result {
                case .success(let success):
                    if let model = success {
                        if let eventLogging = model.operations?.first(where: { $0.rel == .eventLogging  }) {
                            BeaconService.shared.href = eventLogging.href
                        }

                        self.sessionOperationHandling(model: model, culture: model.paymentSession.culture)
                    }
                case .failure(let failure):
                    DispatchQueue.main.async {
                        self.delegate?.sdkProblemOccurred(problem: .paymentSessionAPIRequestFailed(error: failure,
                                                                                                   retry: {
                            self.sessionStartTimestamp = Date()
                            self.makeRequest(model: model, culture: culture)
                        }))

                        let error = failure as NSError

                        BeaconService.shared.log(type: .sdkCallbackInvoked(name: "sdkProblemOccurred",
                                                                           succeeded: self.delegate != nil,
                                                                           values: ["problem": "paymentSessionAPIRequestFailed",
                                                                                    "errorDescription": error.localizedDescription,
                                                                                    "errorCode": error.code,
                                                                                    "errorDomain": error.domain]))
                    }
                }
            }
        }

        private func launchClientApp(task: IntegrationTask) {
            guard let href = task.href, var components = URLComponents(string: href) else {
                self.delegate?.sdkProblemOccurred(problem: .internalInconsistencyError)

                return
            }

            // If the scheme is `swish` then we need to add a `callbackurl` if it's not already included in the link.
            if components.scheme == "swish",
               components.queryItems?.contains(where: { $0.name == "callbackurl" }) == false ||
               components.queryItems?.contains(where: { $0.name == "callbackurl" && ($0.value == nil || $0.value?.isEmpty == true) }) == true {
                if let paymentUrl = orderInfo.paymentUrl?.absoluteString {
                    components.queryItems?.append(URLQueryItem(name: "callbackurl", value: paymentUrl.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)))
                }
            }

            if let url = components.url {
                DispatchQueue.main.async {
                    UIApplication.shared.open(url) { complete in
                        if complete {
                            self.hasLaunchClientAppURLs.append(url)
                            self.instrument = nil
                        } else {
                            self.delegate?.sdkProblemOccurred(problem: .clientAppLaunchFailed)

                            BeaconService.shared.log(type: .sdkCallbackInvoked(name: "sdkProblemOccurred",
                                                                               succeeded: self.delegate != nil,
                                                                               values: ["problem": "clientAppLaunchFailed"]))
                        }

                        BeaconService.shared.log(type: .launchClientApp(values: ["callbackUrl": self.orderInfo.paymentUrl?.absoluteString ?? "",
                                                                                 "clientAppLaunchUrl": url.absoluteString,
                                                                                 "launchSucceeded": complete]))
                    }
                }
            }
        }

        private func sessionOperationHandling(model: PaymentOutputModel, culture: String? = nil) {
            ongoingModel = model

            if let modelProblem = model.problem,
               let problemOperation = modelProblem.operation,
               problemOperation.rel == .acknowledgeFailedAttempt {
                if !hasShownProblemDetails.contains(where: { $0.operation?.href == problemOperation.href }) {
                    hasShownProblemDetails.append(modelProblem)
                    DispatchQueue.main.async {
                        self.delegate?.sessionProblemOccurred(problem: modelProblem)

                        BeaconService.shared.log(type: .sdkCallbackInvoked(name: "sessionProblemOccurred",
                                                                           succeeded: self.delegate != nil,
                                                                           values: ["problemTitle": modelProblem.title,
                                                                                    "problemStatus": modelProblem.status,
                                                                                    "problemDetail": modelProblem.detail]))
                    }
                }

                makeRequest(model: problemOperation, culture: culture)
            }

            let operations = model.prioritisedOperations

            if let preparePayment = operations.first(where: { $0.rel == .preparePayment }) {
                makeRequest(model: preparePayment, culture: culture)
            } else if let startPaymentAttempt = operations.first(where: { $0.rel == .startPaymentAttempt }),
                      instrument != nil {
                makeRequest(model: startPaymentAttempt, culture: culture)
                self.instrument = nil
            } else if let launchClientApp = operations.first(where: { $0.firstTask(with: .launchClientApp) != nil }),
                      let tasks = launchClientApp.firstTask(with: .launchClientApp),
                      !hasLaunchClientAppURLs.contains(where: { $0.absoluteString.contains(tasks.href ?? "") }) {
                self.launchClientApp(task: launchClientApp.firstTask(with: .launchClientApp)!)
            } else if let redirectPayer = operations.first(where: { $0.rel == .redirectPayer }) {
                DispatchQueue.main.async {
                    if redirectPayer.href == self.orderInfo.cancelUrl?.absoluteString {
                        self.delegate?.paymentCanceled()

                        BeaconService.shared.log(type: .sdkCallbackInvoked(name: "paymentCanceled",
                                                                           succeeded: self.delegate != nil,
                                                                           values: nil))
                    } else if redirectPayer.href == self.orderInfo.completeUrl.absoluteString {
                        self.delegate?.paymentComplete()

                        BeaconService.shared.log(type: .sdkCallbackInvoked(name: "paymentComplete",
                                                                           succeeded: self.delegate != nil,
                                                                           values: nil))
                    }
                }
                sessionIsOngoing = false
                hasLaunchClientAppURLs = []
                hasShownProblemDetails = []
            } else if let _ = operations.first(where: { $0.rel == .expandMethod }) {
                DispatchQueue.main.async {
                    let availableInstruments: [AvailableInstrument] = model.paymentSession.methods?.compactMap({ model in
                        switch model {
                        case .swish(let prefills, _):
                            return AvailableInstrument.swish(prefills: prefills)
                        case .creditCard(_, _, _):
                            return nil
                        case .unknown(_):
                            return nil
                        }
                    }) ?? []

                    self.delegate?.availableInstrumentsFetched(availableInstruments)

                    BeaconService.shared.log(type: .sdkCallbackInvoked(name: "availableInstrumentsFetched",
                                                                       succeeded: self.delegate != nil,
                                                                       values: ["instruments": availableInstruments.compactMap({ $0.name }).joined(separator: ";")]))
                }
            } else if let getPayment = operations.first(where: { $0.rel == .getPayment }) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.sessionStartTimestamp = Date()
                    self.makeRequest(model: getPayment, culture: culture)
                }
            } else {
                DispatchQueue.main.async {
                    self.delegate?.sdkProblemOccurred(problem: .paymentSessionEndStateReached)

                    BeaconService.shared.log(type: .sdkCallbackInvoked(name: "sdkProblemOccurred",
                                                                       succeeded: self.delegate != nil,
                                                                       values: ["problem": "paymentSessionEndStateReached"]))
                }
            }
        }

        func handleCallbackUrl(_ url: URL) -> Bool {
            guard url == orderInfo.paymentUrl else {
                return false
            }

            if let ongoingModel = ongoingModel {
                if let operation = ongoingModel.paymentSession.allMethodOperations
                    .first(where: { $0.rel == .getPayment }) {
                    sessionStartTimestamp = Date()
                    makeRequest(model: operation, culture: ongoingModel.paymentSession.culture)
                }
            }

            BeaconService.shared.log(type: .clientAppCallback(values: ["callbackUrl": url.absoluteString]))

            return true
        }
    }
}
