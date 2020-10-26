//
// Copyright 2019 Swedbank AB
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

final class SwedbankPaySDKViewModel {
    private class Update {
        var request: SwedbankPaySDKRequest?
    }
    
    let configuration: SwedbankPaySDKConfiguration
    let consumerData: SwedbankPaySDK.Consumer?
    let paymentOrder: SwedbankPaySDK.PaymentOrder?
    let userData: Any?
    
    var consumerProfileRef: String?
    
    var viewPaymentOrderInfo: SwedbankPaySDK.ViewPaymentOrderInfo?
    
    var updating: Bool {
        return currentUpdate != nil
    }
    
    private var currentUpdate: Update?
    
    init(
        configuration: SwedbankPaySDKConfiguration,
        consumerData: SwedbankPaySDK.Consumer?,
        paymentOrder: SwedbankPaySDK.PaymentOrder?,
        userData: Any?
    ) {
        self.configuration = configuration
        self.consumerData = consumerData
        self.paymentOrder = paymentOrder
        self.userData = userData
    }
    
    func cancelUpdate() {
        if let update = currentUpdate {
            update.request?.cancel()
            update.request = nil
            currentUpdate = nil
        }
    }
    
    func createPaymentOrder(
        completion: @escaping (Result<SwedbankPaySDK.ViewPaymentOrderInfo, Error>) -> Void
    ) {
        configuration.postPaymentorders(
            paymentOrder: paymentOrder,
            userData: userData,
            consumerProfileRef: consumerProfileRef
        ) { result in
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
    
    func identifyConsumer(
        completion: @escaping (Result<SwedbankPaySDK.ViewConsumerIdentificationInfo, Error>) -> Void
    ) {
        configuration.postConsumers(
            consumer: consumerData,
            userData: userData
        ) { result in
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
    
    func updatePaymentOrder(
        updateInfo: Any,
        completion: @escaping (Result<SwedbankPaySDK.ViewPaymentOrderInfo, Error>) -> Void
    ) {
        guard let viewPaymentOrderInfo = viewPaymentOrderInfo else {
            print("Error: setInstrument called when not showing a payment order")
            return
        }
        
        cancelUpdate()
        
        let update = Update()
        currentUpdate = update
        update.request = configuration
            .updatePaymentOrder(
                paymentOrder: paymentOrder,
                userData: userData,
                viewPaymentOrderInfo: viewPaymentOrderInfo,
                updateInfo: updateInfo
            ) { [weak self] result in
                DispatchQueue.main.async {
                    self?.handleUpdatePaymentOrderResult(update, result, completion)
                }
            }
    }
    
    private func handleUpdatePaymentOrderResult(
        _ update: Update,
        _ result: Result<SwedbankPaySDK.ViewPaymentOrderInfo, Error>,
        _ completion: @escaping (Result<SwedbankPaySDK.ViewPaymentOrderInfo, Error>) -> Void
    ) {
        guard update === currentUpdate else {
            return
        }
        
        currentUpdate = nil
        completion(result)
    }
}
