import ObjectMapper

public class SwedbankPaySDK {
    
    public struct Consumer: Codable {
        var consumerCountryCode: String?
        var msisdn: String?
        var email: String?
        var nationalIdentifier: NationalIdentifier?
        
        public init(consumerCountryCode: String?, msisdn: String?, email: String?, nationalIdentifier: NationalIdentifier?) {
            self.consumerCountryCode = consumerCountryCode
            self.msisdn = msisdn
            self.email = email
            self.nationalIdentifier = nationalIdentifier
        }
    }
    
    public struct NationalIdentifier: Codable {
        var socialSecurityNumber: String?
        var countryCode: String?
        
        public init(socialSecurityNumber: String?, countryCode: String?) {
            self.socialSecurityNumber = socialSecurityNumber
            self.countryCode = countryCode
        }
    }
    
    enum ClientProblemType: String {
        case BadRequest = "https://api.payex.com/psp/errordetail/mobilesdk/badrequest" // 400
        case Unauthorized = "https://api.payex.com/psp/errordetail/mobilesdk/unauthorized" // 401
        case InputError = "https://api.payex.com/psp/errordetail/inputerror"
        case Forbidden = "https://api.payex.com/psp/errordetail/forbidden"
        case NotFound = "https://api.payex.com/psp/errordetail/notfound"
    }
    
    enum ServerProblemType: String {
        case InternalServerError = "about:blank" // 500
        case BadGateway = "https://api.payex.com/psp/errordetail/mobilesdk/badgateway" // 502
        case GatewayTimeOut = "https://api.payex.com/psp/errordetail/mobilesdk/gatewaytimeout" // 504
        case SystemError = "https://api.payex.com/psp/errordetail/mobilesdk/systemerror"
        case ConfigurationError = "https://api.payex.com/psp/errordetail/mobilesdk/configurationerror"
    }
    
    public enum Problem {
        case Client(ClientProblem) // 4xx
        case Server(ServerProblem) // 5xx
    }
    
    public enum ClientProblem {
        case MobileSDK(MobileSDKProblem)
        case SwedbankPay(
            type: SwedbankPayProblem,
            title: String?,
            detail: String?,
            instance: String?,
            action: String?,
            problems: [SwedbankPaySubProblem]?,
            raw: String?
        )
        case Unknown(
            type: String?,
            title: String?,
            status: Int,
            detail: String?,
            instance: String?,
            raw: String?
        )
        case UnexpectedContent(
            status: Int,
            contentType: String?,
            body: String?
        )
        
        public enum MobileSDKProblem {
            case Unauthorized (
                message: String?,
                raw: String?
            )
            case InvalidRequest (
                message: String?,
                raw: String?
            )
        }
        public enum SwedbankPayProblem {
            case InputError
            case Forbidden
            case NotFound
        }
    }
    
    public enum ServerProblem {
        case MobileSDK(MobileSDKProblem)
        case SwedbankPay(
            type: SwedbankPayProblem,
            title: String?,
            detail: String?,
            instance: String?,
            action: String?,
            problems: [SwedbankPaySubProblem]?,
            raw: String?
        )
        case Unknown(
            type: String?,
            title: String?,
            status: Int,
            detail: String?,
            instance: String?,
            raw: String?
        )
        case UnexpectedContent(
            status: Int,
            contentType: String?,
            body: String?
        )
        
        public enum MobileSDKProblem {
            case BackendConnectionTimeout (
                message: String?,
                raw: String?
            )
            case BackendConnectionFailure (
                message: String?,
                raw: String?
            )
            case InvalidBackendResponse (
                body: String?,
                raw: String?
            )
        }
        public enum SwedbankPayProblem {
            case SystemError
            case ConfigurationError
            case NotFound
        }
    }
    
    public struct SwedbankPaySubProblem: Mappable {
        var name: String?
        var description: String?
        
        public init?(map: Map) {
        }
        
        public mutating func mapping(map: Map) {
             name <- map["name"]
             description <- map["description"]
        }
    }
}
