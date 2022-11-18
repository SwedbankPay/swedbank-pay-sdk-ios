import Foundation
import SwedbankPaySDK

class PaymentDelegate: SwedbankPaySDKDelegate {
    private let connection: TestMessageConnection
    
    init(port: UInt16) throws {
        let socket = try SocketHelper.makeClient(port: port)
        connection = try TestMessageConnection(socket: socket)
        
        if CommandLine.arguments.contains("-testerror") {
            connection.send(message: .error(errorMessage: "testerror"))
        }
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
        connection.send(message: .error(errorMessage: "\(error)"))
    }
    func paymentOrderDidShow(info: SwedbankPaySDK.ViewPaymentOrderInfo) {
        connection.send(message: .didShow)
    }
    func instrumentSelected() {
        connection.send(message: .instrumentSelected)
    }
    func javaScriptEvent(name: String, arguments: [String: Any]) {
        //connection.send(message: .anyEvent)
    }
}
