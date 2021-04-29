//
//  PaymentDelegate.swift
//  SwedbankPaySDKUITestHost
//
//  Created by Pertti Kroger on 27.4.2021.
//  Copyright © 2021 Swedbank. All rights reserved.
//

import Foundation
import SwedbankPaySDK

class PaymentDelegate: SwedbankPaySDKDelegate {
    private let connection: TestMessageConnection
    
    init(port: UInt16) throws {
        let socket = try SocketHelper.makeClient(port: port)
        connection = try TestMessageConnection(socket: socket)
    }
    deinit {
        connection.close()
    }
    
    func paymentComplete() {
        connection.send(message: .complete)
    }
    func paymentCanceled() {
        connection.send(message: .canceled)
    }
    func paymentFailed(error: Error) {
        connection.send(message: .error)
    }
}
