//
// Copyright 2019 Swedbank AB
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import Alamofire

public extension SwedbankPaySDK {
    
    /// Object for certificate pinning with public keys found in app bundle certificates
    struct PinPublicKeys {
        var pattern: String
        var publicKeys: [SecKey]
        
        /// Initializer for `SwedbankPaySDK.PinPublicKeys`, by default uses public keys of all certificates found in app bundle
        /// - parameter pattern: the hostname pattern to pin
        /// - parameter publicKeys: by default, searches for all certificates in app bundle and uses them
        public init(pattern: String, publicKeys: [SecKey] = ServerTrustPolicy.publicKeys()) {
            if publicKeys.isEmpty {
                print("No publicKeys defined for certificate pinning; did you forget to add a certificate?")
            }
            self.pattern = pattern
            self.publicKeys = publicKeys
        }
        
        /// Initializer for `SwedbankPaySDK.PinPublicKeys`, expects an array of certificate file names for each hostname pattern
        /// - parameter pattern: the hostname pattern to pin
        /// - parameter certificateFileNames: certificate filenames to look for from the app bundle
        public init(pattern: String, certificateFileNames: String...) {
            var publicKeys: [SecKey] = []
            
            /// Returns the public key from the certificate
            func publicKey(for certificate: SecCertificate) -> SecKey? {
                if #available(iOS 12, *) {
                    return SecCertificateCopyKey(certificate)
                } else {
                    var publicKey: SecKey?

                    let policy = SecPolicyCreateBasicX509()
                    var trust: SecTrust?
                    let trustCreationStatus = SecTrustCreateWithCertificates(certificate, policy, &trust)

                    if let trust = trust, trustCreationStatus == errSecSuccess {
                        publicKey = SecTrustCopyPublicKey(trust)
                    }

                    return publicKey
                }
            }
            
            for fileName in certificateFileNames {
                if let filepath = Bundle.main.path(forResource: fileName, ofType: nil) {
                    do {
                        let data = try NSData(contentsOfFile: filepath) as CFData
                        if let certificate = SecCertificateCreateWithData(nil, data) {
                            if let publicKey = publicKey(for: certificate) {
                                publicKeys.append(publicKey)
                            }
                        }
                    } catch {
                        print("Could not read certificate file: \(fileName)")
                    }
                } else {
                    print("Certificate file was not found: \(fileName)")
                }
            }
            self.init(pattern: pattern, publicKeys: publicKeys)
        }
    }
}
