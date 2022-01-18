import Foundation

class TestMessageConnection {
    private let stream: UnsafeMutablePointer<FILE>
        
    init(socket: Int32) throws {
        guard let stream = fdopen(socket, "r+") else {
            throw SocketHelper.Error(errno: errno)
        }
        self.stream = stream
    }
    
    func send(message: TestMessage) {
        let data = try! JSONEncoder().encode(message)
        let length: Int = data.count
        let lengthResult = withUnsafeBytes(of: length) {
            fwrite($0.baseAddress, $0.count, 1, stream)
        }
        guard lengthResult == 1 else {
            perror("fwrite")
            return
        }
        let result = data.withUnsafeBytes {
            fwrite($0.baseAddress, $0.count, 1, stream)
        }
        guard result == 1 else {
            perror("fwrite")
            return
        }
        fflush(stream)
    }
    
    func close() {
        fclose(stream)
    }
    
    func receiveMessages(onMessage: (TestMessage) -> Void) {
        while let message = receiveMessage() {
            onMessage(message)
        }
        fclose(stream)
    }
    
    private func receiveMessage() -> TestMessage? {
        var length: Int = 0
        let lengthResult = withUnsafeMutableBytes(of: &length) {
            fread($0.baseAddress, $0.count, 1, stream)
        }
        guard lengthResult == 1 else {
            return nil
        }
        var data = Data(count: length)
        let result = data.withUnsafeMutableBytes {
            fread($0.baseAddress, $0.count, 1, stream)
        }
        guard result == 1 else {
            return nil
        }
        return try! JSONDecoder().decode(TestMessage.self, from: data)
    }
}
