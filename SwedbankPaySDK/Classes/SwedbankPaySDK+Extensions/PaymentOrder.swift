//
//  PaymentOrder.swift
//  Alamofire
//
//  Created by Pertti Kroger on 18.2.2020.
//

import Foundation

public extension SwedbankPaySDK {
    static var defaultUserAgent: String = {
        let bundle = Bundle(for: SwedbankPaySDK.self)
        let version = bundle.infoDictionary?[kCFBundleVersionKey as String] as? String
        return "SwedbankPaySDK-iOS/\(version ?? "Unknown")"
    }()
    
    struct PaymentOrder : Encodable {
        public var operation: PaymentOrderOperation
        public var currency: String
        public var amount: Int64
        public var vatAmount: Int64
        public var description: String
        public var userAgent: String
        public var language: Language
        public var generateRecurrenceToken: Bool
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
            generateRecurrenceToken: Bool = false,
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
            self.generateRecurrenceToken = generateRecurrenceToken
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
    
    struct PaymentOrderUrls : Encodable {
        public var hostUrls: [URL]
        public var completeUrl: URL
        public var cancelUrl: URL?
        public var paymentUrl: URL?
        public var callbackUrl: URL?
        public var termsOfServiceUrl: URL?
        
        public var paymentToken: String
        
        public init(
            hostUrls: [URL],
            completeUrl: URL,
            cancelUrl: URL? = nil,
            paymentUrl: URL? = nil,
            callbackUrl: URL? = nil,
            termsOfServiceUrl: URL? = nil,
            
            paymentToken: String = UUID().uuidString
        ) {
            self.hostUrls = hostUrls
            self.completeUrl = completeUrl
            self.cancelUrl = cancelUrl
            self.paymentUrl = paymentUrl
            self.callbackUrl = callbackUrl
            self.termsOfServiceUrl = termsOfServiceUrl
            
            self.paymentToken = paymentToken
        }
        
        enum CodingKeys : CodingKey {
            case hostUrls
            case completeUrl
            case cancelUrl
            case paymentUrl
            case callbackUrl
            case termsOfServiceUrl
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
        public var consumerProfileRef: String
        
        public init(consumerProfileRef: String) {
            self.consumerProfileRef = consumerProfileRef
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
    init(
        configuration: SwedbankPaySDK.Configuration,
        callbackUrl: URL? = nil,
        termsOfServiceUrl: URL? = nil,
        paymentToken: String = UUID().uuidString
    ) {
        self.init(
            configuration: configuration,
            hostUrl: configuration.backendUrl,
            callbackUrl: callbackUrl,
            termsOfServiceUrl: termsOfServiceUrl,
            paymentToken: paymentToken
        )
    }
    
    init(
        configuration: SwedbankPaySDK.Configuration,
        hostUrl: URL,
        callbackUrl: URL? = nil,
        termsOfServiceUrl: URL? = nil,
        paymentToken: String = UUID().uuidString
    ) {
        let callback = CallbackUrl.reloadPaymentMenu(token: paymentToken)
        let paymentUrl = callback.toUrl(
            prefix: configuration.callbackPrefix,
            fallbackScheme: configuration.callbackScheme
        )
        
        self.hostUrls = [hostUrl]
        self.completeUrl = URL(string: "complete", relativeTo: hostUrl)!
        self.cancelUrl = URL(string: "cancel", relativeTo: hostUrl)!
        self.paymentUrl = paymentUrl
        self.callbackUrl = callbackUrl
        self.termsOfServiceUrl = termsOfServiceUrl
        
        self.paymentToken = paymentToken
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
