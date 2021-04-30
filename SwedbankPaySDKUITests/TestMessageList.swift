import Dispatch

class TestMessageList {
    enum PollError: Error {
        case timeout
    }
    
    private let queue = DispatchQueue(label: "TestMessageList", target: .global())
    private let semaphore = DispatchSemaphore(value: 0)
    private var list: [TestMessage] = []
    
    func append(message: TestMessage) {
        queue.async {
            self.list.append(message)
            self.semaphore.signal()
        }
    }
    
    func poll(timeout: Double) throws -> TestMessage {
        if semaphore.wait(timeout: .now() + timeout) == .timedOut {
            throw PollError.timeout
        }
        return queue.sync {
            self.list.removeFirst()
        }
    }
}
