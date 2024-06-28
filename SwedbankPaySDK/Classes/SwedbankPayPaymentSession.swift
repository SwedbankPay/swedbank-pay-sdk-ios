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

    func show3DSecureViewController(viewController: UIViewController)

    func dismiss3DSecureViewController()

    func paymentSession3DSecureViewControllerLoadFailed(error: Error, retry: @escaping ()->Void)
}

public extension SwedbankPaySDK {
    /// Object that handles payment sessions
    class SwedbankPayPaymentSession: CallbackUrlDelegate {
        /// Order information that provides `PaymentSession` with callback URLs.
        public var orderInfo: SwedbankPaySDK.ViewPaymentOrderInfo?

        /// A delegate to receive callbacks as the native payment changes.
        public weak var delegate: SwedbankPaySDKPaymentSessionDelegate?

        private var ongoingModel: PaymentOutputModel? = nil
        private var sessionIsOngoing: Bool = false
        private var instrument: SwedbankPaySDK.PaymentAttemptInstrument? = nil
        private var hasShownAvailableInstruments: Bool = false

        private var hasLaunchClientAppURLs: [URL] = []
        private var hasShownProblemDetails: [ProblemDetails] = []
        private var scaMethodRequestDataPerformed: [(name: String, value: String)] = []
        private var scaRedirectDataPerformed: [(name: String, value: String)] = []

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
            instrument = nil
            ongoingModel = nil
            hasLaunchClientAppURLs = []
            hasShownProblemDetails = []
            scaMethodRequestDataPerformed = []
            scaRedirectDataPerformed = []
            hasShownAvailableInstruments = false

            if automaticConfiguration {
                orderInfo = nil
            }

            let model = OperationOutputModel(rel: nil,
                                             href: sessionURL.absoluteString,
                                             method: "GET",
                                             next: nil,
                                             tasks: nil)

            sessionStartTimestamp = Date()
            makeRequest(operationOutputModel: model)

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

            self.instrument = instrument

            var succeeded = false
            if let operation = ongoingModel.paymentSession.methods?
                .first(where: { $0.name == instrument.identifier })?.operations?
                .first(where: { $0.rel == .expandMethod || $0.rel == .startPaymentAttempt || $0.rel == .getPayment }) {

                sessionStartTimestamp = Date()
                makeRequest(operationOutputModel: operation, culture: ongoingModel.paymentSession.culture)

                if operation.rel == .startPaymentAttempt {
                    self.instrument = nil
                }

                succeeded = true
            } else {
                DispatchQueue.main.async {
                    self.delegate?.sdkProblemOccurred(problem: .paymentSessionEndStateReached)

                    BeaconService.shared.log(type: .sdkCallbackInvoked(name: "sdkProblemOccurred",
                                                                       succeeded: self.delegate != nil,
                                                                       values: ["problem": SwedbankPaySDK.PaymentSessionProblem.paymentSessionEndStateReached.rawValue]))
                }

                return
            }

            switch instrument {
            case .swish(let msisdn):
                BeaconService.shared.log(type: .sdkMethodInvoked(name: "makePaymentAttempt",
                                                                 succeeded: succeeded,
                                                                 values: ["instrument": instrument.identifier,
                                                                          "msisdn": msisdn]))
            case .creditCard(let prefill):
                BeaconService.shared.log(type: .sdkMethodInvoked(name: "makePaymentAttempt",
                                                                 succeeded: succeeded,
                                                                 values: ["instrument": instrument.identifier,
                                                                          "paymentToken": prefill.paymentToken,
                                                                          "cardNumber": prefill.maskedPan,
                                                                          "cardExpiryMonth": prefill.expiryMonth,
                                                                          "cardExpiryYear": prefill.expiryYear]))
            }

        }

        public func createSwedbankPaySDKController(manualOrderInfo: SwedbankPaySDK.ViewPaymentOrderInfo? = nil) -> SwedbankPaySDKController? {
            guard let ongoingModel = ongoingModel,
                  let operation = ongoingModel.operations?.first(where: { $0.rel == .viewPayment }),
                  let orderInfo = orderInfo else {
                self.delegate?.sdkProblemOccurred(problem: .internalInconsistencyError)

                BeaconService.shared.log(type: .sdkCallbackInvoked(name: "sdkProblemOccurred",
                                                                   succeeded: self.delegate != nil,
                                                                   values: ["problem": SwedbankPaySDK.PaymentSessionProblem.internalInconsistencyError.rawValue]))

                return nil
            }

            let configuration: SwedbankPayConfiguration

            if let manualOrderInfo {
                configuration = SwedbankPayConfiguration(
                    isV3: manualOrderInfo.isV3,
                    webViewBaseURL: manualOrderInfo.webViewBaseURL,
                    viewPaymentLink: URL(string: operation.href!)!,
                    completeUrl: manualOrderInfo.completeUrl,
                    cancelUrl: manualOrderInfo.cancelUrl,
                    paymentUrl: manualOrderInfo.paymentUrl)
            } else {
                configuration = SwedbankPayConfiguration(
                    isV3: orderInfo.isV3,
                    webViewBaseURL: ongoingModel.paymentSession.urls?.hostUrls?.first,
                    viewPaymentLink: URL(string: operation.href!)!,
                    completeUrl: orderInfo.completeUrl,
                    cancelUrl: orderInfo.cancelUrl,
                    paymentUrl: orderInfo.paymentUrl)
            }

            let viewController = SwedbankPaySDKController(
                configuration: configuration,
                withCheckin: false,
                consumer: nil,
                paymentOrder: nil,
                userData: nil)

            return viewController
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
            if let operation = ongoingModel.operations?
                .first(where: { $0.rel == .abortPayment }) {
                sessionStartTimestamp = Date()
                makeRequest(operationOutputModel: operation, culture: ongoingModel.paymentSession.culture)
                succeeded = true
            }

            BeaconService.shared.log(type: .sdkMethodInvoked(name: "abortPaymentSession",
                                                             succeeded: succeeded,
                                                             values: nil))
        }

        private func makeRequest(operationOutputModel: OperationOutputModel, culture: String? = nil, methodCompletionIndicator: String? = nil, cRes: String? = nil) {
            SwedbankPayAPIEnpointRouter(model: operationOutputModel,
                                        culture: culture,
                                        instrument: instrument,
                                        methodCompletionIndicator: methodCompletionIndicator,
                                        cRes: cRes,
                                        sessionStartTimestamp: sessionStartTimestamp).makeRequest { result in
                switch result {
                case .success(let success):
                    if let paymentOutputModel = success {
                        if self.automaticConfiguration, operationOutputModel.rel == nil {
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

                        if let eventLogging = paymentOutputModel.operations?.first(where: { $0.rel == .eventLogging  }) {
                            BeaconService.shared.href = eventLogging.href
                        }

                        self.sessionOperationHandling(paymentOutputModel: paymentOutputModel, culture: paymentOutputModel.paymentSession.culture)
                    }
                case .failure(let failure):
                    DispatchQueue.main.async {
                        let problem = SwedbankPaySDK.PaymentSessionProblem.paymentSessionAPIRequestFailed(error: failure,
                                                                                                         retry: {
                            self.sessionStartTimestamp = Date()
                            self.makeRequest(operationOutputModel: operationOutputModel,
                                             culture: culture,
                                             methodCompletionIndicator:
                                                methodCompletionIndicator,
                                             cRes: cRes)
                        })

                        self.delegate?.sdkProblemOccurred(problem: problem)

                        let error = failure as NSError

                        BeaconService.shared.log(type: .sdkCallbackInvoked(name: "sdkProblemOccurred",
                                                                           succeeded: self.delegate != nil,
                                                                           values: ["problem": problem.rawValue,
                                                                                    "errorDescription": error.localizedDescription,
                                                                                    "errorCode": error.code,
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
                                                                                 "launchSucceeded": complete]))
                    }
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
                                                                           values: ["problemTitle": modelProblem.title,
                                                                                    "problemStatus": modelProblem.status,
                                                                                    "problemDetail": modelProblem.detail]))
                    }
                }

                makeRequest(operationOutputModel: problemOperation, culture: culture)
            }

            let operations = paymentOutputModel.prioritisedOperations

            print("\(operations.compactMap({ $0.rel }))")

            if let preparePayment = operations.first(where: { $0.rel == .preparePayment }) {
                makeRequest(operationOutputModel: preparePayment, culture: culture)
            } else if operations.contains(where: { $0.rel == .startPaymentAttempt }),
                      let instrument = instrument,
                      let startPaymentAttempt = ongoingModel?.paymentSession.methods?
                .first(where: { $0.name == instrument.identifier })?.operations?
                .first(where: { $0.rel == .startPaymentAttempt }) {

                makeRequest(operationOutputModel: startPaymentAttempt, culture: culture)
                self.instrument = nil
            } else if let launchClientApp = operations.first(where: { $0.firstTask(with: .launchClientApp) != nil }),
                      let tasks = launchClientApp.firstTask(with: .launchClientApp),
                      !hasLaunchClientAppURLs.contains(where: { $0.absoluteString.contains(tasks.href ?? "") }) {
                self.launchClientApp(task: launchClientApp.firstTask(with: .launchClientApp)!)
            } else if let scaMethodRequest = operations.first(where: { $0.firstTask(with: .scaMethodRequest) != nil }),
                      let task = scaMethodRequest.firstTask(with: .scaMethodRequest),
                      !scaMethodRequestDataPerformed.contains(where: { $0.name == task.expects?.first(where: { $0.name == "threeDSMethodData" })?.value }) {
                DispatchQueue.main.async {
                    self.webViewService.load(task: task) { result in
                        switch result {
                        case .success:
                            self.scaMethodRequestDataPerformed.append((name: task.expects?.first(where: { $0.name == "threeDSMethodData" })?.value ?? "", value: "Y"))
                        case .failure(let error):
                            self.scaMethodRequestDataPerformed.append((name: task.expects?.first(where: { $0.name == "threeDSMethodData" })?.value ?? "", value: "N"))
                        }

                        if let model = self.ongoingModel {
                            self.sessionOperationHandling(paymentOutputModel: model, culture: culture)
                        }
                    }
                }
            } else if let createAuthentication = operations.first(where: { $0.rel == .createAuthentication }),
                      let task = createAuthentication.firstTask(with: .scaMethodRequest),
                      let scaMethod = scaMethodRequestDataPerformed.first(where: { $0.name == task.expects?.first(where: { $0.name == "threeDSMethodData" })?.value }) {
                makeRequest(operationOutputModel: createAuthentication, culture: culture, methodCompletionIndicator: scaMethod.value)
            } else if let operation = operations.first(where: { $0.firstTask(with: .scaRedirect) != nil }),
                      let task = operation.firstTask(with: .scaRedirect),
                      !scaRedirectDataPerformed.contains(where: { $0.name == task.expects?.first(where: { $0.name == "creq" })?.value }) {
                DispatchQueue.main.async {
                    self.delegate?.show3DSecureViewController(viewController: self.webViewController)

                    BeaconService.shared.log(type: .sdkCallbackInvoked(name: "show3dSecure",
                                                                       succeeded: self.delegate != nil,
                                                                       values: nil))

                    self.scaRedirectDataPerformed(task: task, culture: culture)
                }
            } else if let completeAuthentication = operations.first(where: { $0.rel == .completeAuthentication }),
                      let task = completeAuthentication.tasks?.first(where: { $0.expects?.contains(where: { $0.name == "creq" } ) ?? false } ),
                      let scaRedirect = scaRedirectDataPerformed.first(where: { $0.name == task.expects?.first(where: { $0.name == "creq" })?.value }) {
                makeRequest(operationOutputModel: completeAuthentication, culture: culture, cRes: scaRedirect.value)
            } else if let redirectPayer = operations.first(where: { $0.rel == .redirectPayer }) {
                DispatchQueue.main.async {
                    if redirectPayer.href == self.orderInfo?.cancelUrl?.absoluteString {
                        self.delegate?.paymentSessionCanceled()

                        BeaconService.shared.log(type: .sdkCallbackInvoked(name: "paymentSessionCanceled",
                                                                           succeeded: self.delegate != nil,
                                                                           values: nil))
                    } else if redirectPayer.href == self.orderInfo?.completeUrl.absoluteString {
                        self.delegate?.paymentSessionComplete()

                        BeaconService.shared.log(type: .sdkCallbackInvoked(name: "paymentSessionComplete",
                                                                           succeeded: self.delegate != nil,
                                                                           values: nil))
                    } else {
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
                hasShownAvailableInstruments = false
            } else if (operations.contains(where: { $0.rel == .expandMethod }) || operations.contains(where: { $0.rel == .startPaymentAttempt })) &&
                        hasShownAvailableInstruments == false {
                DispatchQueue.main.async {
                    let availableInstruments: [AvailableInstrument] = paymentOutputModel.paymentSession.methods?.compactMap({ model in
                        switch model {
                        case .swish(let prefills, _):
                            return AvailableInstrument.swish(prefills: prefills)
                        case .creditCard(let prefills, _, _):
                            return AvailableInstrument.creditCard(prefills: prefills)
                        case .unknown(let identifier):
                            return AvailableInstrument.webBased(identifier: identifier)
                        }
                    }) ?? []

                    self.hasShownAvailableInstruments = true

                    self.delegate?.paymentSessionFetched(availableInstruments: availableInstruments)

                    BeaconService.shared.log(type: .sdkCallbackInvoked(name: "paymentSessionFetched",
                                                                       succeeded: self.delegate != nil,
                                                                       values: ["instruments": availableInstruments.compactMap({ $0.identifier }).joined(separator: ";")]))
                }
            } else if let getPayment = operations.first(where: { $0.rel == .getPayment }) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.sessionStartTimestamp = Date()
                    self.makeRequest(operationOutputModel: getPayment, culture: culture)
                }
            } else if !hasShowedError {
                DispatchQueue.main.async {
                    self.delegate?.sdkProblemOccurred(problem: .paymentSessionEndStateReached)

                    BeaconService.shared.log(type: .sdkCallbackInvoked(name: "sdkProblemOccurred",
                                                                       succeeded: self.delegate != nil,
                                                                       values: ["problem": SwedbankPaySDK.PaymentSessionProblem.paymentSessionEndStateReached.rawValue]))
                }
            }
        }

        func handleCallbackUrl(_ url: URL) -> Bool {
            guard url == orderInfo?.paymentUrl else {
                return false
            }

            if let ongoingModel = ongoingModel {
                if let operation = ongoingModel.paymentSession.allMethodOperations
                    .first(where: { $0.rel == .getPayment }) {
                    sessionStartTimestamp = Date()
                    makeRequest(operationOutputModel: operation, culture: ongoingModel.paymentSession.culture)
                }
            }

            BeaconService.shared.log(type: .clientAppCallback(values: ["callbackUrl": url.absoluteString]))

            return true
        }

        func scaRedirectDataPerformed(task: IntegrationTask, culture: String?) {
            self.webViewController.load(task: task) { result in
                switch result {
                case .success(let value):
                    if !self.scaRedirectDataPerformed.contains(where: { $0.value == value }) {
                        self.scaRedirectDataPerformed.append((name: task.expects!.first(where: { $0.name == "creq" })!.value!, value: value))

                        self.delegate?.dismiss3DSecureViewController()

                        BeaconService.shared.log(type: .sdkCallbackInvoked(name: "dismiss3dSecure",
                                                                           succeeded: self.delegate != nil,
                                                                           values: nil))

                        if let model = self.ongoingModel {
                            self.sessionOperationHandling(paymentOutputModel: model, culture: culture)
                        }
                    }
                case .failure(let error):
                    self.delegate?.paymentSession3DSecureViewControllerLoadFailed(error: error, retry: {
                        self.scaRedirectDataPerformed(task: task, culture: culture)
                    })

                    let error = error as NSError

                    BeaconService.shared.log(type: .sdkCallbackInvoked(name: "paymentSession3DSecureViewControllerLoadFailed",
                                                                       succeeded: self.delegate != nil,
                                                                       values: ["errorDescription": error.localizedDescription,
                                                                                "errorCode": error.code,
                                                                                "errorDomain": error.domain]))
                }
            }
        }
    }
}
