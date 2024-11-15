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
import UIKit
import WebKit

/// Swedbank Pay SDK protocol, conform to this to get the result of the payment process
public protocol SwedbankPaySDKPaymentSessionDelegate: AnyObject {
    /// Called whenever the payment has been completed.
    func paymentSessionComplete()

    /// Called whenever the payment has been canceled for any reason.
    func paymentSessionCanceled()

    /// Called when an list of available instruments is known.
    ///
    /// - parameter availableInstruments: List of different instruments that is available to be used for the payment session.
    func paymentSessionFetched(availableInstruments: [SwedbankPaySDK.AvailableInstrument])

    /// Called if there is a session problem with performing the payment.
    ///
    /// - parameter problem: The problem that caused the failure
    func sessionProblemOccurred(problem: SwedbankPaySDK.ProblemDetails)

    /// Called if there is a SDK problem with performing the payment.
    ///
    /// - parameter problem: The problem that caused the failure
    func sdkProblemOccurred(problem: SwedbankPaySDK.PaymentSessionProblem)

    /// Called when a 3D secure view needs to be presented.
    ///
    /// - parameter viewController: The UIViewController with 3D secure web view.
    func show3DSecureViewController(viewController: UIViewController)

    /// Called whenever the 3D secure view can be dismissed.
    func dismiss3DSecureViewController()

    func showSwedbankPaySDKController(viewController: SwedbankPaySDKController)
}

public extension SwedbankPaySDK {
    enum SwedbankPayPaymentSessionSDKControllerMode {
        case menu(restrictedToInstruments: [SwedbankPaySDK.AvailableInstrument]?)
        case instrumentMode(instrument: SwedbankPaySDK.AvailableInstrument)
    }
    
    /// Object that handles payment sessions
    class SwedbankPayPaymentSession: CallbackUrlDelegate {
        /// Order information that provides `PaymentSession` with callback URLs.
        public var orderInfo: SwedbankPaySDK.ViewPaymentOrderInfo?

        /// A delegate to receive callbacks as the native payment changes.
        public weak var delegate: SwedbankPaySDKPaymentSessionDelegate?

        private var ongoingModel: PaymentOutputModel? = nil
        private var sessionIsOngoing: Bool = false
        private var paymentViewSessionIsOngoing: Bool = false
        private var instrument: SwedbankPaySDK.PaymentAttemptInstrument? = nil
        private var sdkControllerMode: SwedbankPaySDK.SwedbankPayPaymentSessionSDKControllerMode? = nil
        private var hasShownAvailableInstruments: Bool = false
        private var merchantIdentifier: String? = nil

        private var hasLaunchClientAppURLs: [URL] = []
        private var hasShownProblemDetails: [ProblemDetails] = []
        private var scaMethodRequestDataPerformed: [(name: String, value: String)] = []
        private var scaRedirectDataPerformed: [(name: String, value: String)] = []
        private var notificationUrl: String? = nil

        private var sessionStartTimestamp = Date()

        private var webViewService = SCAWebViewService()
        private lazy var webViewController = SwedbankPaySCAWebViewController()

        private var automaticConfiguration: Bool = true

        public init(manualOrderInfo orderInfo: SwedbankPaySDK.ViewPaymentOrderInfo? = nil) {
            if let orderInfo {
                self.orderInfo = orderInfo
                self.automaticConfiguration = false
            }

            SwedbankPaySDK.addCallbackUrlDelegate(self)
        }

        deinit {
            SwedbankPaySDK.removeCallbackUrlDelegate(self)
        }

        /// Starts a new native payment session.
        ///
        /// Calling this when a payment is already started will throw out the old payment.
        ///
        /// - parameter with sessionURL: Session URL needed to start the native payment session
        public func fetchPaymentSession(sessionURL: URL) {
            sessionIsOngoing = true
            paymentViewSessionIsOngoing = false
            instrument = nil
            sdkControllerMode = nil
            merchantIdentifier = nil
            ongoingModel = nil
            hasLaunchClientAppURLs = []
            hasShownProblemDetails = []
            scaMethodRequestDataPerformed = []
            scaRedirectDataPerformed = []
            notificationUrl = nil
            hasShownAvailableInstruments = false

            if automaticConfiguration {
                orderInfo = nil
            }

            let model = OperationOutputModel(rel: nil,
                                             href: sessionURL.absoluteString,
                                             method: "GET",
                                             next: nil,
                                             tasks: nil,
                                             expects: nil)

            sessionStartTimestamp = Date()
            makeRequest(router: nil, operation: model)

            BeaconService.shared.clear()
            BeaconService.shared.log(type: .sdkMethodInvoked(name: "startPaymentSession",
                                                             succeeded: true,
                                                             values: nil))
        }

        /// Make a payment attempt with a specific instrument.
        ///
        /// There needs to be an active payment session before an payment attempt can be made.
        ///
        /// - parameter instrument: Payment attempt instrument
        public func makeNativePaymentAttempt(instrument: SwedbankPaySDK.PaymentAttemptInstrument) {
            guard let ongoingModel = ongoingModel else {
                self.delegate?.sdkProblemOccurred(problem: .internalInconsistencyError)

                BeaconService.shared.log(type: .sdkCallbackInvoked(name: "sdkProblemOccurred",
                                                                   succeeded: self.delegate != nil,
                                                                   values: ["problem": SwedbankPaySDK.PaymentSessionProblem.internalInconsistencyError.rawValue]))

                return
            }

            paymentViewSessionIsOngoing = false
            self.instrument = instrument

            switch instrument {
            case .applePay(let merchantIdentifier):
                self.merchantIdentifier = merchantIdentifier
            default:
                break
            }

            sessionOperationHandling(paymentOutputModel: ongoingModel, culture: ongoingModel.paymentSession.culture)

            switch instrument {
            case .swish(let msisdn):
                BeaconService.shared.log(type: .sdkMethodInvoked(name: "makePaymentAttempt",
                                                                 succeeded: true,
                                                                 values: ["instrument": instrument.paymentMethod,
                                                                          "msisdn": msisdn]))
            case .creditCard(let prefill):
                BeaconService.shared.log(type: .sdkMethodInvoked(name: "makePaymentAttempt",
                                                                 succeeded: true,
                                                                 values: ["instrument": instrument.paymentMethod,
                                                                          "paymentToken": prefill.paymentToken,
                                                                          "cardNumber": prefill.maskedPan,
                                                                          "cardExpiryMonth": prefill.expiryMonth,
                                                                          "cardExpiryYear": prefill.expiryYear]))
            case .applePay:
                BeaconService.shared.log(type: .sdkMethodInvoked(name: "makePaymentAttempt",
                                                                 succeeded: true,
                                                                 values: ["instrument": instrument.paymentMethod]))
            case .newCreditCard(enabledPaymentDetailsConsentCheckbox: let enabledPaymentDetailsConsentCheckbox):
                BeaconService.shared.log(type: .sdkMethodInvoked(name: "makePaymentAttempt",
                                                                 succeeded: true,
                                                                 values: ["instrument": instrument.paymentMethod,
                                                                          "showConsentAffirmation": enabledPaymentDetailsConsentCheckbox.description]))
            }

        }

        /// Creates a SwedbankPaySDKController.
        ///
        /// There needs to be an active payment session before an payment attempt can be made.
        ///
        /// - returns:- SwedbankPaySDKController to be shown.
        public func createSwedbankPaySDKController(mode: SwedbankPayPaymentSessionSDKControllerMode) {
            guard let ongoingModel = ongoingModel else {
                self.delegate?.sdkProblemOccurred(problem: .internalInconsistencyError)

                BeaconService.shared.log(type: .sdkCallbackInvoked(name: "sdkProblemOccurred",
                                                                   succeeded: self.delegate != nil,
                                                                   values: ["problem": SwedbankPaySDK.PaymentSessionProblem.internalInconsistencyError.rawValue]))

                return
            }

            let logValues: [String: String?]

            switch mode {
            case .instrumentMode(let instrument):
                logValues = [
                    "mode": "instrumentMode",
                    "instrument": instrument.paymentMethod
                ]
            case .menu(let restrictedToInstruments):
                logValues = [
                    "mode": "menu",
                    "restrictedToInstruments": restrictedToInstruments?.compactMap({ $0.paymentMethod }).joined(separator: ";")
                ]
            }

            BeaconService.shared.log(type: .sdkMethodInvoked(name: "createSwedbankPaySDKController",
                                                             succeeded: true,
                                                             values: logValues))

            paymentViewSessionIsOngoing = false
            sdkControllerMode = mode

            sessionOperationHandling(paymentOutputModel: ongoingModel, culture: ongoingModel.paymentSession.culture)
        }
        
        private func createSwedbankPaySDKController() {
            guard let ongoingModel = ongoingModel,
                  let operation = ongoingModel.operations?.firstOperation(withRel: .viewPayment),
                  let orderInfo = orderInfo,
                  let href = operation.href,
                  let viewPaymentLink = URL(string: href) else {
                self.delegate?.sdkProblemOccurred(problem: .internalInconsistencyError)

                BeaconService.shared.log(type: .sdkCallbackInvoked(name: "sdkProblemOccurred",
                                                                   succeeded: self.delegate != nil,
                                                                   values: ["problem": SwedbankPaySDK.PaymentSessionProblem.internalInconsistencyError.rawValue]))

                return
            }

            let configuration = SwedbankPayConfiguration(
                isV3: orderInfo.isV3,
                webViewBaseURL: automaticConfiguration ? ongoingModel.paymentSession.urls?.hostUrls?.first : orderInfo.webViewBaseURL,
                viewPaymentLink: viewPaymentLink,
                completeUrl: orderInfo.completeUrl,
                cancelUrl: orderInfo.cancelUrl,
                paymentUrl: orderInfo.paymentUrl)

            let viewController = SwedbankPaySDKController(
                configuration: configuration,
                withCheckin: false,
                consumer: nil,
                paymentOrder: nil,
                userData: nil)

            paymentViewSessionIsOngoing = true

            viewController.internalDelegate = self

            delegate?.showSwedbankPaySDKController(viewController: viewController)
        }

        /// Abort an active payment session.
        ///
        /// Does nothing if there isn't an active payment session.
        public func abortPaymentSession() {
            guard let ongoingModel = ongoingModel else {
                self.delegate?.sdkProblemOccurred(problem: .internalInconsistencyError)

                BeaconService.shared.log(type: .sdkCallbackInvoked(name: "sdkProblemOccurred",
                                                                   succeeded: self.delegate != nil,
                                                                   values: ["problem": SwedbankPaySDK.PaymentSessionProblem.internalInconsistencyError.rawValue]))

                return
            }

            var succeeded = false
            if let operation = ongoingModel.operations?.firstOperation(withRel: .abortPayment) {
                sessionStartTimestamp = Date()
                makeRequest(router: .abortPayment, operation: operation)
                succeeded = true
            }

            BeaconService.shared.log(type: .sdkMethodInvoked(name: "abortPaymentSession",
                                                             succeeded: succeeded,
                                                             values: nil))
        }

        private func makeRequest(router: EnpointRouter?, operation: OperationOutputModel) {
            SwedbankPayAPIEnpointRouter(endpoint: Endpoint(router: router, href: operation.href, method: operation.method),
                                        sessionStartTimestamp: sessionStartTimestamp).makeRequest { result in
                switch result {
                case .success(let success):
                    if let paymentOutputModel = success {
                        if self.automaticConfiguration, router == nil {
                            guard let urls = paymentOutputModel.paymentSession.urls, urls.completeUrl != nil, urls.hostUrls != nil else {
                                self.delegate?.sdkProblemOccurred(problem: .automaticConfigurationFailed)

                                BeaconService.shared.log(type: .sdkCallbackInvoked(name: "sdkProblemOccurred",
                                                                                   succeeded: self.delegate != nil,
                                                                                   values: ["problem": SwedbankPaySDK.PaymentSessionProblem.automaticConfigurationFailed.rawValue]))

                                return
                            }

                            self.orderInfo = SwedbankPaySDK.ViewPaymentOrderInfo(isV3: true,
                                                                                 webViewBaseURL: nil,
                                                                                 viewPaymentLink: URL(string: "https://")!,
                                                                                 completeUrl: urls.completeUrl!,
                                                                                 cancelUrl: urls.cancelUrl,
                                                                                 paymentUrl: urls.paymentUrl,
                                                                                 termsOfServiceUrl: urls.termsOfServiceUrl)
                        }

                        if let eventLogging = paymentOutputModel.operations?.firstOperation(withRel: .eventLogging) {
                            BeaconService.shared.href = eventLogging.href
                        }

                        self.sessionOperationHandling(paymentOutputModel: paymentOutputModel, culture: paymentOutputModel.paymentSession.culture)
                    }
                case .failure(let failure):
                    DispatchQueue.main.async {
                        let problem = SwedbankPaySDK.PaymentSessionProblem.paymentSessionAPIRequestFailed(error: failure,
                                                                                                         retry: {
                            self.sessionStartTimestamp = Date()
                            self.makeRequest(router: router, operation: operation)
                        })

                        self.delegate?.sdkProblemOccurred(problem: problem)

                        let error = failure as NSError

                        BeaconService.shared.log(type: .sdkCallbackInvoked(name: "sdkProblemOccurred",
                                                                           succeeded: self.delegate != nil,
                                                                           values: ["problem": problem.rawValue,
                                                                                    "errorDescription": error.localizedDescription,
                                                                                    "errorCode": String(error.code),
                                                                                    "errorDomain": error.domain]))
                    }
                }
            }
        }

        private func launchClientApp(task: IntegrationTask) {
            guard let href = task.href, var components = URLComponents(string: href) else {
                self.delegate?.sdkProblemOccurred(problem: .internalInconsistencyError)

                BeaconService.shared.log(type: .sdkCallbackInvoked(name: "sdkProblemOccurred",
                                                                   succeeded: self.delegate != nil,
                                                                   values: ["problem": SwedbankPaySDK.PaymentSessionProblem.internalInconsistencyError.rawValue]))

                return
            }

            // If the scheme is `swish` then we need to add a `callbackurl` if it's not already included in the link.
            if components.scheme == "swish",
               components.queryItems?.contains(where: { $0.name == "callbackurl" }) == false ||
               components.queryItems?.contains(where: { $0.name == "callbackurl" && ($0.value == nil || $0.value?.isEmpty == true) }) == true {
                if let paymentUrl = orderInfo?.paymentUrl?.absoluteString {
                    components.queryItems?.append(URLQueryItem(name: "callbackurl", value: paymentUrl.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)))
                }
            }

            if let url = components.url {
                DispatchQueue.main.async {
                    UIApplication.shared.open(url) { complete in
                        if complete {
                            self.hasLaunchClientAppURLs.append(url)
                            self.instrument = nil
                        } else {
                            self.delegate?.sdkProblemOccurred(problem: .clientAppLaunchFailed)

                            BeaconService.shared.log(type: .sdkCallbackInvoked(name: "sdkProblemOccurred",
                                                                               succeeded: self.delegate != nil,
                                                                               values: ["problem": SwedbankPaySDK.PaymentSessionProblem.clientAppLaunchFailed.rawValue]))
                        }

                        BeaconService.shared.log(type: .launchClientApp(values: ["callbackUrl": self.orderInfo?.paymentUrl?.absoluteString ?? "",
                                                                                 "clientAppLaunchUrl": url.absoluteString,
                                                                                 "launchSucceeded": complete.description]))
                    }
                }
            }
        }

        private func makeApplePayAuthorization(attemptPayloadOperation: OperationOutputModel, failPaymentAttemptOperation: OperationOutputModel, task: IntegrationTask) {
            guard let merchantIdentifier = merchantIdentifier else {
                self.delegate?.sdkProblemOccurred(problem: .internalInconsistencyError)

                BeaconService.shared.log(type: .sdkCallbackInvoked(name: "sdkProblemOccurred",
                                                                   succeeded: self.delegate != nil,
                                                                   values: ["problem": SwedbankPaySDK.PaymentSessionProblem.internalInconsistencyError.rawValue]))

                return
            }

            SwedbankPayAuthorization.shared.showApplePay(operation: attemptPayloadOperation, task: task, merchantIdentifier: merchantIdentifier) { result in
                switch result {
                case .success(let paymentOutputModel):
                    self.sessionOperationHandling(paymentOutputModel: paymentOutputModel, culture: paymentOutputModel.paymentSession.culture)
                case .failure(ApplePayError.userCancelled):
                    self.makeRequest(router: .failPaymentAttempt(problemType: "UserCancelled", errorCode: ""), operation: failPaymentAttemptOperation)
                case .failure(let error):
                    self.makeRequest(router: .failPaymentAttempt(problemType: "TechnicalError", errorCode: error.localizedDescription), operation: failPaymentAttemptOperation)
                }
            }
        }

        private func sessionOperationHandling(paymentOutputModel: PaymentOutputModel, culture: String? = nil) {
            ongoingModel = paymentOutputModel

            var hasShowedError = false
            
            if let modelProblem = paymentOutputModel.problem,
               let problemOperation = modelProblem.operation,
               problemOperation.rel == .acknowledgeFailedAttempt {
                if !hasShownProblemDetails.contains(where: { $0.operation?.href == problemOperation.href }) {
                    hasShownProblemDetails.append(modelProblem)
                    hasShowedError = true

                    DispatchQueue.main.async {
                        self.delegate?.sessionProblemOccurred(problem: modelProblem)

                        BeaconService.shared.log(type: .sdkCallbackInvoked(name: "sessionProblemOccurred",
                                                                           succeeded: self.delegate != nil,
                                                                           values: ["problemTitle": modelProblem.title ?? "",
                                                                                    "problemStatus": String(modelProblem.status ?? 0),
                                                                                    "problemDetail": modelProblem.detail ?? ""]))
                    }

                    makeRequest(router: .acknowledgeFailedAttempt, operation: problemOperation)
                }
            }

            let operations = paymentOutputModel.prioritisedOperations

            if let preparePayment = operations.firstOperation(withRel: .preparePayment) {
                // Initial state of payment session, run preparePayment operation
                
                makeRequest(router: .preparePayment, operation: preparePayment)
            } else if let attemptPayload = operations.firstOperation(withRel: .attemptPayload),
                      let failPayment = paymentOutputModel.paymentSession.methods?.firstMethod(withName: AvailableInstrument.applePay.paymentMethod)?.operations?.firstOperation(withRel: .failPaymentAttempt),
                      let walletSdk = attemptPayload.firstTask(withRel: .walletSdk) {
                // We have an active walletSdk task, this means we should initiate an Apple Pay Payment Request locally on the device
                
                makeApplePayAuthorization(attemptPayloadOperation: attemptPayload, failPaymentAttemptOperation: failPayment, task: walletSdk)
            } else if let instrument = self.instrument,
                      (paymentOutputModel.paymentSession.instrumentModePaymentMethod != nil && paymentOutputModel.paymentSession.instrumentModePaymentMethod != instrument.paymentMethod)
                        || !paymentOutputModel.paymentSession.allPaymentMethods.contains(where: {$0 == instrument.paymentMethod}),
                      let customizePayment = paymentOutputModel.operations?.firstOperation(withRel: .customizePayment) {
                // Resetting Instrument Mode session to Menu Mode (instrumentModePaymentMethod set to nil), if new payment attempt is made with an instrument other than the current Instrument Mode instrument or with an instrument not in the list of methods (restricted menu)
                
                makeRequest(router: .customizePayment(instrument: nil, paymentMethod: nil, restrictToPaymentMethods: nil), operation: customizePayment)
            } else if let instrument = self.instrument,
                      instrument.instrumentModeRequired,
                      paymentOutputModel.paymentSession.instrumentModePaymentMethod == nil
                        || paymentOutputModel.paymentSession.instrumentModePaymentMethod != instrument.paymentMethod,
                      let customizePayment = paymentOutputModel.operations?.firstOperation(withRel: .customizePayment) {
                // Switching to Instrument Mode from Menu Mode session (instrumentModePaymentMethod set to nil) or from Instrument Mode with other instrument, if new payment attempt is made with an Instrument Mode required instrument (newCreditCard)
                
                makeRequest(router: .customizePayment(instrument: instrument, paymentMethod: nil, restrictToPaymentMethods: nil), operation: customizePayment)
            } else if let instrument = self.instrument,
                      instrument.instrumentModeRequired,
                      paymentOutputModel.paymentSession.instrumentModePaymentMethod == instrument.paymentMethod {
                // Session is in Instrument Mode, and the set instrument is matching payment attempt, time to create a web based view and send to the merchant app
                
                self.instrument = nil
                
                DispatchQueue.main.async {
                    self.createSwedbankPaySDKController()
                }
            } else if let sdkControllerMode = self.sdkControllerMode,
                      case .instrumentMode(let instrument) = sdkControllerMode,
                      paymentOutputModel.paymentSession.instrumentModePaymentMethod == nil
                        || paymentOutputModel.paymentSession.instrumentModePaymentMethod != instrument.paymentMethod,
                      let customizePayment = paymentOutputModel.operations?.firstOperation(withRel: .customizePayment) {
                // Switching to Instrument Mode from Menu Mode session (instrumentModePaymentMethod set to nil) or from Instrument Mode with other instrument, if a SDK view controller is requiested in instrument mode
                
                makeRequest(router: .customizePayment(instrument: nil, paymentMethod: instrument.paymentMethod, restrictToPaymentMethods: nil), operation: customizePayment)
            } else if let sdkControllerMode = self.sdkControllerMode,
                      case .instrumentMode(let instrument) = sdkControllerMode,
                      paymentOutputModel.paymentSession.instrumentModePaymentMethod == instrument.paymentMethod {
                // Session is in Instrument Mode, and the set SDK view controller mode is matching the instrument, time to create a web based view and send to the merchant app
                
                self.sdkControllerMode = nil
                
                DispatchQueue.main.async {
                    self.createSwedbankPaySDKController()
                }
            } else if let sdkControllerMode = self.sdkControllerMode,
                      case .menu(let restrictedToInstruments) = sdkControllerMode,
                      paymentOutputModel.paymentSession.instrumentModePaymentMethod != nil
                        || paymentOutputModel.paymentSession.restrictedToInstruments?.sorted() != restrictedToInstruments?.compactMap({$0.paymentMethod}).sorted(),
                      let customizePayment = paymentOutputModel.operations?.firstOperation(withRel: .customizePayment) {
                // Switching to Menu Mode with potential list of restricted instruments from Instrument Mode or when  list of restricted instruments doesn't match (different list of instruments)
                
                makeRequest(router: .customizePayment(instrument: nil, paymentMethod: nil, restrictToPaymentMethods: restrictedToInstruments?.compactMap({$0.paymentMethod})), operation: customizePayment)
            } else if let sdkControllerMode = self.sdkControllerMode,
                      case .menu(let restrictedToInstruments) = sdkControllerMode,
                      paymentOutputModel.paymentSession.instrumentModePaymentMethod == nil
                        && paymentOutputModel.paymentSession.restrictedToInstruments?.sorted() == restrictedToInstruments?.compactMap({$0.paymentMethod}).sorted() {
                // Session is in Menu Mode, and the list of restricted instruments match the set SDK view controller mode, time to create a web based view and send to the merchant app
                
                self.sdkControllerMode = nil
                
                DispatchQueue.main.async {
                    self.createSwedbankPaySDKController()
                }
            } else if operations.containsOperation(withRel: .startPaymentAttempt),
                      let instrument = instrument,
                      let startPaymentAttempt = paymentOutputModel.paymentSession.methods?
                .firstMethod(withName: instrument.paymentMethod)?.operations?
                .firstOperation(withRel: .startPaymentAttempt) {
                // We have a startPaymentAttempt and it's matching the set instrument, time to make a payment attempt

                makeRequest(router: .startPaymentAttempt(instrument: instrument, culture: culture), operation: startPaymentAttempt)
                self.instrument = nil
            } else if let launchClientApp = operations.first(where: { $0.firstTask(withRel: .launchClientApp) != nil }),
                      let tasks = launchClientApp.firstTask(withRel: .launchClientApp),
                      !hasLaunchClientAppURLs.contains(where: { $0.absoluteString.contains(tasks.href ?? "") }) {
                // We have an active launchClientApp task, and the contained URL isn't in the list of already launched Client App URLs, launch the external app on the device
                
                self.launchClientApp(task: launchClientApp.firstTask(withRel: .launchClientApp)!)
            } else if let scaMethodRequest = operations.first(where: { $0.firstTask(withRel: .scaMethodRequest) != nil }),
                      let task = scaMethodRequest.firstTask(withRel: .scaMethodRequest),
                      let href = task.href,
                      !href.isEmpty,
                      !scaMethodRequestDataPerformed.contains(where: { $0.name == task.expects?.value(for: "threeDSMethodData") ?? "null" }) {
                // We have an active scaMethodRequest task, with a non-empty and non-nil href, and we haven't loaded the Method Request URL before (as identified by threeDSMethodData value as key), load the SCA Method Request in the "invisble web view"
                
                DispatchQueue.main.async {
                    self.webViewService.load(task: task) { result in
                        switch result {
                        case .success:
                            self.scaMethodRequestDataPerformed.append((name: task.expects?.value(for: "threeDSMethodData") ?? "null", value: "Y"))
                        case .failure:
                            self.scaMethodRequestDataPerformed.append((name: task.expects?.value(for: "threeDSMethodData") ?? "null", value: "N"))
                        }

                        self.sessionOperationHandling(paymentOutputModel: paymentOutputModel, culture: culture)
                    }
                }
            } else if let createAuthentication = operations.firstOperation(withRel: .createAuthentication),
                      let notificationUrl = createAuthentication.expects?.value(for: "NotificationUrl") {
                // We have a createAuthentication operation and should move forward with sending one of the Method Completion Indicators
                
                self.notificationUrl = notificationUrl

                if let task = createAuthentication.firstTask(withRel: .scaMethodRequest),
                   let scaMethod = scaMethodRequestDataPerformed.first(where: { $0.name == task.expects?.value(for: "threeDSMethodData") ?? "null" }) {
                    // We have loaded the Method Request URL in the "invisible web view" before (as identified by threeDSMethodData value as key), so we can use the result and run the createAuthentication operation
                    
                    makeRequest(router: .createAuthentication(methodCompletionIndicator: scaMethod.value, notificationUrl: notificationUrl), operation: createAuthentication)
                } else if let methodCompletionIndicator = createAuthentication.expects?.value(for: "methodCompletionIndicator") {
                    // The Session API has already provided us with a pre-defined Method Completion Indicator, so we take that and run the createAuthentication operation
                    
                    makeRequest(router: .createAuthentication(methodCompletionIndicator: methodCompletionIndicator, notificationUrl: notificationUrl), operation: createAuthentication)
                } else {
                    // We didn't have a result from a loaded Method Request URL, and we didn't get a pre-defined Method Completion Indicator, so we will have to send in the Unkonwn (U) indicator
                    
                    makeRequest(router: .createAuthentication(methodCompletionIndicator: "U", notificationUrl: notificationUrl), operation: createAuthentication)
                }
            } else if let operation = operations.first(where: { $0.firstTask(withRel: .scaRedirect) != nil }),
                      let task = operation.firstTask(withRel: .scaRedirect),
                      !scaRedirectDataPerformed.contains(where: { $0.name == task.expects?.value(for: "creq") }) {
                // We have an active scaRedirect task, and the 3D secure page hasn't been shown to the user yet (as identified by creq as key), tell the merchant app to show a 3D Secure View Controller
                
                DispatchQueue.main.async {
                    self.webViewController.notificationUrl = self.notificationUrl

                    self.delegate?.show3DSecureViewController(viewController: self.webViewController)

                    BeaconService.shared.log(type: .sdkCallbackInvoked(name: "show3DSecureViewController",
                                                                       succeeded: self.delegate != nil,
                                                                       values: nil))

                    self.scaRedirectDataPerformed(task: task, culture: culture)
                }
            } else if let completeAuthentication = operations.firstOperation(withRel: .completeAuthentication),
                      let task = completeAuthentication.tasks?.first(where: { $0.expects?.contains(where: { $0.name == "creq" } ) ?? false } ),
                      let scaRedirect = scaRedirectDataPerformed.first(where: { $0.name == task.expects?.value(for: "creq") }) {
                // We have an active scaRedirect task, and the 3D secure page has been shown to the user (as identified by creq as key), run the completeAuthentication operation with the result
                
                makeRequest(router: .completeAuthentication(cRes: scaRedirect.value), operation: completeAuthentication)
            } else if let redirectPayer = operations.firstOperation(withRel: .redirectPayer) {
                // We have a redirectPayer operation, this means the payment session has ended and we can look at the URL to determine the result
                
                DispatchQueue.main.async {
                    if redirectPayer.href == self.orderInfo?.cancelUrl?.absoluteString {
                        // URL matches the cancelUrl, the session has been cancelled
                        
                        self.delegate?.paymentSessionCanceled()

                        BeaconService.shared.log(type: .sdkCallbackInvoked(name: "paymentSessionCanceled",
                                                                           succeeded: self.delegate != nil,
                                                                           values: nil))
                    } else if redirectPayer.href == self.orderInfo?.completeUrl.absoluteString {
                        // URL matches the completeUrl, the session has been completed
                        
                        self.delegate?.paymentSessionComplete()

                        BeaconService.shared.log(type: .sdkCallbackInvoked(name: "paymentSessionComplete",
                                                                           succeeded: self.delegate != nil,
                                                                           values: nil))
                    } else {
                        // Redirect to an unknown URL, no way to recover from here
                        
                        self.delegate?.sdkProblemOccurred(problem: .paymentSessionEndStateReached)
                        
                        BeaconService.shared.log(type: .sdkCallbackInvoked(name: "sdkProblemOccurred",
                                                                           succeeded: self.delegate != nil,
                                                                           values: ["problem": SwedbankPaySDK.PaymentSessionProblem.paymentSessionEndStateReached.rawValue]))
                    }
                }
                sessionIsOngoing = false
                hasLaunchClientAppURLs = []
                hasShownProblemDetails = []
                scaMethodRequestDataPerformed = []
                scaRedirectDataPerformed = []
                notificationUrl = nil
                hasShownAvailableInstruments = false
            } else if let instrument = self.instrument,
                      let operation = paymentOutputModel.paymentSession.methods?
                .firstMethod(withName: instrument.paymentMethod)?.operations?
                .first(where: { $0.rel == .expandMethod || $0.rel == .startPaymentAttempt || $0.rel == .getPayment }) {
                // We have a method matching the set instrument, and it has one of the three supported method operations (expandMethod, startPaymentAttempt or getPayment)

                sessionStartTimestamp = Date()

                switch operation.rel {
                case .expandMethod:
                    // The current instrument has an expandMethod operation, run that to move to the next step of the process (startPaymentAttempt)
                    
                    makeRequest(router: .expandMethod(instrument: instrument), operation: operation)
                case .startPaymentAttempt:
                    // The current instrument has a startPaymentAttempt operation, run that to move to the next step of the process (getPayment, redirectPayer or problem)
                    
                    makeRequest(router: .startPaymentAttempt(instrument: instrument, culture: culture), operation: operation)
                    self.instrument = nil
                case .getPayment:
                    // The current instrument has a getPayment operation, run that so we're polling the session until we can move to the next step of the process (redirectPayer or problem)
                    
                    makeRequest(router: .getPayment, operation: operation)
                default:
                    // We already checked the operation in the if statement above, so this code should not be reachable
                    
                    fatalError("Operantion rel is not supported for makeNativePaymentAttempt: \(String(describing: operation.rel))")
                }
            } else if let getPayment = operations.firstOperation(withRel: .getPayment) {
                // We're told to simply fetch the session again, wait until polling and fetch the session, running the session operation handling once again
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.sessionStartTimestamp = Date()
                    self.makeRequest(router: .getPayment, operation: getPayment)
                }
            } else if hasShownAvailableInstruments == false {
                // No process has been initiated above, and we haven't sent the available instrumnts to the merchant app for this session yet, so send the list and wait for action
                
                DispatchQueue.main.async {
                    let availableInstruments: [AvailableInstrument] = paymentOutputModel.paymentSession.methods?.compactMap({ model in
                        switch model {
                        case .swish(let prefills, _):
                            return AvailableInstrument.swish(prefills: prefills)
                        case .creditCard(let prefills, _, _):
                            return AvailableInstrument.creditCard(prefills: prefills)
                        case .applePay:
                            return AvailableInstrument.applePay
                        case .webBased(let paymentMethod):
                            return AvailableInstrument.webBased(paymentMethod: paymentMethod)
                        }
                    }) ?? []
                    
                    self.hasShownAvailableInstruments = true
                    
                    self.delegate?.paymentSessionFetched(availableInstruments: availableInstruments)
                    
                    BeaconService.shared.log(type: .sdkCallbackInvoked(name: "paymentSessionFetched",
                                                                       succeeded: self.delegate != nil,
                                                                       values: ["instruments": availableInstruments.compactMap({ $0.paymentMethod }).joined(separator: ";")]))
                }
            } else if !hasShowedError {
                // No process has been initiated at all. The session is in a state that this session operation handling logic can't resolve.
                
                DispatchQueue.main.async {
                    self.delegate?.sdkProblemOccurred(problem: .paymentSessionEndStateReached)

                    BeaconService.shared.log(type: .sdkCallbackInvoked(name: "sdkProblemOccurred",
                                                                       succeeded: self.delegate != nil,
                                                                       values: ["problem": SwedbankPaySDK.PaymentSessionProblem.paymentSessionEndStateReached.rawValue]))
                }
            }
        }

        internal func handleCallbackUrl(_ url: URL) -> Bool {
            guard url.appendingPathComponent("") == orderInfo?.paymentUrl?.appendingPathComponent(""),
                  paymentViewSessionIsOngoing == false else {
                return false
            }

            if let ongoingModel = ongoingModel {
                if let operation = ongoingModel.paymentSession.allMethodOperations.firstOperation(withRel: .getPayment) {
                    sessionStartTimestamp = Date()
                    makeRequest(router: .getPayment, operation: operation)
                }
            }

            BeaconService.shared.log(type: .clientAppCallback(values: ["callbackUrl": url.absoluteString]))

            return true
        }

        private func scaRedirectDataPerformed(task: IntegrationTask, culture: String?) {
            self.webViewController.load(task: task) { result in
                switch result {
                case .success(let value):
                    if !self.scaRedirectDataPerformed.contains(where: { $0.value == value }) {
                        self.scaRedirectDataPerformed.append((name: task.expects!.value(for: "creq")!, value: value))

                        self.delegate?.dismiss3DSecureViewController()

                        BeaconService.shared.log(type: .sdkCallbackInvoked(name: "dismiss3DSecureViewController",
                                                                           succeeded: self.delegate != nil,
                                                                           values: nil))

                        if let model = self.ongoingModel {
                            self.sessionOperationHandling(paymentOutputModel: model, culture: culture)
                        }
                    }
                case .failure(let error):
                    let problem = SwedbankPaySDK.PaymentSessionProblem.paymentSession3DSecureViewControllerLoadFailed(error: error, retry: {
                        self.scaRedirectDataPerformed(task: task, culture: culture)
                    })

                    self.delegate?.sdkProblemOccurred(problem: problem)

                    let error = error as NSError

                    BeaconService.shared.log(type: .sdkCallbackInvoked(name: "sdkProblemOccurred",
                                                                       succeeded: self.delegate != nil,
                                                                       values: ["problem": problem.rawValue,
                                                                                "errorDescription": error.localizedDescription,
                                                                                "errorCode": String(error.code),
                                                                                "errorDomain": error.domain]))
                }
            }
        }
    }
}

extension SwedbankPaySDK.SwedbankPayPaymentSession: SwedbankPaySDKInternalDelegate {
    public func updatePaymentOrderFailed(updateInfo: Any, error: any Error) {
        let problem = SwedbankPaySDK.PaymentSessionProblem.paymentSessionAPIRequestFailed(error: error, retry: nil)

        self.delegate?.sdkProblemOccurred(problem: problem)

        let error = error as NSError

        BeaconService.shared.log(type: .sdkCallbackInvoked(name: "sdkProblemOccurred",
                                                           succeeded: self.delegate != nil,
                                                           values: ["problem": problem.rawValue,
                                                                    "errorDescription": error.localizedDescription,
                                                                    "errorCode": String(error.code),
                                                                    "errorDomain": error.domain]))
    }

    public func paymentComplete() {
        self.delegate?.paymentSessionComplete()

        BeaconService.shared.log(type: .sdkCallbackInvoked(name: "paymentSessionComplete",
                                                           succeeded: self.delegate != nil,
                                                           values: nil))
    }

    public func paymentCanceled() {
        self.delegate?.paymentSessionCanceled()

        BeaconService.shared.log(type: .sdkCallbackInvoked(name: "paymentSessionCanceled",
                                                           succeeded: self.delegate != nil,
                                                           values: nil))
    }

    public func paymentFailed(error: any Error) {
        let problem = SwedbankPaySDK.PaymentSessionProblem.paymentControllerPaymentFailed(error: error, retry: nil)

        self.delegate?.sdkProblemOccurred(problem: problem)

        let error = error as NSError

        BeaconService.shared.log(type: .sdkCallbackInvoked(name: "sdkProblemOccurred",
                                                           succeeded: self.delegate != nil,
                                                           values: ["problem": problem.rawValue,
                                                                    "errorDescription": error.localizedDescription,
                                                                    "errorCode": String(error.code),
                                                                    "errorDomain": error.domain]))
    }
}
