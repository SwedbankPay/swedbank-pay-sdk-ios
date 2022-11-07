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
            case .identifyingConsumer(let version, _):
                if case .v3(let info) = version {
                    return info
                }
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
            case .payerIdentification(let info, _, _, _):
                return info
        }
    }
    
    var versionOptions: SwedbankPaySDK.VersionOptions? {
        switch state {
            case .idle:
                return nil
            case .initializingConsumerSession(options: let options):
                return options
            case .identifyingConsumer(_, options: let options):
                return options
            case .creatingPaymentOrder(_, options: let options):
                return options
            case .paying(_, options: let options, _):
                return options
            case .updatingPaymentOrder(_, _, options: let options):
                return options
            case .complete(_):
                return nil
            case .canceled(_):
                return nil
            case .failed:
                return nil
            case .payerIdentification(_, let options, _, _):
                return options
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
    
    /// Payer identified event received
    func handlePayerIdentified() {
        if let options = versionOptions, options.contains(.isV3),
            let info = viewPaymentOrderInfo {
            //make a call to the SwedbankPaySDKConfiguration to allow it to update the payment order if needed.
            refreshPaymentOrderAfterIdentification(paymentInfo: info, options: options)
        }
    }
    
    func updatePaymentOrder(updateInfo: Any) {
        switch state {
            case .payerIdentification(let viewPaymentOrderInfo, options: let options, state: _, error: _):
                updatePaymentOrder(viewPaymentOrderInfo: viewPaymentOrderInfo, updateInfo: updateInfo, options: options)
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
    
    func abortPayment() {
        cancelUpdate()
        guard let paymentInfo = viewPaymentOrderInfo else {
            print("Error, missing paymentInfo - cannot cancel nothing")
            return
        }
        
        configuration.abortPayment(paymentInfo: paymentInfo, userData: userData, completion: { result in
            DispatchQueue.main.async { [self] in
                if case .failure(let err) = result {
                    state = .failed(paymentInfo, err)
                } else {
                    state = .canceled(paymentInfo)
                }
            }
        })
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
    
    /// Used for the sub-states of payerIdentification (see below).
    enum IdentificationState: Codable {
        //case userInputBegun - not needed since this case is handled by .identifyingConsumer, which puts us into waiting for input.
        case userInputConfirmed //user has given input, now waiting for backend to get the needed values
        case addressIsKnown  //in case you only have one shipping selection, go directly to update payment
    }
    
    enum State {
        case idle
        case initializingConsumerSession(options: SwedbankPaySDK.VersionOptions)
        case identifyingConsumer(SwedbankPaySDK.IdentifyingVersion, options: SwedbankPaySDK.VersionOptions)
        case creatingPaymentOrder(String?, options: SwedbankPaySDK.VersionOptions)
        case paying(SwedbankPaySDK.ViewPaymentOrderInfo, options: SwedbankPaySDK.VersionOptions, failedUpdate: (updateInfo: Any, error: Error)? = nil)
        case payerIdentification(SwedbankPaySDK.ViewPaymentOrderInfo, options: SwedbankPaySDK.VersionOptions, state: IdentificationState, error: Error? = nil)
        case updatingPaymentOrder(SwedbankPaySDK.ViewPaymentOrderInfo, Update, options: SwedbankPaySDK.VersionOptions)
        case complete(SwedbankPaySDK.ViewPaymentOrderInfo?)
        case canceled(SwedbankPaySDK.ViewPaymentOrderInfo?)
        case failed(SwedbankPaySDK.ViewPaymentOrderInfo?, Error)
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
        result: Result<SwedbankPaySDK.ViewPaymentOrderInfo, Error>
    ) {
        if case .creatingPaymentOrder(_, options: let options) = state {
            switch result {
                case .success(let info):
                    if options.contains([.useCheckin, .isV3]) {
                        state = .identifyingConsumer(.v3(info), options: options)
                    } else {
                        state = .paying(info, options: options)
                    }
                case .failure(let error):
                    state = .failed(viewPaymentOrderInfo, error)
            }
        } else if case .identifyingConsumer(_, options: let options) = state {
            switch result {
                case .success(let info):
                    state = .paying(info, options: options)
                case .failure(let error):
                    state = .failed(viewPaymentOrderInfo, error)
            }
        }
    }
}

private extension SwedbankPaySDKViewModel {
    
    private func refreshPaymentOrderAfterIdentification(
        paymentInfo: SwedbankPaySDK.ViewPaymentOrderInfo,
        options: SwedbankPaySDK.VersionOptions,
        fromAwakeAfterDecode: Bool = false
    ) {
        // we don't want the user to start paying before this is refreshed
        switch state {
            case .idle: assert(!fromAwakeAfterDecode)
            case .identifyingConsumer: assert(!fromAwakeAfterDecode)    //this is the normal flow - its an error to be called from awake
            case .payerIdentification: assert(fromAwakeAfterDecode)    //this can happen after awake, otherwise its an error
            case .paying: assert(!fromAwakeAfterDecode) //if called directly from merchant
            default: assertionFailure("Unexpected state: \(self.state) (expected .payerIdentification or .identifyingConsumer)")
        }
        state = .payerIdentification(paymentInfo, options: options, state: .userInputConfirmed)
        
        //trying to make this something more general since we probably don't need the actual address here but rather the shipping options and cost changes.
        _ = configuration.expandPayerAfterIdentified(
            paymentInfo: paymentInfo
        ) { result in
            
            DispatchQueue.main.async {
                self.handleExpandPayer(info: paymentInfo, options: options, result: result)
            }
        }
    }
    
    private func handleExpandPayer(
        info: SwedbankPaySDK.ViewPaymentOrderInfo,
        options: SwedbankPaySDK.VersionOptions,
        result: Result<Void, Error>
    ) {
        //print("currentState: \(state)")
        if case .failure(let err) = result {
            state = .payerIdentification(info, options: options, state: .addressIsKnown, error: err)
        } else {
            state = .payerIdentification(info, options: options, state: .addressIsKnown)
            // Now its up to the integrator to disable user interaction and update the payment accordingly, and if not - we continue to payment
            
            if case .payerIdentification(_, options: _, state: let newState, error: let error) = state,
               newState == .addressIsKnown,
               error == nil {
                // the delegate did not trigger changed state - continue to payment
                state = .paying(info, options: options)
            }
        }
    }
    
    private func updatePaymentOrder(
        viewPaymentOrderInfo: SwedbankPaySDK.ViewPaymentOrderInfo,
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
            options: options,
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
        case identificationState
        case error
        case codableErrorType
    }
    
    private enum Discriminator: String, Codable {
        case idle
        case initializingConsumerSession
        case identifyingConsumer
        case creatingPaymentOrder
        case paying
        case payerIdentification
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
                let info = try container.decode(SwedbankPaySDK.ViewPaymentOrderInfo.self, forKey: .info)
                let options = try container.decode(SwedbankPaySDK.VersionOptions.self, forKey: .options)
                self = .paying(info, options: options)
            case .payerIdentification:
                let info = try container.decode(SwedbankPaySDK.ViewPaymentOrderInfo.self, forKey: .info)
                let options = try container.decode(SwedbankPaySDK.VersionOptions.self, forKey: .options)
                let state = try container.decode(SwedbankPaySDKViewModel.IdentificationState.self, forKey: .identificationState)
                let error = try container.decodeErrorIfPresent(codableTypeKey: .codableErrorType, valueKey: .error)
                self = .payerIdentification(info, options: options, state: state, error: error)
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
            case .payerIdentification(let info, options: let options, state: let identificationState, error: let error):
                try container.encode(Discriminator.payerIdentification, forKey: .discriminator)
                try container.encode(info, forKey: .info)
                try container.encode(options, forKey: .options)
                try container.encode(identificationState, forKey: .identificationState)
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
            case .payerIdentification(let info, options: let options, state: _, error: _):
                refreshPaymentOrderAfterIdentification(paymentInfo: info, options: options, fromAwakeAfterDecode: true)
            default:
                break
        }
    }
}
