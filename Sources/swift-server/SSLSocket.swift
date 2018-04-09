import Foundation
import COpenSSL

class SSLSocket: Socket {
    
    static var sslContext: UnsafeMutablePointer<SSL_CTX>?
    
    static func initSSLContext(certificateFile: String, privateKeyFile: String) {
        SSL_load_error_strings();
        SSL_library_init();
        OpenSSL_add_all_digests();
        SSLSocket.sslContext = SSL_CTX_new(TLSv1_2_server_method())
        if SSL_CTX_use_certificate_file(SSLSocket.sslContext, certificateFile , SSL_FILETYPE_PEM) != 1 {
            fatalError("Failed to use provided certificate file")
        }
        if SSL_CTX_use_PrivateKey_file(SSLSocket.sslContext, privateKeyFile, SSL_FILETYPE_PEM) != 1 {
            fatalError("Failed to use provided preivate key file")
        }
    }
    
    var sslSocket: UnsafeMutablePointer<SSL>
    
    override init(socketFD: Int32) {
        sslSocket = SSL_new(SSLSocket.sslContext!);
        super.init(socketFD: socketFD)
        
        SSL_set_fd(sslSocket, socketFileDescriptor);
        let ssl_err = SSL_accept(sslSocket);
        if ssl_err <= 0 { close(socketFileDescriptor) }
    }
    
    override func sendData(data: [UInt8]) {
        var bytesToSend = data.count
        repeat {
            let bytesSent = SSL_write(sslSocket, data, Int32(bytesToSend));
            if bytesSent <= 0 { return }
            bytesToSend -= Int(bytesSent)
        } while bytesToSend > 0
    }
    
    override func acceptRequest() -> Request? {
        var requestBuffer: [UInt8] = [UInt8](repeating: 0, count: bufferSize)
        var requestLength: Int = 0
        while true {
            let bytesRead = SSL_read(sslSocket, &requestBuffer[requestLength], Int32(bufferSize - requestLength));
            guard bytesRead > 0 else { return nil }
            requestLength += Int(bytesRead)
            if let requestString = String(bytes: requestBuffer[..<requestLength].filter{$0 != 13}, encoding: .utf8) {
                return Request.parse(string: requestString);
            }
        }
    }
    
}
