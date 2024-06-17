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

import UIKit

/// Swedbank Pay SDK protocol, conform to this to get the result of the payment process
public protocol SwedbankPaySDKPaymentSessionDelegate: AnyObject {
    /// Called whenever the payment has been completed.
    func paymentComplete()

    /// Called whenever the payment has been canceled for any reason.
    func paymentCanceled()

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

    func showViewController(viewController: UIViewController)

    func finishedWithViewController()

    func sdkProblemWithViewController(problem: SwedbankPaySDK.PaymentSessionProblem)
}
