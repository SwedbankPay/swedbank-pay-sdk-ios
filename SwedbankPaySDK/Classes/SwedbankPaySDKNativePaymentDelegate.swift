//
//  SwedbankPaySDKNativePaymentDelegate.swift
//  SwedbankPaySDK
//
//  Created by Michael Balsiger on 2024-05-30.
//  Copyright © 2024 Swedbank. All rights reserved.
//

import UIKit

/// Swedbank Pay SDK protocol, conform to this to get the result of the payment process
public protocol SwedbankPaySDKNativePaymentDelegate: AnyObject {
    /// Called whenever the payment has been completed.
    func paymentComplete()

    /// Called whenever the payment has been canceled for any reason.
    func paymentCanceled()

    /// Called when an list of available instruments is known.
    ///
    /// - parameter availableInstruments: List of different instruments that is available to be used for the payment session.
    func availableInstrumentsFetched(_ availableInstruments: [SwedbankPaySDK.AvailableInstrument])

    /// Called if there is a session problem with performing the payment.
    ///
    /// - parameter problem: The problem that caused the failure
    func sessionProblemOccurred(problem: SwedbankPaySDK.ProblemDetails)

    /// Called if there is a SDK problem with performing the payment.
    ///
    /// - parameter problem: The problem that caused the failure
    func sdkProblemOccurred(problem: SwedbankPaySDK.NativePaymentProblem)

    func showViewController(viewController: UIViewController)

    func finishedWithViewController()
}
