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
        var operation: PaymentOrderOperation
        var currency: String
        var amount: Int64
        var vatAmount: Int64
        var description: String
        var userAgent: String
        var language: Language
        var generateRecurrenceToken: Bool
        var urls: PaymentOrderUrls
        var payeeInfo: PayeeInfo
        var payer: PaymentOrderPayer?
        var orderItems: [OrderItem]?
        var riskIndicator: RiskIndicator?
        
        public init(
            operation: PaymentOrderOperation = .Purchase,
            currency: String,
            amount: Int64,
            vatAmount: Int64,
            description: String,
            userAgent: String = defaultUserAgent,
            language: Language = .English,
            generateRecurrenceToken: Bool = false,
            urls: PaymentOrderUrls,
            payeeInfo: PayeeInfo = .init(),
            payer: PaymentOrderPayer? = nil,
            orderItems: [OrderItem]? = nil,
            riskIndicator: RiskIndicator? = nil
        ) {
            self.operation = operation
            self.currency = currency
            self.amount = amount
            self.vatAmount = vatAmount
            self.description = description
            self.userAgent = userAgent
            self.language = language
            self.generateRecurrenceToken = generateRecurrenceToken
            self.urls = urls
            self.payeeInfo = payeeInfo
            self.payer = payer
            self.orderItems = orderItems
            self.riskIndicator = riskIndicator
        }
    }
    
    enum PaymentOrderOperation : String, Codable {
        case Purchase
        case Verify
    }
    
    struct PaymentOrderUrls : Encodable {
        var hostUrls: [URL]
        var completeUrl: URL
        var cancelUrl: URL?
        var paymentUrl: URL?
        var callbackUrl: URL?
        var termsOfServiceUrl: URL?
        
        var paymentToken: String
        
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
        var payeeId: String
        var payeeReference: String
        var payeeName: String?
        var productCategory: String?
        var orderReference: String?
        var subsite: String?
        
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
        var consumerProfileRef: String
        
        public init(consumerProfileRef: String) {
            self.consumerProfileRef = consumerProfileRef
        }
    }
    
    struct OrderItem : Codable {
        var reference: String
        var name: String
        var type: ItemType
        var `class`: String
        var itemUrl: URL?
        var imageUrl: URL?
        var description: String?
        var discountDescription: String?
        var quantity: Int
        var quantityUnit: String
        var unitPrice: Int64
        var discountPrice: Int64
        var vatPercent: Int
        var amount: Int64
        var vatAmount: Int64
        
        public init(
            reference: String,
            name: String,
            type: ItemType,
            class: String,
            itemUrl: URL?,
            imageUrl: URL?,
            description: String?,
            discountDescription: String?,
            quantity: Int,
            quantityUnit: String,
            unitPrice: Int64,
            discountPrice: Int64,
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
        var deliveryEmailAddress: String?
        var deliveryTimeFrameIndicator: DeliveryTimeFrameIndicator?
        var preOrderDate: String?
        var preOrderPurchaseIndicator: PurchaseIndicator?
        var shipIndicator: ShipIndicator.Raw?
        var pickUpAddress: PickUpAddress?
        var giftCardPurchase: Bool?
        var reOrderPurchaseIndicator: PurchaseIndicator?
        
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
        var name: String?
        var streetAddress: String?
        var coAddress: String?
        var city: String?
        var zipCode: String?
        var countryCode: String?
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
