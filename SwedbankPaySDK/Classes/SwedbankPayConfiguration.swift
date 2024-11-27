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

enum SwedbankPayConfigurationError: Error {
    case notImplemented
}

internal class SwedbankPayConfiguration {
    let orderInfo: SwedbankPaySDK.ViewPaymentOrderInfo

    init(isV3: Bool = true, webViewBaseURL: URL?,
         viewPaymentLink: URL, completeUrl: URL, cancelUrl: URL?,
         paymentUrl: URL? = nil, termsOfServiceUrl: URL? = nil) {
        self.orderInfo = SwedbankPaySDK.ViewPaymentOrderInfo(
            isV3: isV3,
            webViewBaseURL: webViewBaseURL,
            viewPaymentLink: viewPaymentLink,
            completeUrl: completeUrl,
            cancelUrl: cancelUrl,
            paymentUrl: paymentUrl,
            termsOfServiceUrl: termsOfServiceUrl
        )
    }
}

extension SwedbankPayConfiguration: SwedbankPaySDKConfiguration {

    // This delegate method is not used but required
    func postConsumers(consumer: SwedbankPaySDK.Consumer?, userData: Any?, completion: @escaping (Result<SwedbankPaySDK.ViewConsumerIdentificationInfo, Error>) -> Void) {
        completion(.failure(SwedbankPayConfigurationError.notImplemented))
    }

    func postPaymentorders(paymentOrder: SwedbankPaySDK.PaymentOrder?, userData: Any?, consumerProfileRef: String?, options: SwedbankPaySDK.VersionOptions, completion: @escaping (Result<SwedbankPaySDK.ViewPaymentOrderInfo, Error>) -> Void) {
        completion(.success(orderInfo))
    }
}
