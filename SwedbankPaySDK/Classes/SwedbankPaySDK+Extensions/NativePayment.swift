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

        private var hasLaunchClientApp: [URL] = []

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
            hasLaunchClientApp = []

            let model = OperationOutputModel(rel: nil,
                                             href: sessionApi,
                                             method: "GET",
                                             next: nil,
                                             tasks: nil)

            makeRequest(model: model)
        }

        public func makePaymentAttempt(with instrument: SwedbankPaySDK.PaymentAttemptInstrument) {
            guard let ongoingModel = ongoingModel else {
                return
            }

            self.instrument = instrument

            if let operation = ongoingModel.paymentSession.methods?
                .first(where: { $0.name == instrument.name })?.operations?
                .first(where: { $0.rel == .expandMethod || $0.rel == .startPaymentAttempt || $0.rel == .getPayment }) {
                makeRequest(model: operation, culture: ongoingModel.paymentSession.culture)
            }
        }

        public func abortPaymentSession() {
            guard let ongoingModel = ongoingModel else {
                return
            }

            if let operation = ongoingModel.operations?
                .first(where: { $0.rel == .abortPayment }) {
                makeRequest(model: operation, culture: ongoingModel.paymentSession.culture)
            }
        }

        private func makeRequest(model: OperationOutputModel, culture: String? = nil) {
            SwedbankPayAPIEnpointRouter(model: model, culture: culture, instrument: instrument).makeRequest { result in
                switch result {
                case .success(let success):
                    if let model = success {
                        self.sessionOperationHandling(model: model, culture: model.paymentSession.culture)
                    }
                case .failure(let failure):
                    self.delegate?.paymentFailed(error: failure)
                    self.sessionIsOngoing = false
                }
            }
        }

        private func launchClientApp(task: IntegrationTask) {
            guard let href = task.href, var components = URLComponents(string: href) else {
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
                    self.hasLaunchClientApp.append(url)
                    UIApplication.shared.open(url)
                }
            }
        }

        private func sessionOperationHandling(model: PaymentOutputModel, culture: String? = nil) {
            ongoingModel = model

            let operations = model.prioritisedOperations

            if let acknowledgeFailedAttempt = operations.first(where: { $0.rel == .acknowledgeFailedAttempt }),
               let problem = model.problem {
                delegate?.paymentFailed(problem: problem)
                makeRequest(model: acknowledgeFailedAttempt, culture: culture)
            } else if let preparePayment = operations.first(where: { $0.rel == .preparePayment }) {
                makeRequest(model: preparePayment, culture: culture)
            } else if let startPaymentAttempt = operations.first(where: { $0.rel == .startPaymentAttempt }) {
                if instrument != nil {
                    makeRequest(model: startPaymentAttempt, culture: culture)
                    instrument = nil
                } else {
                    delegate?.availableInstrumentsFetched(model.paymentSession.methods ?? [])
                }
            } else if let launchClientApp = operations.first(where: { $0.firstTask(with: .launchClientApp) != nil }),
                      let tasks = launchClientApp.firstTask(with: .launchClientApp),
                      !hasLaunchClientApp.contains(where: { $0.absoluteString.contains(tasks.href ?? "") }) {
                self.launchClientApp(task: launchClientApp.firstTask(with: .launchClientApp)!)
            } else if let redirectPayer = operations.first(where: { $0.rel == .redirectPayer }) {
                if redirectPayer.href == orderInfo.cancelUrl?.absoluteString {
                    delegate?.paymentCanceled()
                } else if redirectPayer.href == orderInfo.completeUrl.absoluteString {
                    delegate?.paymentComplete()
                }
                sessionIsOngoing = false
            } else if let _ = operations.first(where: { $0.rel == .expandMethod }) {
                delegate?.availableInstrumentsFetched(model.paymentSession.methods ?? [])
            } else if let getPayment = operations.first(where: { $0.rel == .getPayment }) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.makeRequest(model: getPayment, culture: culture)
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
                    makeRequest(model: operation, culture: ongoingModel.paymentSession.culture)
                }
            }

            return true
        }
    }
}
