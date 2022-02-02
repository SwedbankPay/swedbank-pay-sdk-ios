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
    
    var viewPaymentOrderInfo: SwedbankPaySDK.ViewPaymentLinkInfo? {
        switch state {
            case .idle:
                return nil
            case .initializingConsumerSession:
                return nil
            case .identifyingConsumer:
                return nil
            case .creatingPaymentOrder:
                return nil
            case .paying(let info, options: _, _):
                return info
            case .updatingPaymentOrder(let info, _, _):
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
    
    func start(useCheckin: Bool, isV3: Bool = false, configuration: @autoclosure () -> SwedbankPaySDKConfiguration) {
        if case .idle = state {
            if self.configuration == nil {
                self.configuration = configuration()
            }
            var options: SwedbankPaySDK.VersionOptions = useCheckin ? .useCheckin : []
            if isV3 {
                options.formUnion(.isV3)
            }
            if useCheckin && !isV3 {
                //isV3 handles identification of consumers automatically - so no need for special handle of this
                initializeConsumerSession(options: options)
            } else {
                //let options: SwedbankPaySDK.VersionOptions = useCheckin ? [.isV3, .useCheckin] : .isV3
                createPaymentOrder(consumerProfileRef: nil, options: options)
            }
        }
    }
    
    func `continue`(consumerProfileRef: String) {
        if case .identifyingConsumer(_, let options) = state {
            createPaymentOrder(
                consumerProfileRef: consumerProfileRef,
                options: options
            )
        }
    }
    
    func updatePaymentOrder(updateInfo: Any) {
        switch state {
            case .paying(let viewPaymentOrderInfo, let options, _):
                updatePaymentOrder(viewPaymentOrderInfo: viewPaymentOrderInfo, updateInfo: updateInfo, options: options)
            case .updatingPaymentOrder(let viewPaymentOrderInfo, _, options: let options):
                cancelUpdate()
                updatePaymentOrder(viewPaymentOrderInfo: viewPaymentOrderInfo, updateInfo: updateInfo, options: options)
            default:
                print("Error: updatePaymentOrder called when not showing a payment order")
        }
    }
    
    func cancelUpdate() {
        if case .updatingPaymentOrder(let data, let update, let options) = state {
            if case .active(let request?) = update.state {
                request.cancel()
            }
            update.state = .canceled
            state = .paying(data, options: options)
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
        case initializingConsumerSession(options: SwedbankPaySDK.VersionOptions)
        case identifyingConsumer(SwedbankPaySDK.IdentifyingVersion, options: SwedbankPaySDK.VersionOptions)
        case creatingPaymentOrder(String?, options: SwedbankPaySDK.VersionOptions)
        case paying(SwedbankPaySDK.ViewPaymentLinkInfo, options: SwedbankPaySDK.VersionOptions, failedUpdate: (updateInfo: Any, error: Error)? = nil)
        case updatingPaymentOrder(SwedbankPaySDK.ViewPaymentLinkInfo, Update, options: SwedbankPaySDK.VersionOptions)
        case complete(SwedbankPaySDK.ViewPaymentLinkInfo?)
        case canceled(SwedbankPaySDK.ViewPaymentLinkInfo?)
        case failed(SwedbankPaySDK.ViewPaymentLinkInfo?, Error)
        /*
         TODO:
         State.consumerIdentified should be added
         Should move to this state if using v3 after the onPayerIdentified javascript event is received
         You may refactor continue(consumerProfileRef:) to be used for this purpose, or you may add a new callback (arguably cleaner). Your choice.
         That callback should, in turn, make a call to the SwedbankPaySDKConfiguration to allow it to update the payment order if needed. See below.
         When the SwedbankPaySDKConfiguration returns the possibly-updated payment order, should move to the .paying state
         updateUI() should show a loading indicator in this state
         */
    }
}

//consumerSession and consumerResult are only used in V2 and will be removed in the future.
private extension SwedbankPaySDKViewModel {
    private func initializeConsumerSession(
        options: SwedbankPaySDK.VersionOptions,
        fromAwakeAfterDecode: Bool = false
    ) {
        switch state {
            case .idle: assert(!fromAwakeAfterDecode)
            case .initializingConsumerSession: assert(fromAwakeAfterDecode)
            default: assertionFailure("Unexpected state: \(self.state)")
        }
        
        state = .initializingConsumerSession(options: options)
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
        if case .initializingConsumerSession(let options) = state {
            switch result {
                case .success(let info):
                    state = .identifyingConsumer(.v2(info), options: options)
                case .failure(let error):
                    state = .failed(viewPaymentOrderInfo, error)
            }
        }
    }
}

private extension SwedbankPaySDKViewModel {
    private func createPaymentOrder(
        consumerProfileRef: String?,
        options: SwedbankPaySDK.VersionOptions,
        fromAwakeAfterDecode: Bool = false
    ) {
        switch state {
            case .idle: assert(!fromAwakeAfterDecode)
            case .identifyingConsumer: assert(!fromAwakeAfterDecode)
            case .creatingPaymentOrder(consumerProfileRef, _): assert(fromAwakeAfterDecode)
            default: assertionFailure("Unexpected state: \(self.state)")
        }
        
        state = .creatingPaymentOrder(consumerProfileRef, options: options)
        
        configuration.postPaymentorders(
            paymentOrder: paymentOrder,
            userData: userData,
            consumerProfileRef: consumerProfileRef,
            options: options
        ) { result in
            DispatchQueue.main.async {
                self.handlePostPaymentOrdersResult(
                    result: result
                )
            }
        }
    }
    
    private func handlePostPaymentOrdersResult(
        result: Result<SwedbankPaySDK.ViewPaymentLinkInfo, Error>
    ) {
        if case .creatingPaymentOrder(_, options: let options) = state {
            switch result {
                case .success(let info):
                    if options.contains([.useCheckin, .isV3]) {
                        //TODO: new test
                        state = .identifyingConsumer(.v3(info), options: options)
                    } else {
                        state = .paying(info, options: options)
                    }
                case .failure(let error):
                    state = .failed(viewPaymentOrderInfo, error)
            }
        }
    }
}

private extension SwedbankPaySDKViewModel {
    private func updatePaymentOrder(
        viewPaymentOrderInfo: SwedbankPaySDK.ViewPaymentLinkInfo,
        updateInfo: Any,
        options: SwedbankPaySDK.VersionOptions
    ) {
        
        switch state {
            case .paying: break
            case .updatingPaymentOrder: break
            default: assertionFailure("Unexpected state: \(self.state) (expected .paying or .updatingPaymentOrder)")
        }
        
        let update = Update()
        state = .updatingPaymentOrder(viewPaymentOrderInfo, update, options: options)
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
        result: Result<SwedbankPaySDK.ViewPaymentLinkInfo, Error>
    ) {
        if case .active = update.state {
            switch state {
            case .updatingPaymentOrder(let data, let currentUpdate, let options) where currentUpdate === update:
                switch result {
                case .success(let info):
                    state = .paying(info, options: options)
                case .failure(let error):
                    state = .paying(data, options: options, failedUpdate: (updateInfo, error))
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
        case options
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
                let options = try container.decode(SwedbankPaySDK.VersionOptions.self, forKey: .options)
                self = .initializingConsumerSession(options: options)
            case .identifyingConsumer:
                let info = try container.decode(SwedbankPaySDK.IdentifyingVersion.self, forKey: .info)
                let options = try container.decode(SwedbankPaySDK.VersionOptions.self, forKey: .options)
                self = .identifyingConsumer(info, options: options)
            case .creatingPaymentOrder:
                let consumerProfileRef = try container.decodeIfPresent(String.self, forKey: .consumerProfileRef)
                let options = try container.decode(SwedbankPaySDK.VersionOptions.self, forKey: .options)
                self = .creatingPaymentOrder(consumerProfileRef, options: options)
            case .paying:
                let info = try container.decode(SwedbankPaySDK.ViewPaymentLinkInfo.self, forKey: .info)
                let options = try container.decode(SwedbankPaySDK.VersionOptions.self, forKey: .options)
                self = .paying(info, options: options)
            case .complete:
                let info = try container.decodeIfPresent(SwedbankPaySDK.ViewPaymentLinkInfo.self, forKey: .info)
                self = .complete(info)
            case .canceled:
                let info = try container.decodeIfPresent(SwedbankPaySDK.ViewPaymentLinkInfo.self, forKey: .info)
                self = .canceled(info)
            case .failed:
                let info = try container.decodeIfPresent(SwedbankPaySDK.ViewPaymentLinkInfo.self, forKey: .info)
                let error = try container.decodeErrorIfPresent(codableTypeKey: .codableErrorType, valueKey: .error)
                self = .failed(info, error ?? SwedbankPaySDKController.StateRestorationError.unknown)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        
        switch self {
            case .idle:
                try container.encode(Discriminator.idle, forKey: .discriminator)
            case .initializingConsumerSession(options: let options):
                try container.encode(Discriminator.initializingConsumerSession, forKey: .discriminator)
                try container.encode(options, forKey: .options)
            case .identifyingConsumer(let info, let options):
                try container.encode(Discriminator.identifyingConsumer, forKey: .discriminator)
                try container.encode(info, forKey: .info)
                try container.encode(options, forKey: .options)
            case .creatingPaymentOrder(let consumerProfileRef, options: let options):
                try container.encode(Discriminator.creatingPaymentOrder, forKey: .discriminator)
                try container.encodeIfPresent(consumerProfileRef, forKey: .consumerProfileRef)
                try container.encode(options, forKey: .options)
            case .paying(let info, options: let options, _):
                try container.encode(Discriminator.paying, forKey: .discriminator)
                try container.encode(info, forKey: .info)
                try container.encode(options, forKey: .options)
            case .updatingPaymentOrder(let info, _, let options):
                try container.encode(Discriminator.paying, forKey: .discriminator)
                try container.encode(info, forKey: .info)
                try container.encode(options, forKey: .options)
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
            case .initializingConsumerSession(options: let options):
                initializeConsumerSession(options: options, fromAwakeAfterDecode: true)
            case .creatingPaymentOrder(let consumerProfileRef, options: let options):
                createPaymentOrder(consumerProfileRef: consumerProfileRef, options: options, fromAwakeAfterDecode: true)
            default:
                break
        }
    }
}
