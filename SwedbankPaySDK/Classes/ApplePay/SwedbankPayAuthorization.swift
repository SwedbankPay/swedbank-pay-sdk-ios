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
import PassKit

class SwedbankPayAuthorization: NSObject {
    static let shared = SwedbankPayAuthorization()

    private var operation: OperationOutputModel?
    private var task: IntegrationTask?
    private var handler: ((Result<PaymentOutputModel?, Error>) -> Void)?

    private var success: PaymentOutputModel?
    private var errors: [Error]?
    private var status: PKPaymentAuthorizationStatus?

    func showApplePay(operation: OperationOutputModel, task: IntegrationTask, merchantIdentifier: String?, handler: @escaping (Result<PaymentOutputModel?, Error>) -> Void) {
        self.errors = nil
        self.status = nil

        self.operation = operation
        self.task = task
        self.handler = handler

        let paymentRequest = PKPaymentRequest()

        if let totalAmountLabel = task.expects?.first(where: { $0.name == "TotalAmountLabel" })?.value,
           let totalAmount = task.expects?.first(where: { $0.name == "TotalAmount" })?.value {
            let total = PKPaymentSummaryItem(label: totalAmountLabel, amount: NSDecimalNumber(string: totalAmount), type: .final)
            paymentRequest.paymentSummaryItems = [total]
        }

        if let merchantIdentifier = merchantIdentifier {
            paymentRequest.merchantIdentifier = merchantIdentifier
        }

        if let merchantCapabilities = task.expects?.first(where: { $0.name == "MerchantCapabilities" })?.stringArray?.contains(where: { $0 == "supports3DS" }) {
            paymentRequest.merchantCapabilities = .threeDSecure
        }

        if let identifier = task.expects?.first(where: { $0.name == "Locale" })?.value,
           let countryCode = Locale(identifier: identifier).regionCode {
            paymentRequest.countryCode = countryCode
        }

        if let currencyCode = task.expects?.first(where: { $0.name == "CurrencyCode" })?.value {
            paymentRequest.currencyCode = currencyCode
        }

        if let supportedNetworks: [PKPaymentNetwork] = task.expects?.first(where: { $0.name == "SupportedNetworks" })?.stringArray?.compactMap({ string in
            return SwedbankPaymentNetwork(rawValue: string)?.pkPaymentNetwork
        }) {
            paymentRequest.supportedNetworks = supportedNetworks
        }

        if let supportedCountries = task.expects?.first(where: { $0.name == "SupportedCountries" })?.stringArray {
            paymentRequest.supportedCountries = Set(supportedCountries.map { $0 })
        }

        if let requiredShippingContactFields: [String] = task.expects?.first(where: { $0.name == "RequiredShippingContactFields" })?.stringArray {
            paymentRequest.requiredShippingContactFields = Set(requiredShippingContactFields.map { PKContactField(rawValue: $0) })
        }

        let paymentController = PKPaymentAuthorizationController(paymentRequest: paymentRequest)
        paymentController.delegate = self
        paymentController.present(completion: { (presented: Bool) in
            if !presented {
                handler(.failure(SwedbankPayAPIError.unknown))
            }
        })
    }
}

extension SwedbankPayAuthorization: PKPaymentAuthorizationControllerDelegate {
    func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
        if let handler = self.handler {
            if let status = status {
                handler(.success((success)))
            } else {
                handler(.failure(self.errors?.first ?? SwedbankPayAPIError.unknown))
            }
        }

        self.handler = nil

        controller.dismiss()
    }

    func paymentAuthorizationController(_ controller: PKPaymentAuthorizationController, didAuthorizePayment payment: PKPayment, handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {
        let paymentPayload = payment.token.paymentData.base64EncodedString()

        let router = EnpointRouter.applePay(paymentPayload: paymentPayload)

        SwedbankPayAPIEnpointRouter(endpoint: Endpoint(router: router, href: operation?.href, method: operation?.method),
                                    sessionStartTimestamp: Date()).makeRequest { result in
            switch result {
            case .success(let success):
                self.success = success
                self.status = PKPaymentAuthorizationStatus.success
                self.errors = [Error]()
            case .failure(let error):
                self.success = nil
                self.status = PKPaymentAuthorizationStatus.failure
                self.errors = [error]
            }

            completion(PKPaymentAuthorizationResult(status: self.status!, errors: self.errors))
        }
    }
}
