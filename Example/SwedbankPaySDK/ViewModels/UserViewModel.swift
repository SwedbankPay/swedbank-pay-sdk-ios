import UIKit
import SwedbankPaySDK

/// Singleton ViewModel for user data
class UserViewModel {
    
    static let shared = UserViewModel()
    
    private init() {}
    
    /// In this example the default user is unidentified Norwegian
    private var userType: UserType = .Anonymous
    private var country: Country = .Norway
    private var currency: Currency = .NOK
    
    /// Returns the country currently in use
    public func getCountry() -> Country {
        return country
    }
    
    /// Returns the currency currently in use
    public func getCurrency() -> Currency {
        return currency
    }
    
    /// Returns the user type, anonymous or identified
    public func getUserType() -> UserType {
        return userType
    }
    
    /// Returns the language code for merchantData
    public func getLanguageCode() -> String {
        switch country {
        case .Norway:
            return "no-NO"
        case .Sweden:
            return "sv-SE"
        }
    }
    
    /// Sets the country for user
    public func setCountry(_ country: Country) {
        self.country = country
        switch country {
        case .Norway:
            self.currency = .NOK
        case .Sweden:
            self.currency = .SEK
        }
    }
    
    /// Sets the user type, anonymous or identified
    public func setUserType(_ type: UserType) {
        self.userType = type
    }
    
    /// Returns the Consumer required, nil for anonymous payment
    public func getConsumer() -> SwedbankPaySDK.Consumer? {
        switch userType {
        case .Anonymous:
            return nil
        case .Identified:
            switch country {
            case .Norway:
                return SwedbankPaySDK.Consumer.init(
                    consumerCountryCode: "NO",
                    msisdn: "+4798765432",
                    email: "olivia.nyhuus@payex.com",
                    nationalIdentifier: SwedbankPaySDK.NationalIdentifier.init(
                        socialSecurityNumber: "26026708248",
                        countryCode: "NO"
                    )
                )
            case .Sweden:
                return SwedbankPaySDK.Consumer.init(
                    consumerCountryCode: "SE",
                    msisdn: "+46739000001",
                    email: "leia.ahlstrom@payex.com",
                    nationalIdentifier: SwedbankPaySDK.NationalIdentifier.init(
                        socialSecurityNumber: "971020-2392",
                        countryCode: "SE"
                    )
                )
            }
        }
    }
}
