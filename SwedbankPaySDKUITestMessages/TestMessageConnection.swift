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
        let dataStr = "\(message)\n"
        let data = dataStr.data(using: .utf8)!
        let result = data.withUnsafeBytes {
            fwrite($0.baseAddress, $0.count, 1, stream)
        }
        if result == 1 {
            fflush(stream)
        }
    }
    
    func close() {
        fclose(stream)
    }
    
    func receiveMessages(onMessage: (TestMessage) -> Void) {
        var len: size_t = 0
        while let cLine = fgetln(stream, &len) {
            let data = Data(bytes: cLine, count: len)
            let line = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .newlines)
            let message = line.flatMap(TestMessage.init(rawValue:))
            message.map(onMessage)
        }
        fclose(stream)
    }
}
