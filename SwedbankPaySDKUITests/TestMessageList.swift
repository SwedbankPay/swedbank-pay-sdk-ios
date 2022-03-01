import Dispatch
import Foundation

class TestMessageList {
    private let queue = DispatchQueue(label: "TestMessageList", target: .global())
    private var messages: [TestMessage] = []
    private let waiterGroup = DispatchGroup()
    private var waiters = 0
    
    func append(message: TestMessage) {
        queue.async {
            self.messages.append(message)
            for _ in 0..<self.waiters {
                self.waiterGroup.leave()
            }
            self.waiters = 0
        }
    }
    
    func getMessages() -> [TestMessage] {
        return queue.sync {
            messages
        }
    }
    
    func waitForNewMessage(after messages: [TestMessage], timeout: Double) -> [TestMessage] {
        let messages: [TestMessage]? = queue.sync {
            if self.messages != messages {
                return self.messages
            } else {
                waiterGroup.enter()
                waiters += 1
                return nil
            }
        }
        if let messages = messages {
            return messages
        } else {
            _ = waiterGroup.wait(timeout: .now() + timeout)
            return getMessages()
        }
    }
    
    func waitForFirst(timeout: Double) -> TestMessage? {
        let messages = getMessages()
        if let message = messages.first {
            return message
        } else {
            return waitForNewMessage(after: messages, timeout: timeout).first
        }
    }
    
    func waitForMessage(timeout: Double, message: TestMessage) -> Bool {
        let messages = getMessages()
        if messages.contains(message) {
            return true
        } else {
            let start = Date()
            let newBatch = waitForNewMessage(after: messages, timeout: timeout)
            if newBatch.contains(message) {
                return true
            }
            let timeLeft = start.timeIntervalSinceNow + timeout
            if timeLeft <= 0 {
                return false
            }
            return waitForMessage(timeout: timeLeft, message: message)
        }
    }
}
