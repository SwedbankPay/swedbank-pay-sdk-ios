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

final class SwedbankPaySDKViewModel {
        
    var configuration: SwedbankPaySDKConfiguration?
    var consumerData: SwedbankPaySDK.Consumer?
    var paymentOrder: SwedbankPaySDK.PaymentOrder?
    var userData: Any?
    var consumerProfileRef: String?
    
    var viewPaymentOrderInfo: SwedbankPaySDK.ViewPaymentOrderInfo?
    
    func createPaymentOrder(
        completion: @escaping (Result<SwedbankPaySDK.ViewPaymentOrderInfo, Error>) -> Void
    ) {
        configuration?.postPaymentorders(
            paymentOrder: paymentOrder,
            userData: userData,
            consumerProfileRef: consumerProfileRef,
            completion: completion
        )
    }
    
    func identifyConsumer(
        completion: @escaping (Result<SwedbankPaySDK.ViewConsumerIdentificationInfo, Error>) -> Void
    ) {
        configuration?.postConsumers(
            consumer: consumerData,
            userData: userData,
            completion: completion
        )
    }
}
