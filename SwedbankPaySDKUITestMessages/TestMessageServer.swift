import Foundation

class TestMessageServer {
    private let socket: Int32
    let port: UInt16
    
    init() throws {
        (socket, port) = try SocketHelper.makeServer()
    }
    
    func start(onMessage: @escaping (TestMessage) -> Void) {
        acceptConnection(onMessage: onMessage)
    }
    func stop() {
        close(socket)
    }
    
    private func acceptConnection(onMessage: @escaping (TestMessage) -> Void) {
        DispatchQueue.global().async {
            do {
                let conn = try SocketHelper.throwIfFailure(accept(self.socket, nil, nil))
                self.serveConnection(conn: conn, onMessage: onMessage)
                self.acceptConnection(onMessage: onMessage)
            } catch {
                print("acceptConnection loop exiting: \(error)")
            }
        }
    }
    
    private func serveConnection(conn: Int32, onMessage: @escaping (TestMessage) -> Void) {
        DispatchQueue.global().async {
            do {
                try TestMessageConnection(socket: conn)
                    .receiveMessages(onMessage: onMessage)
            } catch {
                print("serveConnection error: \(error)")
            }
        }
    }
}
