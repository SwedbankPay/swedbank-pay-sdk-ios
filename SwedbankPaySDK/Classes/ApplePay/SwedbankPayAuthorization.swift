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
    private let completionHandler: () -> ()
    private let stateHandler: ((Result<PaymentOutputModel, Error>) -> PKPaymentAuthorizationStatus)

    private var hasAuthorizedPayment = false

    init(operation: OperationOutputModel, task: IntegrationTask, merchantIdentifier: String, completionHandler: @escaping () -> (), stateHandler: @escaping (Result<PaymentOutputModel, Error>) -> PKPaymentAuthorizationStatus) {
        self.operation = operation
        self.merchantIdentifier = merchantIdentifier
        self.task = task
        self.completionHandler = completionHandler
        self.stateHandler = stateHandler
    }
    
    func present() {
        let paymentRequest = PKPaymentRequest()

        if let totalAmountLabel = task.expects?.first(where: { $0.name == "TotalAmountLabel" })?.value,
           let totalAmount = task.expects?.first(where: { $0.name == "TotalAmount" })?.value {
            let total = PKPaymentSummaryItem(label: totalAmountLabel, amount: NSDecimalNumber(string: totalAmount), type: .final)
            paymentRequest.paymentSummaryItems = [total]
        }

        paymentRequest.merchantIdentifier = merchantIdentifier

        if let swedbankCapabilities = task.expects?.first(where: { $0.name == "MerchantCapabilities" })?.stringArray?.compactMap({ capability in
            return SwedbankMerchantCapability(rawValue: capability)
        }) {
            paymentRequest.merchantCapabilities = swedbankCapabilities.pkMerchantCapabilities()
        }

        if let identifier = task.expects?.first(where: { $0.name == "Locale" })?.value,
           let countryCode = Locale(identifier: identifier).regionCode {
            paymentRequest.countryCode = countryCode
        }

        if let currencyCode = task.expects?.first(where: { $0.name == "CurrencyCode" })?.value {
            paymentRequest.currencyCode = currencyCode
        }

        if let supportedNetworks: [PKPaymentNetwork] = task.expects?.first(where: { $0.name == "SupportedNetworks" })?.stringArray?.compactMap({ network in
            return SwedbankPaymentNetwork(rawValueIgnoringCase: network)?.pkPaymentNetwork
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
                let _ = self.stateHandler(.failure(SwedbankPayAPIError.unknown))
                self.completionHandler()
            }
        })
    }
}

extension SwedbankPayAuthorization: PKPaymentAuthorizationControllerDelegate {
    func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
        if !hasAuthorizedPayment {
            // paymentAuthorizationController didAuthorizePayment haven't been called, user has cancelled and handler callback haven't been called
            let _ = stateHandler(.failure(ApplePayError.userCancelled))
        }

        controller.dismiss()
        completionHandler()
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
                    status = self.stateHandler(.success(paymentOutputModel))
                } else {
                    status = self.stateHandler(.failure(SwedbankPayAPIError.unknown))
                }
                errors = [Error]()
            case .failure(let error):
                status = self.stateHandler(.failure(error))
                errors = [error]
            }

            completion(PKPaymentAuthorizationResult(status: status, errors: errors))
        }
    }
}
