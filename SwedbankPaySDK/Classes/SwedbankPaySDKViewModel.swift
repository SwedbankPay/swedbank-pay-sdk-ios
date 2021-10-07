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
    
    private(set) var state = State.idle {
        didSet {
            onStateChanged?()
        }
    }
    var onStateChanged: (() -> Void)?
    
    var configuration: SwedbankPaySDKConfiguration!
    
    let consumer: SwedbankPaySDK.Consumer?
    let paymentOrder: SwedbankPaySDK.PaymentOrder?
    let userData: Any?
    
    var viewPaymentOrderInfo: SwedbankPaySDK.ViewPaymentOrderInfo? {
        switch state {
        case .idle:
            return nil
        case .initializingConsumerSession:
            return nil
        case .identifyingConsumer:
            return nil
        case .creatingPaymentOrder:
            return nil
        case .paying(let info, _):
            return info
        case .updatingPaymentOrder(let info, _):
            return info
        case .complete(let info):
            return info
        case .canceled(let info):
            return info
        case .failed(let info, _):
            return info
        }
    }
    
    var updating: Bool {
        switch state {
        case .updatingPaymentOrder:
            return true
        default:
            return false
        }
    }
        
    init(
        consumer: SwedbankPaySDK.Consumer?,
        paymentOrder: SwedbankPaySDK.PaymentOrder?,
        userData: Any?
    ) {
        self.consumer = consumer
        self.paymentOrder = paymentOrder
        self.userData = userData
    }
    
    func start(useCheckin: Bool, configuration: @autoclosure () -> SwedbankPaySDKConfiguration) {
        if case .idle = state {
            if self.configuration == nil {
                self.configuration = configuration()
            }
            
            if useCheckin {
                initializeConsumerSession()
            } else {
                createPaymentOrder(consumerProfileRef: nil)
            }
        }
    }
    
    func `continue`(consumerProfileRef: String) {
        if case .identifyingConsumer = state {
            createPaymentOrder(
                consumerProfileRef: consumerProfileRef
            )
        }
    }
    
    func updatePaymentOrder(updateInfo: Any) {
        switch state {
        case .paying(let viewPaymentOrderInfo, _):
            updatePaymentOrder(viewPaymentOrderInfo: viewPaymentOrderInfo, updateInfo: updateInfo)
        case .updatingPaymentOrder(let viewPaymentOrderInfo, _):
            cancelUpdate()
            updatePaymentOrder(viewPaymentOrderInfo: viewPaymentOrderInfo, updateInfo: updateInfo)
        default:
            print("Error: updatePaymentOrder called when not showing a payment order")
        }
    }
    
    func cancelUpdate() {
        if case .updatingPaymentOrder(let data, let update) = state {
            if case .active(let request?) = update.state {
                request.cancel()
            }
            update.state = .canceled
            state = .paying(data)
        }
    }
    
    func onComplete() {
        state = .complete(viewPaymentOrderInfo)
    }
    
    func onCanceled() {
        state = .canceled(viewPaymentOrderInfo)
    }
    
    func onFailed(error: Error) {
        cancelUpdate()
        state = .failed(viewPaymentOrderInfo, error)
    }
    
    class Update {
        enum State {
            case active(SwedbankPaySDKRequest?)
            case canceled
        }
        var state = State.active(nil)
    }
    
    enum State {
        case idle
        case initializingConsumerSession
        case identifyingConsumer(SwedbankPaySDK.ViewConsumerIdentificationInfo)
        case creatingPaymentOrder(String?)
        case paying(SwedbankPaySDK.ViewPaymentOrderInfo, failedUpdate: (updateInfo: Any, error: Error)? = nil)
        case updatingPaymentOrder(SwedbankPaySDK.ViewPaymentOrderInfo, Update)
        case complete(SwedbankPaySDK.ViewPaymentOrderInfo?)
        case canceled(SwedbankPaySDK.ViewPaymentOrderInfo?)
        case failed(SwedbankPaySDK.ViewPaymentOrderInfo?, Error)
    }
}

private extension SwedbankPaySDKViewModel {
    private func initializeConsumerSession(
        fromAwakeAfterDecode: Bool = false
    ) {
        switch state {
        case .idle: assert(!fromAwakeAfterDecode)
        case .initializingConsumerSession: assert(fromAwakeAfterDecode)
        default: assertionFailure("Unexpected state: \(self.state)")
        }
        
        state = .initializingConsumerSession
        configuration.postConsumers(
            consumer: consumer,
            userData: userData
        ) { result in
            DispatchQueue.main.async {
                self.handlePostConsumersResult(
                    result: result
                )
            }
        }
    }
    
    private func handlePostConsumersResult(
        result: Result<SwedbankPaySDK.ViewConsumerIdentificationInfo, Error>
    ) {
        if case .initializingConsumerSession = state {
            switch result {
            case .success(let info):
                state = .identifyingConsumer(info)
            case .failure(let error):
                state = .failed(viewPaymentOrderInfo, error)
            }
        }
    }
}

private extension SwedbankPaySDKViewModel {
    private func createPaymentOrder(
        consumerProfileRef: String?,
        fromAwakeAfterDecode: Bool = false
    ) {
        switch state {
        case .idle: assert(!fromAwakeAfterDecode)
        case .identifyingConsumer: assert(!fromAwakeAfterDecode)
        case .creatingPaymentOrder(consumerProfileRef): assert(fromAwakeAfterDecode)
        default: assertionFailure("Unexpected state: \(self.state)")
        }
        
        state = .creatingPaymentOrder(consumerProfileRef)
        configuration.postPaymentorders(
            paymentOrder: paymentOrder,
            userData: userData,
            consumerProfileRef: consumerProfileRef
        ) { result in
            DispatchQueue.main.async {
                self.handlePostPaymentOrdersResult(
                    result: result
                )
            }
        }
    }
    
    private func handlePostPaymentOrdersResult(
        result: Result<SwedbankPaySDK.ViewPaymentOrderInfo, Error>
    ) {
        if case .creatingPaymentOrder = state {
            switch result {
            case .success(let info):
                state = .paying(info)
            case .failure(let error):
                state = .failed(viewPaymentOrderInfo, error)
            }
        }
    }
}

private extension SwedbankPaySDKViewModel {
    private func updatePaymentOrder(
        viewPaymentOrderInfo: SwedbankPaySDK.ViewPaymentOrderInfo,
        updateInfo: Any
    ) {
        switch state {
        case .paying: break
        case .updatingPaymentOrder: break
        default: assertionFailure("Unexpected state: \(self.state) (expected .paying or .updatingPaymentOrder)")
        }
        
        let update = Update()
        state = .updatingPaymentOrder(viewPaymentOrderInfo, update)
        let request = configuration.updatePaymentOrder(
            paymentOrder: paymentOrder,
            userData: userData,
            viewPaymentOrderInfo: viewPaymentOrderInfo,
            updateInfo: updateInfo
        ) { result in
            DispatchQueue.main.async {
                self.handleUpdatePaymentOrderResult(update: update, updateInfo: updateInfo, result: result)
            }
        }
        // Check that the configuration callback did not immediately cancel the update.
        // It would be silly, but we don't want our logic to break regardless.
        switch update.state {
        case .active:
            update.state = .active(request)
        case .canceled:
            request?.cancel()
        }
    }
    
    private func handleUpdatePaymentOrderResult(
        update: Update,
        updateInfo: Any,
        result: Result<SwedbankPaySDK.ViewPaymentOrderInfo, Error>
    ) {
        if case .active = update.state {
            switch state {
            case .updatingPaymentOrder(let data, let currentUpdate) where currentUpdate === update:
                switch result {
                case .success(let info):
                    state = .paying(info)
                case .failure(let error):
                    state = .paying(data, failedUpdate: (updateInfo, error))
                }
            default:
                break
            }
        }
    }
}

// MARK: State Restoration

extension SwedbankPaySDKViewModel.State: Codable {
    private enum Key: String, CodingKey {
        case discriminator
        case info
        case consumerProfileRef
        case error
        case codableErrorType
    }
    
    private enum Discriminator: String, Codable {
        case idle
        case initializingConsumerSession
        case identifyingConsumer
        case creatingPaymentOrder
        case paying
        case complete
        case canceled
        case failed
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        let discriminator = try container.decode(Discriminator.self, forKey: .discriminator)
        switch discriminator {
        case .idle:
            self = .idle
        case .initializingConsumerSession:
            self = .initializingConsumerSession
        case .identifyingConsumer:
            let info = try container.decode(SwedbankPaySDK.ViewConsumerIdentificationInfo.self, forKey: .info)
            self = .identifyingConsumer(info)
        case .creatingPaymentOrder:
            let consumerProfileRef = try container.decodeIfPresent(String.self, forKey: .consumerProfileRef)
            self = .creatingPaymentOrder(consumerProfileRef)
        case .paying:
            let info = try container.decode(SwedbankPaySDK.ViewPaymentOrderInfo.self, forKey: .info)
            self = .paying(info)
        case .complete:
            let info = try container.decodeIfPresent(SwedbankPaySDK.ViewPaymentOrderInfo.self, forKey: .info)
            self = .complete(info)
        case .canceled:
            let info = try container.decodeIfPresent(SwedbankPaySDK.ViewPaymentOrderInfo.self, forKey: .info)
            self = .canceled(info)
        case .failed:
            let info = try container.decodeIfPresent(SwedbankPaySDK.ViewPaymentOrderInfo.self, forKey: .info)
            let error = try container.decodeErrorIfPresent(codableTypeKey: .codableErrorType, valueKey: .error)
            self = .failed(info, error ?? SwedbankPaySDKController.StateRestorationError.unknown)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        
        switch self {
        case .idle:
            try container.encode(Discriminator.idle, forKey: .discriminator)
        case .initializingConsumerSession:
            try container.encode(Discriminator.initializingConsumerSession, forKey: .discriminator)
        case .identifyingConsumer(let info):
            try container.encode(Discriminator.identifyingConsumer, forKey: .discriminator)
            try container.encode(info, forKey: .info)
        case .creatingPaymentOrder(let consumerProfileRef):
            try container.encode(Discriminator.creatingPaymentOrder, forKey: .discriminator)
            try container.encodeIfPresent(consumerProfileRef, forKey: .consumerProfileRef)
        case .paying(let info, _):
            try container.encode(Discriminator.paying, forKey: .discriminator)
            try container.encode(info, forKey: .info)
        case .updatingPaymentOrder(let info, _):
            try container.encode(Discriminator.paying, forKey: .discriminator)
            try container.encode(info, forKey: .info)
        case .complete(let info):
            try container.encode(Discriminator.complete, forKey: .discriminator)
            try container.encodeIfPresent(info, forKey: .info)
        case .canceled(let info):
            try container.encode(Discriminator.canceled, forKey: .discriminator)
            try container.encodeIfPresent(info, forKey: .info)
        case .failed(let info, let error):
            try container.encode(Discriminator.failed, forKey: .discriminator)
            try container.encodeIfPresent(info, forKey: .info)
            try container.encodeIfPresent(error: error, codableTypeKey: .codableErrorType, valueKey: .error)
        }
    }
}

extension SwedbankPaySDKViewModel: Codable {
    private enum CodingKeys: String, CodingKey {
        case state
        case consumer
        case paymentOrder
        case codableUserDataType
        case userData
    }
    
    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let consumer = try container.decodeIfPresent(SwedbankPaySDK.Consumer.self, forKey: .consumer)
        let paymentOrder = try container.decodeIfPresent(SwedbankPaySDK.PaymentOrder.self, forKey: .paymentOrder)
        do {
            let userData = try container.decodeUserDataIfPresent(codableTypeKey: .codableUserDataType, valueKey: .userData)
            let state = try container.decode(State.self, forKey: .state)
            self.init(consumer: consumer, paymentOrder: paymentOrder, userData: userData)
            self.state = state
        } catch {
            self.init(consumer: consumer, paymentOrder: paymentOrder, userData: nil)
            self.state = .failed(nil, error)
        }
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(consumer, forKey: .consumer)
        try container.encodeIfPresent(paymentOrder, forKey: .paymentOrder)
        do {
            try container.encodeIfPresent(userData: userData, codableTypeKey: .codableUserDataType, valueKey: .userData)
            try container.encode(state, forKey: .state)
        } catch SwedbankPaySDKController.StateRestorationError.unregisteredCodable(let encodedType) {
            try container.encode(State.failed(
                nil,
                SwedbankPaySDKController.StateRestorationError.unregisteredCodable(encodedType)
            ), forKey: .state)
        }
    }
    
    func awakeAfterDecode(configuration: @autoclosure () -> SwedbankPaySDKConfiguration) {
        if self.configuration == nil {
            self.configuration = configuration()
        }
        switch state {
        case .initializingConsumerSession:
            initializeConsumerSession(fromAwakeAfterDecode: true)
        case .creatingPaymentOrder(let consumerProfileRef):
            createPaymentOrder(consumerProfileRef: consumerProfileRef, fromAwakeAfterDecode: true)
        default:
            break
        }
    }
}
