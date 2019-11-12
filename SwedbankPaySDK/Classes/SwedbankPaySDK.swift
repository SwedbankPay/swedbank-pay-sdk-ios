import Alamofire
import ObjectMapper

/// Class defining data types exposed to the client app using the SDK
public final class SwedbankPaySDK {
    
    /// Swedbank Pay SDK Configuration
    public struct Configuration {
        var backendUrl: String?
        var headers: Dictionary<String, String>?
        var domainWhitelist: [WhitelistedDomain]?
        var pinPublicKeys: [PinPublicKeys]?

        /// Initializer for `SwedbankPaySDK.Configuration`
        /// - parameter backendUrl: backend URL
        /// - parameter headers: HTTP Request headers Dictionary in a form of 'apikey, access token' -pair
        /// - parameter domainWhitelist: Optional array of domains allowed to be connected to; defaults to `backendURL` if nil
        /// - parameter certificatePins: Optional array of domains for certification pinning, matched against any certificate found anywhere in the app bundle
        public init(backendUrl: String?, headers: Dictionary<String, String>?, domainWhitelist: [WhitelistedDomain]? = nil, pinPublicKeys: [PinPublicKeys]? = nil) {
            self.backendUrl = backendUrl
            self.headers = headers
            self.domainWhitelist = domainWhitelist
            self.pinPublicKeys = pinPublicKeys
        }
    }
    
    ///  Whitelisted domains
    public struct WhitelistedDomain {
        var domain: String?
        var includeSubdomains: Bool

        /// Initializer for `SwedbankPaySDK.WhitelistedDomain`
        /// - parameter domain: URL of the domain as a String
        /// - parameter includeSubdomains: if `true`, means any subdomain of `domain` is valid
        public init(domain: String?, includeSubdomains: Bool) {
            self.domain = domain
            self.includeSubdomains = includeSubdomains
        }
    }
    
    /// Object for certificate pinning with public keys found in app bundle certificates
    public struct PinPublicKeys {
        var pattern: String
        var publicKeys: [SecKey]
        
        /// Initializer for PinPublicKeys, by default uses public keys of all certificates found in app bundle
        /// - parameter pattern: the hostname pattern to pin
        /// - parameter publicKeys: by default, searches for all certificates in app bundle and uses them
        public init(pattern: String, publicKeys: [SecKey] = ServerTrustPolicy.publicKeys()) {
            if publicKeys.isEmpty {
                print("No publicKeys defined for certificate pinning; did you forget to add a certificate?")
            }
            self.pattern = pattern
            self.publicKeys = publicKeys
        }
        
        /// Initializer for PinPublicKeys, expects an array of certificate file names for each hostname pattern
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
    
    ///  Consumer object for Swedbank Pay SDK
    public struct Consumer: Codable {
        var consumerCountryCode: String?
        var msisdn: String?
        var email: String?
        var nationalIdentifier: NationalIdentifier?
        
        /// Initializer for `SwedbankPaySDK.Consumer`
        /// - parameter consumerCountryCode: String representing consumer's country code
        /// - parameter msisdn: String representing consumer's phone number
        /// - parameter email: String representing consumer's email address
        /// - parameter nationalIdentifier: `NationalIdentifier`object representing consumer's social security number and country code
        public init(consumerCountryCode: String?, msisdn: String?, email: String?, nationalIdentifier: NationalIdentifier?) {
            self.consumerCountryCode = consumerCountryCode
            self.msisdn = msisdn
            self.email = email
            self.nationalIdentifier = nationalIdentifier
        }
    }
    
    /// National identifier object for Swedbank Pay SDK
    public struct NationalIdentifier: Codable {
        var socialSecurityNumber: String?
        var countryCode: String?
        
        /// Initializer for `SwedbankPaySDK.NationalIdentifier`
        /// - parameter socialSecurityNumber: String representing consumer's social security number
        /// - parameter countryCode: String representing consumer's country code
        public init(socialSecurityNumber: String?, countryCode: String?) {
            self.socialSecurityNumber = socialSecurityNumber
            self.countryCode = countryCode
        }
    }
    
    // MARK: Problem 
    
    /// `ClientProblemType` URLs
    enum ClientProblemType: String {
        case BadRequest = "https://api.payex.com/psp/errordetail/mobilesdk/badrequest" // 400
        case Unauthorized = "https://api.payex.com/psp/errordetail/mobilesdk/unauthorized" // 401
        case InputError = "https://api.payex.com/psp/errordetail/inputerror"
        case Forbidden = "https://api.payex.com/psp/errordetail/forbidden"
        case NotFound = "https://api.payex.com/psp/errordetail/notfound"
    }
    
    /// `ServerProblemType` URLs
    enum ServerProblemType: String {
        case InternalServerError = "about:blank" // 500
        case BadGateway = "https://api.payex.com/psp/errordetail/mobilesdk/badgateway" // 502
        case GatewayTimeOut = "https://api.payex.com/psp/errordetail/mobilesdk/gatewaytimeout" // 504
        case SystemError = "https://api.payex.com/psp/errordetail/mobilesdk/systemerror"
        case ConfigurationError = "https://api.payex.com/psp/errordetail/mobilesdk/configurationerror"
    }
    
    /// Base class for any problems encountered in the payment.
    ///
    /// All problems are either `Client` or `Server` problems. A Client problem is one where there was something wrong with the request
    /// the client app sent to the service. A Client problem always implies an HTTP response status in the Client Error range, 400-499.
    ///
    /// A Server problem is one where the service understood the request, but could not fulfill it. If the backend responds in an unexpected
    /// manner, the situation will be interpreted as a Server error, unless the response status is in 400-499 range, in which case it is still considered a
    /// Client error.
    ///
    /// This separation to Client and Server errors provides a crude but often effective way of distinguishing between temporary service unavailability
    /// and permanent configuration errors.
    ///
    /// Client and Server errors are further divided to specific types. See individual documentation for details.
    public enum Problem {
        case Client(ClientProblem)
        case Server(ServerProblem)
    }
    
    /// A Client Problem always implies a HTTP status in 400-499.
    public enum ClientProblem {
        
        /// Base class for `Client` Problems defined by the example backend
        case MobileSDK(MobileSDKProblem)
        
        /// Base class for `Client` problems defined by the Swedbank Pay backend.
        ///
        /// [https://developer.payex.com/xwiki/wiki/developer/view/Main/ecommerce/technical-reference/#HProblems]
        case SwedbankPay(
            type: SwedbankPayProblem,
            title: String?,
            detail: String?,
            instance: String?,
            action: String?,
            problems: [SwedbankPaySubProblem]?,
            raw: String?
        )
        
        /// `Client` problem with an unrecognized type.
        case Unknown(
            type: String?,
            title: String?,
            status: Int,
            detail: String?,
            instance: String?,
            raw: String?
        )
        
        /// Pseudo-problem, not actually parsed from an application/problem+json response. This problem is emitted if the server response is in
        /// an unexpected format and the HTTP status is in the Client Error range (400-499).
        case UnexpectedContent(
            status: Int,
            contentType: String?,
            body: String?
        )
        
        public enum MobileSDKProblem {
            
            /// The merchant backend rejected the request because its authentication headers were invalid.
            case Unauthorized (
                message: String?,
                raw: String?
            )
            
            /// The merchant backend did not understand the request.
            case InvalidRequest (
                message: String?,
                raw: String?
            )
        }
        public enum SwedbankPayProblem {
            
            /// The request could not be handled because the request was malformed somehow (e.g. an invalid field value).
            case InputError
            
            /// The request was understood, but the service is refusing to fulfill it. You may not have access to the requested resource.
            case Forbidden
            
            /// The requested resource was not found.
            case NotFound
        }
    }
    
    /// Any unexpected response where the HTTP status is outside 400-499 results in a `Server` Problem; usually it means the status was in 500-599.
    public enum ServerProblem {
        
        /// Base class for `Server` Problems defined by the example backend.
        case MobileSDK(MobileSDKProblem)
        
        /// Base class for `Server` problems defined by the Swedbank Pay backend.
        ///
        /// [https://developer.payex.com/xwiki/wiki/developer/view/Main/ecommerce/technical-reference/#HProblems]
        case SwedbankPay(
            type: SwedbankPayProblem,
            title: String?,
            detail: String?,
            instance: String?,
            action: String?,
            problems: [SwedbankPaySubProblem]?,
            raw: String?
        )
        
        /// `Server` problem with an unrecognized type.
        case Unknown(
            type: String?,
            title: String?,
            status: Int,
            detail: String?,
            instance: String?,
            raw: String?
        )
        
        /// Pseudo-problem, not actually parsed from an application/problem+json response. This problem is emitted if the server response is in
        /// an unexpected format and the HTTP status is not in the Client Error range.
        case UnexpectedContent(
            status: Int,
            contentType: String?,
            body: String?
        )
        
        public enum MobileSDKProblem {
            
            /// The merchant backend timed out trying to connect to the Swedbank Pay backend.
            case BackendConnectionTimeout (
                message: String?,
                raw: String?
            )
            
            /// The merchant backend failed to connect to the Swedbank Pay backend.
            case BackendConnectionFailure (
                message: String?,
                raw: String?
            )
            
            /// The merchant backend received an invalid response from the Swedbank Pay backend.
            case InvalidBackendResponse (
                body: String?,
                raw: String?
            )
        }
        public enum SwedbankPayProblem {
            
            /// A generic error message. HTTP Status code 500.
            case SystemError
            
            /// An error relating to configuration issues. HTTP Status code 500.
            case ConfigurationError
        }
    }
    
    /// Object detailing the reason for a [SwedbankPayProblem].
    ///
    /// See [https://developer.payex.com/xwiki/wiki/developer/view/Main/ecommerce/technical-reference/#HProblems].
    public struct SwedbankPaySubProblem: Mappable {
        public var name: String?
        public var description: String?
        
        public init?(map: Map) {
        }
        
        public mutating func mapping(map: Map) {
             name <- map["name"]
             description <- map["description"]
        }
    }
}
