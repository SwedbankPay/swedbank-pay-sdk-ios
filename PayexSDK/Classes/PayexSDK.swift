public class PayexSDK {
    
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
}
