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
    /// Object that handles native payments
    class NativePayment: CallbackUrlDelegate {
        /// Order information that provides `NativePayment` with callback URLs.
        public var orderInfo: SwedbankPaySDK.ViewPaymentOrderInfo

        /// A delegate to receive callbacks as the native payment changes.
        public weak var delegate: SwedbankPaySDKNativePaymentDelegate?

        private var ongoingModel: PaymentOutputModel? = nil
        private var sessionIsOngoing: Bool = false
        private var instrument: SwedbankPaySDK.PaymentAttemptInstrument? = nil
        private var hasShownAvailableInstruments: Bool = false

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

        /// Starts a new native payment session.
        ///
        /// Calling this when a payment is already started will throw out the old payment.
        ///
        /// - parameter with sessionURL: Session URL needed to start the native payment session
        public func startPaymentSession(sessionURL: URL) {
            sessionIsOngoing = true
            instrument = nil
            ongoingModel = nil
            hasLaunchClientAppURLs = []
            hasShownProblemDetails = []
            hasShownAvailableInstruments = false

            let model = OperationOutputModel(rel: nil,
                                             href: sessionURL.absoluteString,
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

        /// Make a payment attempt with a specific instrument.
        ///
        /// There needs to be an active payment session before an payment attempt can be made.
        ///
        /// - parameter instrument: Payment attempt instrument
        public func makePaymentAttempt(instrument: SwedbankPaySDK.PaymentAttemptInstrument) {
            guard let ongoingModel = ongoingModel else {
                self.delegate?.sdkProblemOccurred(problem: .internalInconsistencyError)

                BeaconService.shared.log(type: .sdkCallbackInvoked(name: "sdkProblemOccurred",
                                                                   succeeded: self.delegate != nil,
                                                                   values: ["problem": SwedbankPaySDK.NativePaymentProblem.internalInconsistencyError.rawValue]))

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
                                                                 values: ["instrument": instrument.name,
                                                                          "msisdn": msisdn]))
            case .creditCard(let prefill):
                BeaconService.shared.log(type: .sdkMethodInvoked(name: "makePaymentAttempt",
                                                                 succeeded: succeeded,
                                                                 values: ["instrument": instrument.name,
                                                                          "paymentToken": prefill.paymentToken,
                                                                          "cardNumber": prefill.maskedPan,
                                                                          "cardExpiryMonth": prefill.expiryMonth,
                                                                          "cardExpiryYear": prefill.expiryYear]))
            }

        }

        /// Abort an active payment session.
        ///
        /// Does nothing if there isn't an active payment session.
        public func abortPaymentSession() {
            guard let ongoingModel = ongoingModel else {
                self.delegate?.sdkProblemOccurred(problem: .internalInconsistencyError)

                BeaconService.shared.log(type: .sdkCallbackInvoked(name: "sdkProblemOccurred",
                                                                   succeeded: self.delegate != nil,
                                                                   values: ["problem": SwedbankPaySDK.NativePaymentProblem.internalInconsistencyError.rawValue]))

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
                        let problem = SwedbankPaySDK.NativePaymentProblem.paymentSessionAPIRequestFailed(error: failure,
                                                                                                         retry: {
                            self.sessionStartTimestamp = Date()
                            self.makeRequest(model: model, culture: culture)
                        })

                        self.delegate?.sdkProblemOccurred(problem: problem)

                        let error = failure as NSError

                        BeaconService.shared.log(type: .sdkCallbackInvoked(name: "sdkProblemOccurred",
                                                                           succeeded: self.delegate != nil,
                                                                           values: ["problem": problem.rawValue,
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

                BeaconService.shared.log(type: .sdkCallbackInvoked(name: "sdkProblemOccurred",
                                                                   succeeded: self.delegate != nil,
                                                                   values: ["problem": SwedbankPaySDK.NativePaymentProblem.internalInconsistencyError.rawValue]))

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
                                                                               values: ["problem": SwedbankPaySDK.NativePaymentProblem.clientAppLaunchFailed.rawValue]))
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

            var hasShowedError = false
            
            if let modelProblem = model.problem,
               let problemOperation = modelProblem.operation,
               problemOperation.rel == .acknowledgeFailedAttempt {
                if !hasShownProblemDetails.contains(where: { $0.operation?.href == problemOperation.href }) {
                    hasShownProblemDetails.append(modelProblem)
                    hasShowedError = true

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
            } else if operations.contains(where: { $0.rel == .startPaymentAttempt }),
                      let instrument = instrument,
                      let startPaymentAttempt = ongoingModel?.paymentSession.methods?
                .first(where: { $0.name == instrument.name })?.operations?
                .first(where: { $0.rel == .startPaymentAttempt }) {

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
                    } else {
                        self.delegate?.sdkProblemOccurred(problem: .paymentSessionEndStateReached)
                        
                        BeaconService.shared.log(type: .sdkCallbackInvoked(name: "sdkProblemOccurred",
                                                                           succeeded: self.delegate != nil,
                                                                           values: ["problem": SwedbankPaySDK.NativePaymentProblem.paymentSessionEndStateReached.rawValue]))
                    }
                }
                sessionIsOngoing = false
                hasLaunchClientAppURLs = []
                hasShownProblemDetails = []
                hasShownAvailableInstruments = false
            } else if (operations.contains(where: { $0.rel == .expandMethod }) || operations.contains(where: { $0.rel == .startPaymentAttempt })) &&
                        hasShownAvailableInstruments == false {
                DispatchQueue.main.async {
                    let availableInstruments: [AvailableInstrument] = model.paymentSession.methods?.compactMap({ model in
                        switch model {
                        case .swish(let prefills, _):
                            return AvailableInstrument.swish(prefills: prefills)
                        case .creditCard(let prefills, _, _):
                            return AvailableInstrument.creditCard(prefills: prefills)
                        case .unknown(_):
                            return nil
                        }
                    }) ?? []

                    self.hasShownAvailableInstruments = true

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
            } else if !hasShowedError {
                DispatchQueue.main.async {
                    self.delegate?.sdkProblemOccurred(problem: .paymentSessionEndStateReached)

                    BeaconService.shared.log(type: .sdkCallbackInvoked(name: "sdkProblemOccurred",
                                                                       succeeded: self.delegate != nil,
                                                                       values: ["problem": SwedbankPaySDK.NativePaymentProblem.paymentSessionEndStateReached.rawValue]))
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
