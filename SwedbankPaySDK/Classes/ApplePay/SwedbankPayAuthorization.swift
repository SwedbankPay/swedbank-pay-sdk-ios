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

enum ApplePayError: Error {
    case userCancelled
}

class SwedbankPayAuthorization: NSObject {
    private let operation: OperationOutputModel
    private let merchantIdentifier: String
    private let task: IntegrationTask
    private let handler: ((Result<PaymentOutputModel, Error>) -> PKPaymentAuthorizationStatus)

    private var hasAuthorizedPayment = false

    init(operation: OperationOutputModel, task: IntegrationTask, merchantIdentifier: String, handler: @escaping (Result<PaymentOutputModel, Error>) -> PKPaymentAuthorizationStatus) {
        self.operation = operation
        self.merchantIdentifier = merchantIdentifier
        self.task = task
        self.handler = handler
    }
    
    func present() {
        let paymentRequest = PKPaymentRequest()

        if let totalAmountLabel = task.expects?.first(where: { $0.name == "TotalAmountLabel" })?.value,
           let totalAmount = task.expects?.first(where: { $0.name == "TotalAmount" })?.value {
            let total = PKPaymentSummaryItem(label: totalAmountLabel, amount: NSDecimalNumber(string: totalAmount), type: .final)
            paymentRequest.paymentSummaryItems = [total]
        }

        paymentRequest.merchantIdentifier = merchantIdentifier

        if (task.expects?.first(where: { $0.name == "MerchantCapabilities" })?.stringArray?.contains(where: { $0 == "supports3DS" })) != nil {
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
                let _ = self.handler(.failure(SwedbankPayAPIError.unknown))
            }
        })
    }
}

extension SwedbankPayAuthorization: PKPaymentAuthorizationControllerDelegate {
    func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
        if !hasAuthorizedPayment {
            // paymentAuthorizationController didAuthorizePayment haven't been called, user has cancelled and handler callback haven't been called
            let _ = handler(.failure(ApplePayError.userCancelled))
        }

        controller.dismiss()
    }

    func paymentAuthorizationController(_ controller: PKPaymentAuthorizationController, didAuthorizePayment payment: PKPayment, handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {
        self.hasAuthorizedPayment = true
        
        let paymentPayload = payment.token.paymentData.base64EncodedString()

        let router = EnpointRouter.attemptPayload(paymentPayload: paymentPayload)

        SwedbankPayAPIEnpointRouter(endpoint: Endpoint(router: router, href: operation.href, method: operation.method),
                                    sessionStartTimestamp: Date()).makeRequest { result in
            let status: PKPaymentAuthorizationStatus
            let errors: [Error]
            
            switch result {
            case .success(let paymentOutputModel):
                if let paymentOutputModel = paymentOutputModel {
                    status = self.handler(.success(paymentOutputModel))
                } else {
                    status = self.handler(.failure(SwedbankPayAPIError.unknown))
                }
                errors = [Error]()
            case .failure(let error):
                status = self.handler(.failure(error))
                errors = [error]
            }

            completion(PKPaymentAuthorizationResult(status: status, errors: errors))
        }
    }
}
