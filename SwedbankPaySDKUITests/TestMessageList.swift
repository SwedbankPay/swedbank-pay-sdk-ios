import Dispatch
import Foundation

extension String: Error {
    var localizedDescription: String {
        return self
    }
}

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
            let msg = messages
            messages.removeAll()
            return msg
        }
    }
    
    func waitForNewMessage(after messages: [TestMessage], timeout: Double) -> [TestMessage] {
        let messages: [TestMessage]? = queue.sync {
            if self.messages != messages {
                let msg = self.messages
                self.messages.removeAll()
                return msg
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
    
    func makeErrorIfExists(_ messages: [TestMessage]) throws {
        for msg in messages {
            if case let .error(errorMessage) = msg {
                print("got error: \(errorMessage)")
                throw errorMessage
            }
        }
    }
    
    func waitForMessage(timeout: Double, message: TestMessage) throws -> Bool {
        let messages = getMessages()
        try makeErrorIfExists(messages)
        
        if messages.contains(message) {
            return true
        } else {
            let start = Date()
            let newBatch = waitForNewMessage(after: messages, timeout: timeout)
            try makeErrorIfExists(newBatch)
            
            if newBatch.contains(message) {
                return true
            }
            let timeLeft = start.timeIntervalSinceNow + timeout
            if timeLeft <= 0 {
                return false
            }
            return try waitForMessage(timeout: timeLeft, message: message)
        }
    }
}
