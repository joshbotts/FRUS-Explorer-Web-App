// `frus-light --check-health`: asks this container's own /healthz, for Docker's HEALTHCHECK.
// The runtime image has no curl, so this speaks just enough HTTP over a plain socket.

import Foundation
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

enum HealthCheck {
    /// True when `GET path` on the loopback address answers 200 within `timeout` seconds.
    static func isHealthy(port: Int, path: String = "/healthz", timeout: Int = 3) -> Bool {
        probe(port: port, path: path, timeout: timeout).hasPrefix("HTTP/1.1 200")
    }

    /// The response's status line, or what went wrong; Docker keeps it in the health log.
    /// Tries 127.0.0.1, then ::1 when nothing listens on IPv4, so a server bound to either
    /// answers, and a server that hangs costs one timeout, not two.
    static func probe(port: Int, path: String = "/healthz", timeout: Int = 3) -> String {
        let ipv4 = probe(family: AF_INET, port: port, path: path, timeout: timeout)
        guard ipv4.error == ECONNREFUSED else { return ipv4.text }
        let ipv6 = probe(family: AF_INET6, port: port, path: path, timeout: timeout)
        return ipv6.error == nil ? ipv6.text : ipv4.text
    }

    private static func probe(family: Int32, port: Int, path: String, timeout: Int) -> (text: String, error: Int32?) {
        func failure(_ what: String) -> (text: String, error: Int32?) {
            let code = errno
            return ("\(what): \(String(cString: strerror(code)))", code)
        }
        let host = family == AF_INET ? "127.0.0.1" : "[::1]"
        #if canImport(Glibc)
        let fd = socket(family, Int32(SOCK_STREAM.rawValue), 0)
        #else
        let fd = socket(family, SOCK_STREAM, 0)
        #endif
        guard fd >= 0 else { return failure("socket") }
        defer { close(fd) }
        var limit = timeval(tv_sec: timeout, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &limit, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &limit, socklen_t(MemoryLayout<timeval>.size))
        #if canImport(Darwin)
        var noSignal: Int32 = 1  // a reset connection must not kill the process with SIGPIPE
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &noSignal, socklen_t(MemoryLayout<Int32>.size))
        let sendFlags: Int32 = 0
        #else
        let sendFlags = Int32(MSG_NOSIGNAL)
        #endif

        let connected: Int32
        if family == AF_INET {
            var address = sockaddr_in()
            #if canImport(Darwin)
            address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            #endif
            address.sin_family = sa_family_t(AF_INET)
            address.sin_port = in_port_t(UInt16(port).bigEndian)
            address.sin_addr.s_addr = inet_addr("127.0.0.1")
            connected = withUnsafePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        } else {
            var address = sockaddr_in6()
            #if canImport(Darwin)
            address.sin6_len = UInt8(MemoryLayout<sockaddr_in6>.size)
            #endif
            address.sin6_family = sa_family_t(AF_INET6)
            address.sin6_port = in_port_t(UInt16(port).bigEndian)
            address.sin6_addr = in6addr_loopback
            connected = withUnsafePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in6>.size))
                }
            }
        }
        guard connected == 0 else { return failure("connect to \(host):\(port)") }

        let request = Array("GET \(path) HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n".utf8)
        let sent = request.withUnsafeBufferPointer { send(fd, $0.baseAddress, $0.count, sendFlags) }
        guard sent == request.count else { return failure("send") }

        // Read until the status line ends, the line is too long to be one, or the peer closes.
        var line: [UInt8] = []
        var chunk = [UInt8](repeating: 0, count: 64)
        while line.count < 128, !line.contains(10) {
            let received = recv(fd, &chunk, chunk.count, 0)
            if received < 0 { return failure("recv") }
            if received == 0 { break }
            line += chunk.prefix(received)
        }
        guard !line.isEmpty else { return ("no response", nil) }
        let statusLine = line.prefix { $0 != 13 && $0 != 10 }
        return (String(decoding: statusLine, as: UTF8.self), nil)
    }
}
