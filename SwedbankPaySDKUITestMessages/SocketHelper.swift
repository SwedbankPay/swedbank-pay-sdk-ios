import Foundation

enum SocketHelper {
    struct Error: Swift.Error {
        var error: String?
        
        init(errno: Int32) {
            let cstring = strerror(errno)
            error = cstring.flatMap { String.init(cString: $0) }
        }
    }
    
    @discardableResult
    static func throwIfFailure(_ result: Int32) throws -> Int32 {
        if result < 0 {
            throw Error(errno: errno)
        }
        return result
    }
    
    static func makeServer() throws -> (socket: Int32, port: UInt16) {
        let sock = try makeTcpSocket()
        do {
            try bindToLoopback(sock)
            try throwIfFailure(listen(sock, 1))
            let port = try getPort(sock)
            return (sock, port)
        } catch {
            close(sock)
            throw error
        }
    }
    
    static func makeClient(port: UInt16) throws -> Int32 {
        let sock = try makeTcpSocket()
        do {
            try connectToLoopback(sock, port: port)
            return sock
        } catch {
            close(sock)
            throw error
        }
    }
    
    private static func makeTcpSocket() throws -> Int32 {
        return try throwIfFailure(socket(PF_INET, SOCK_STREAM, 0))
    }
    
    private static func withSockaddr(
        _ addr: sockaddr_in,
        f: (UnsafePointer<sockaddr>, socklen_t) -> Int32
    ) throws {
        let size = socklen_t(MemoryLayout.stride(ofValue: addr))
        try throwIfFailure(withUnsafeBytes(of: addr) {
            f($0.bindMemory(to: sockaddr.self).baseAddress!, size)
        })
    }
    
    private static func bindToLoopback(_ sock: Int32) throws {
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_addr = in_addr(s_addr: INADDR_LOOPBACK.bigEndian)
        try withSockaddr(addr) { ptr, size in
            bind(sock, ptr, size)
        }
    }
    
    private static func connectToLoopback(_ sock: Int32, port: UInt16) throws {
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr = in_addr(s_addr: INADDR_LOOPBACK.bigEndian)
        try withSockaddr(addr) { ptr, size in
            connect(sock, ptr, size)
        }
    }

    private static func getPort(_ sock: Int32) throws -> UInt16 {
        var addr = sockaddr_in()
        var size = socklen_t(MemoryLayout.stride(ofValue: addr))
        try throwIfFailure(withUnsafeMutableBytes(of: &addr) {
            getsockname(sock, $0.bindMemory(to: sockaddr.self).baseAddress, &size)
        })
        return UInt16(bigEndian: addr.sin_port)
    }
}
