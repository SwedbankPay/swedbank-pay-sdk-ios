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

public extension SwedbankPaySDK {
    class NativePayment {
        /// The `SwedbankPaySDKConfiguration` used by this `NativePayment`.
        ///
        /// Note that `NativePayment` accesses this property only once during initialization,
        /// and will use the returned value thereafter. Hence, you cannot change the configuration "in-flight"
        /// by changing the value returned from here.
        open var configuration: SwedbankPaySDKConfiguration

        /// A delegate to receive callbacks as the state of SwedbankPaySDKController changes.
        public weak var delegate: SwedbankPaySDKDelegate?

        private var sessionIsOngoing: Bool = false

        public init(configuration: SwedbankPaySDKConfiguration) {
            self.configuration = configuration
        }

        public func startPaymentSession(with sessionApi: String) {
            sessionIsOngoing = true

            let model = OperationOutputModel(href: sessionApi,
                                             method: "GET")

            makeRequest(model: model)
        }

        private func makeRequest(model: OperationOutputModel) {
            SwedbankPayAPIEnpointRouter(model: model).makeRequest { result in
                switch result {
                case .success:
                    break
                case .failure(let failure):
                    self.delegate?.paymentFailed(error: failure)
                    self.sessionIsOngoing = false
                }
            }
        }
    }
}
