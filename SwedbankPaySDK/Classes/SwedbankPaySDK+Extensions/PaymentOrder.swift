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

public extension SwedbankPaySDK {
    static var defaultUserAgent: String = {
        let bundle = Bundle(for: SwedbankPaySDK.self)
        let version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String
        return "SwedbankPaySDK-iOS/\(version ?? "Unknown")"
    }()
    
    struct PaymentOrder : Codable {
        public var operation: PaymentOrderOperation
        public var currency: String
        public var amount: Int64
        public var vatAmount: Int64
        public var description: String
        public var userAgent: String
        public var language: Language
        public var instrument: Instrument?
        public var generateRecurrenceToken: Bool
        public var generatePaymentToken: Bool
        public var restrictedToInstruments: [String]?
        public var urls: PaymentOrderUrls
        public var payeeInfo: PayeeInfo
        public var payer: PaymentOrderPayer?
        public var orderItems: [OrderItem]?
        public var riskIndicator: RiskIndicator?
        public var disablePaymentMenu: Bool
        
        public init(
            operation: PaymentOrderOperation = .Purchase,
            currency: String,
            amount: Int64,
            vatAmount: Int64,
            description: String,
            userAgent: String = defaultUserAgent,
            language: Language = .English,
            instrument: Instrument? = nil,
            generateRecurrenceToken: Bool = false,
            generatePaymentToken: Bool = false,
            restrictedToInstruments: [String]? = nil,
            urls: PaymentOrderUrls,
            payeeInfo: PayeeInfo = .init(),
            payer: PaymentOrderPayer? = nil,
            orderItems: [OrderItem]? = nil,
            riskIndicator: RiskIndicator? = nil,
            disablePaymentMenu: Bool = false
        ) {
            self.operation = operation
            self.currency = currency
            self.amount = amount
            self.vatAmount = vatAmount
            self.description = description
            self.userAgent = userAgent
            self.language = language
            self.instrument = instrument
            self.generateRecurrenceToken = generateRecurrenceToken
            self.generatePaymentToken = generatePaymentToken
            self.restrictedToInstruments = restrictedToInstruments
            self.urls = urls
            self.payeeInfo = payeeInfo
            self.payer = payer
            self.orderItems = orderItems
            self.riskIndicator = riskIndicator
            self.disablePaymentMenu = disablePaymentMenu
        }
    }
    
    enum PaymentOrderOperation : String, Codable {
        case Purchase
        case Verify
    }
    
    struct PaymentOrderUrls : Codable {
        public var hostUrls: [URL]
        public var completeUrl: URL
        public var cancelUrl: URL?
        public var paymentUrl: URL?
        public var callbackUrl: URL?
        public var termsOfServiceUrl: URL?
                
        public init(
            hostUrls: [URL],
            completeUrl: URL,
            cancelUrl: URL? = nil,
            paymentUrl: URL? = nil,
            callbackUrl: URL? = nil,
            termsOfServiceUrl: URL? = nil
        ) {
            self.hostUrls = hostUrls
            self.completeUrl = completeUrl
            self.cancelUrl = cancelUrl
            self.paymentUrl = paymentUrl
            self.callbackUrl = callbackUrl
            self.termsOfServiceUrl = termsOfServiceUrl
        }
    }
    
    struct PayeeInfo : Codable {
        public var payeeId: String
        public var payeeReference: String
        public var payeeName: String?
        public var productCategory: String?
        public var orderReference: String?
        public var subsite: String?
        
        public init(
            payeeId: String = "",
            payeeReference: String = "",
            payeeName: String? = nil,
            productCategory: String? = nil,
            orderReference: String? = nil,
            subsite: String? = nil
        ) {
            self.payeeId = payeeId
            self.payeeReference = payeeReference
            self.payeeName = payeeName
            self.productCategory = productCategory
            self.orderReference = orderReference
            self.subsite = subsite
        }
    }
    
    struct PaymentOrderPayer : Codable {
        public var consumerProfileRef: String?
        public var email: String?
        public var msisdn: String?
         
        public init(
            consumerProfileRef: String? = nil,
            email: String? = nil,
            msisdn: String? = nil
        ) {
            self.consumerProfileRef = consumerProfileRef
            self.email = email
            self.msisdn = msisdn
        }
    }

    struct OrderItem : Codable {
        public var reference: String
        public var name: String
        public var type: ItemType
        public var `class`: String
        public var itemUrl: URL?
        public var imageUrl: URL?
        public var description: String?
        public var discountDescription: String?
        public var quantity: Int
        public var quantityUnit: String
        public var unitPrice: Int64
        public var discountPrice: Int64?
        public var vatPercent: Int
        public var amount: Int64
        public var vatAmount: Int64
        
        public init(
            reference: String,
            name: String,
            type: ItemType,
            class: String,
            itemUrl: URL? = nil,
            imageUrl: URL? = nil,
            description: String? = nil,
            discountDescription: String? = nil,
            quantity: Int,
            quantityUnit: String,
            unitPrice: Int64,
            discountPrice: Int64? = nil,
            vatPercent: Int,
            amount: Int64,
            vatAmount: Int64
        ) {
            self.reference = reference
            self.name = name
            self.type = type
            self.class = `class`
            self.itemUrl = itemUrl
            self.imageUrl = imageUrl
            self.description = description
            self.discountDescription = discountDescription
            self.quantity = quantity
            self.quantityUnit = quantityUnit
            self.unitPrice = unitPrice
            self.discountPrice = discountPrice
            self.vatPercent = vatPercent
            self.amount = amount
            self.vatAmount = vatAmount
        }
    }
    
    enum ItemType : String, Codable {
        case Product = "PRODUCT"
        case Service = "SERVICE"
        case ShippingFee = "SHIPPING_FEE"
        case PaymentFee = "PAYMENT_FEE"
        case Discount = "DISCOUNT"
        case ValueCode = "VALUE_CODE"
        case Other = "OTHER"
    }
    
    struct RiskIndicator : Codable {
        public var deliveryEmailAddress: String?
        public var deliveryTimeFrameIndicator: DeliveryTimeFrameIndicator?
        public var preOrderDate: String?
        public var preOrderPurchaseIndicator: PurchaseIndicator?
        public var shipIndicator: ShipIndicator.Raw?
        public var pickUpAddress: PickUpAddress?
        public var giftCardPurchase: Bool?
        public var reOrderPurchaseIndicator: PurchaseIndicator?
        
        public init(
            deliveryEmailAddress: String? = nil,
            deliveryTimeFrameIndicator: SwedbankPaySDK.DeliveryTimeFrameIndicator? = nil,
            preOrderDate: DateComponents? = nil,
            preOrderPurchaseIndicator: SwedbankPaySDK.PurchaseIndicator? = nil,
            shipIndicator: SwedbankPaySDK.ShipIndicator? = nil,
            giftCardPurchase: Bool? = nil,
            reOrderPurchaseIndicator: SwedbankPaySDK.PurchaseIndicator? = nil
        ) {
            self.deliveryEmailAddress = deliveryEmailAddress
            self.deliveryTimeFrameIndicator = deliveryTimeFrameIndicator
            self.preOrderDate = preOrderDate.map(SwedbankPaySDK.RiskIndicator.format(preOrderDate:))
            self.preOrderPurchaseIndicator = preOrderPurchaseIndicator
            self.shipIndicator = shipIndicator?.raw
            self.pickUpAddress = shipIndicator?.pickUpAddress
            self.giftCardPurchase = giftCardPurchase
            self.reOrderPurchaseIndicator = reOrderPurchaseIndicator
        }
        
        private static func format(preOrderDate: DateComponents) -> String {
            guard let year = preOrderDate.year else {
                fatalError("preOrderDate has no year")
            }
            guard let month = preOrderDate.month else {
                fatalError("preOrderDate has no month")
            }
            guard let day = preOrderDate.day else {
                fatalError("preOrderDate has no day")
            }
            return String(format: "%04d%02d%02d", year, month, day)
        }
    }
    
    enum DeliveryTimeFrameIndicator : String, Codable {
        case ElectronicDelivery = "01"
        case SameDayShipping = "02"
        case OvernightShipping = "03"
        case TwoDayOrMoreShipping = "04"
    }
    
    enum PurchaseIndicator : String, Codable {
        case MerchandiseAvailable = "01"
        case FutureAvailability = "02"
    }
    
    enum ShipIndicator {
        case ShipToBillingAddress
        case ShipToVerifiedAddress
        case ShipToDifferentAddress
        case PickUpAtStore(pickUpAddress: PickUpAddress)
        case DigitalGoods
        case Tickets
        case Other
    }
    
    struct PickUpAddress : Codable {
        public var name: String?
        public var streetAddress: String?
        public var coAddress: String?
        public var city: String?
        public var zipCode: String?
        public var countryCode: String?
    }
}

public extension SwedbankPaySDK.PaymentOrderUrls {
    private static func buildCompleteUrl(configuration: SwedbankPaySDK.MerchantBackendConfiguration) -> URL {
        return URL(string: "complete", relativeTo: configuration.backendUrl)!
    }
    private static func buildCancelUrl(configuration: SwedbankPaySDK.MerchantBackendConfiguration) -> URL {
        return URL(string: "cancel", relativeTo: configuration.backendUrl)!
    }
    private static func buildPaymentUrl(configuration: SwedbankPaySDK.MerchantBackendConfiguration, language: SwedbankPaySDK.Language, id: String) -> URL {
        var components = URLComponents()
        components.path = "sdk-callback/ios-universal-link"
        var queryItems: [URLQueryItem] = [
            .init(name: "scheme", value: configuration.callbackScheme),
            .init(name: "language", value: language.rawValue),
            .init(name: "id", value: id)
        ]
        if let appName = getAppName() {
            queryItems.append(.init(name: "app", value: appName))
        }
        components.queryItems = queryItems
        return components.url(relativeTo: configuration.backendUrl)!
    }
    private static func getAppName() -> String? {
        let bundle = Bundle.main
        let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        return displayName ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
    }
    
    /// Convenience initializer that generates a set of urls
    /// for a payment using `MerchantBackendConfiguration`
    ///  - parameter configuration: the MerchantBackendConfiguration where this payment is to be used
    ///  - parameter language: the language of the payment
    ///  - parameter callbackUrl: the callbackUrl to set for the payment
    ///  - parameter termsOfServiceUrl: the Terms of Service url of the payment
    ///  - parameter identifier: an unique identifier that is used to identify this payment **inside this application**
    init(
        configuration: SwedbankPaySDK.MerchantBackendConfiguration,
        language: SwedbankPaySDK.Language,
        callbackUrl: URL? = nil,
        termsOfServiceUrl: URL? = nil,
        identifier: String = UUID().uuidString
    ) {
        self.init(
            configuration: configuration,
            language: language,
            hostUrl: configuration.backendUrl,
            callbackUrl: callbackUrl,
            termsOfServiceUrl: termsOfServiceUrl
        )
    }
    
    /// Convenience initializer that generates a set of urls
    /// for a payment using `MerchantBackendConfiguration`
    ///  - parameter configuration: the MerchantBackendConfiguration where this payment is to be used
    ///  - parameter language: the language of the payment
    ///  - parameter hostUrl: the url to set in the hostUrls of the payment.
    ///   This will also become the `webViewBaseURL` of the `ViewPaymentOrderInfo` created for this payment
    ///  - parameter callbackUrl: the callbackUrl to set for the payment
    ///  - parameter termsOfServiceUrl: the Terms of Service url of the payment
    ///  - parameter identifier: an unique identifier that is used to identify this payment **inside this application**
    init(
        configuration: SwedbankPaySDK.MerchantBackendConfiguration,
        language: SwedbankPaySDK.Language,
        hostUrl: URL,
        callbackUrl: URL? = nil,
        termsOfServiceUrl: URL? = nil,
        identifier: String = UUID().uuidString
    ) {
        self.hostUrls = [hostUrl]
        self.completeUrl = SwedbankPaySDK.PaymentOrderUrls.buildCompleteUrl(configuration: configuration)
        self.cancelUrl = SwedbankPaySDK.PaymentOrderUrls.buildCancelUrl(configuration: configuration)
        self.paymentUrl = SwedbankPaySDK.PaymentOrderUrls.buildPaymentUrl(configuration: configuration, language: language, id: identifier)
        self.callbackUrl = callbackUrl
        self.termsOfServiceUrl = termsOfServiceUrl
    }
}

public extension SwedbankPaySDK.ShipIndicator {
    enum Raw : String, Codable {
        case ShipToBillingAddress = "01"
        case ShipToVerifiedAddress = "02"
        case ShipToDifferentAddress = "03"
        case PickUpAtStore = "04"
        case DigitalGoods = "05"
        case Tickets = "06"
        case Other = "07"
    }
    
    var raw: Raw {
        switch self {
        case .ShipToBillingAddress: return .ShipToBillingAddress
        case .ShipToVerifiedAddress: return .ShipToVerifiedAddress
        case .ShipToDifferentAddress: return .ShipToDifferentAddress
        case .PickUpAtStore: return .PickUpAtStore
        case .DigitalGoods: return .DigitalGoods
        case .Tickets: return .Tickets
        case .Other: return .Other
        }
    }
    
    var pickUpAddress: SwedbankPaySDK.PickUpAddress? {
        switch self {
        case .PickUpAtStore(let pickUpAddress): return pickUpAddress
        default: return nil
        }
    }
}
