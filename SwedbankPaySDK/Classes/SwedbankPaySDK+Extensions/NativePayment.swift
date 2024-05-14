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
    class NativePayment {
        /// Order information that provides `NativePayment` with callback URLs.
        public var orderInfo: SwedbankPaySDK.ViewPaymentOrderInfo

        /// A delegate to receive callbacks as the state of SwedbankPaySDKController changes.
        public weak var delegate: SwedbankPaySDKDelegate?

        private var ongoingModel: PaymentOutputModel? = nil
        private var sessionIsOngoing: Bool = false
        private var instrument: SwedbankPaySDK.PaymentAttemptInstrument? = nil

        public init(orderInfo: SwedbankPaySDK.ViewPaymentOrderInfo) {
            self.orderInfo = orderInfo
        }

        public func startPaymentSession(with sessionApi: String) {
            sessionIsOngoing = true
            instrument = nil

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

        private func makeRequest(model: OperationOutputModel, culture: String? = nil) {
            SwedbankPayAPIEnpointRouter(model: model, culture: culture, instrument: instrument).makeRequest { result in
                switch result {
                case .success:
                    break
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
                    UIApplication.shared.open(url)
                }
            }
        }
    }
}
