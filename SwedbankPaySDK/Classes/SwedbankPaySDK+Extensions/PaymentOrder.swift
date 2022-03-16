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
    
    /// Description of a payment order to be created
    ///
    /// This type mirrors the fields used in the `POST /psp/paymentorders` request
    /// (`https://developer.swedbankpay.com/checkout/other-features#creating-a-payment-order`).
    /// `PaymentOrder` is designed to work with `SwedbankPaySDK.MerchantBackendConfiguration`
    /// and a server implementing the Merchant Backend API, such as the example backends
    /// provided by Swedbank Pay, but it can be useful when using a  custom
    /// `SwedbankPaySDKConfiguration` as well.
    struct PaymentOrder : Codable, Equatable {
        /// The operation to perform
        public var operation: PaymentOrderOperation
        
        /// Whether to use v3 or v2, it must contain "Checkout3"
        public var productName: String?
        
        /// Shortcut to know if this is v3 or not
        public var isV3: Bool {
            get {
                return productName != PaymentOrder.checkout3
            }
            set (value) {
                productName = value ? PaymentOrder.checkout3 : nil
            }
        }
        
        /// Constant for the productName when using version 3
        static let checkout3 = "Checkout3"
        
        /// Currency to use
        public var currency: String
        
        /// Payment amount, including VAT
        ///
        /// Denoted in the smallest monetary unit applicable, typically 1/100.
        /// E.g. 50.00 SEK would be represented as `5000`.
        public var amount: Int64
        
        /// Amount of VAT included in the payment
        ///
        /// Denoted in the smallest monetary unit applicable, typically 1/100.
        /// E.g. 50.00 SEK would be represented as `5000`.
        public var vatAmount: Int64
        
        /// A description of the payment order
        public var description: String
        
        /// User-agent of the payer.
        ///
        /// Defaults to `"SwedbankPaySDK-iOS/{version}"`.
        public var userAgent: String
        
        /// Language to use in the payment menu
        public var language: Language
        
        /// The payment instrument to use in instrument mode.
        public var instrument: Instrument?
        
        /// If `true`, a recurrence token will be created from this payment order
        ///
        /// The recurrence token should be retrieved by your server from Swedbank Pay.
        /// Your server can then use the token for recurring server-to-server payments.
        public var generateRecurrenceToken: Bool
        
        /// If `true`, a unscheduled token will be created from this payment order
        ///
        /// The unscheduled token should be retrieved by your server from Swedbank Pay.
        /// Your server can then use the token for unscheduled server-to-server payments.
        public var generateUnscheduledToken: Bool
        
        /// If `true`, a payment token will be created from this payment order
        ///
        /// You must also set `payer.payerReference` to generate a payment token.
        /// The payment token can be used later to reuse the same payment details;
        /// see `paymentToken`.
        public var generatePaymentToken: Bool
        
        /// If `true`, the payment menu will not show any stored payment details.
        ///
        /// This is useful mainly if you are implementing a custom UI for stored
        /// payment details.
        public var disableStoredPaymentDetails: Bool
        
        /// If set, only shows the specified payment instruments in the payment menu
        public var restrictedToInstruments: [String]?
        
        /// A set of URLs related to the payment.
        ///
        /// See `SwedbankPaySDK.PaymentOrderUrls` for details.
        public var urls: PaymentOrderUrls
        
        /// Information about the payee (recipient)
        ///
        /// See `SwedbankPaySDK.PayeeInfo` for details.
        public var payeeInfo: PayeeInfo
        
        /// Information about the payer
        ///
        /// See `SwedbankPaySDK.PaymentOrderPayer` for details.
        public var payer: PaymentOrderPayer?
        
        /// A list of items that are being paid for by this payment order.
        ///
        /// The sum of the items' `amount` and `vatAmount` should match
        /// the `amount` and `vatAmount` of the payment order.
        public var orderItems: [OrderItem]?
        
        /// A collection of additional data to minimize the risk of 3-D Secure strong authentication.
        ///
        /// For best user experience, you should fill this field as completely as possible.
        public var riskIndicator: RiskIndicator?
        
        public var disablePaymentMenu: Bool
        
        /// A payment token to use for this payment.
        ///
        /// You must also set `payer.payerReference` to use a payment token;
        /// the `payerReference` must match the one used when the payment token
        /// was generated.
        public var paymentToken: String?
        
        public var initiatingSystemUserAgent: String?
        
        public init(
            operation: PaymentOrderOperation = .Purchase,
            isV3: Bool = false,
            currency: String,
            amount: Int64,
            vatAmount: Int64,
            description: String,
            userAgent: String = defaultUserAgent,
            language: Language = .English,
            instrument: Instrument? = nil,
            generateRecurrenceToken: Bool = false,
            generateUnscheduledToken: Bool = false,
            generatePaymentToken: Bool = false,
            disableStoredPaymentDetails: Bool = false,
            restrictedToInstruments: [String]? = nil,
            urls: PaymentOrderUrls,
            payeeInfo: PayeeInfo = .init(),
            payer: PaymentOrderPayer? = nil,
            orderItems: [OrderItem]? = nil,
            riskIndicator: RiskIndicator? = nil,
            disablePaymentMenu: Bool = false,
            paymentToken: String? = nil,
            initiatingSystemUserAgent: String? = nil
        ) {
            self.operation = operation
            self.productName = isV3 ? PaymentOrder.checkout3 : nil
            self.currency = currency
            self.amount = amount
            self.vatAmount = vatAmount
            self.description = description
            self.userAgent = userAgent
            self.language = language
            self.instrument = instrument
            self.generateRecurrenceToken = generateRecurrenceToken
            self.generateUnscheduledToken = generateUnscheduledToken
            self.generatePaymentToken = generatePaymentToken
            self.disableStoredPaymentDetails = disableStoredPaymentDetails
            self.restrictedToInstruments = restrictedToInstruments
            self.urls = urls
            self.payeeInfo = payeeInfo
            self.payer = payer
            self.orderItems = orderItems
            self.riskIndicator = riskIndicator
            self.disablePaymentMenu = disablePaymentMenu
            self.paymentToken = paymentToken
            self.initiatingSystemUserAgent = initiatingSystemUserAgent
        }
    }
    
    /// Type of operation the payment order performs
    enum PaymentOrderOperation : String, Codable {
        /// A purchase, i.e. a single payment
        case Purchase
        
        /// Pre-verification of a payment method. This operation will not charge the payment method,
        /// but it can create a token for future payments.
        ///
        /// See `PaymentOrder.generateRecurrenceToken`, `PaymentOrder.generateUnscheduledToken`, `PaymentOrder.generatePaymentToken`
        case Verify
    }
    
    /// A set of URLs relevant to a payment order.
    ///
    /// The Mobile SDK places some requirements on these URLs,  different to the web-page case.
    /// See individual properties for discussion.
    struct PaymentOrderUrls : Codable, Equatable {
        /// Array of URLs that are valid for embedding this payment order.
        ///
        /// The SDK generates the web page that embeds the payment order internally, so it is not really
        /// hosted anywhere. However, the WebView will use the value returned in
        /// `ViewPaymentOrderInfo.webViewBaseUrl` as the url of that generated page. Therefore,
        /// the `webViewBaseUrl` you use should match `hostUrls` here.
        public var hostUrls: [URL]
        /// The URL that the payment menu will redirect to when the payment is complete.
        ///
        /// The SDK will capture the navigation before it happens; the `completeUrl` will never be
        /// actually loaded in the WebView. Thus, the only requirement for this URL is that is is
        /// formally valid.
        public var completeUrl: URL
        /// The URL that the payment menu will redirect to when the payment is canceled.
        ///
        /// The SDK will capture the navigation before it happens; i.e. this works similarly to how
        /// `completeUrl` does.
        public var cancelUrl: URL?
        /// A URL that will be navigated to when the payment menu needs to be reloaded.
        ///
        /// The `paymentUrl` is used to get back to the payment menu after some third-party process
        /// related to the payment is completed. As long as the process stays within the SDK controlled
        /// WebView, we can intercept the navigation, like `completeUrl` , and reload the payment menu.
        /// However, because those processes may involve opening other applications, we must also be
        /// prepared for `paymentUrl` being opened from those third-party applications. In particular,
        /// we must be prepared for `paymentUrl` being opened in Safari.
        ///
        /// The have `paymentUrl` handed over to the SDK, it must be a Universal Link registered to your
        /// application. With Univeral Links correctly configured, the `paymentUrl` should be routed
        /// to your application, and you will receive it in your
        /// `UIApplicationDelegate.application(_:continue:restorationHandler:)` method. From there,
        /// you must forward it to the SDK by calling `SwedbankPaySDK.continue(userActivity:)`.
        ///
        /// In some cases the `paymentUrl` will be opened in Safari instead, despite correct
        /// Universal Links configuration. To handle this situation you have the option of
        /// attempting to retrigger the Univeral Links routing by redirecting the from `paymentUrl`
        /// to a different domain, with a link back to `paymentUrl`. Please refer to the documentation
        /// in the Swedbank Pay Developer Portal for further discussion of the mechanics involved.
        /// To facilitate the backend part of this system, the SDK will also accept URLs that
        /// have additional query parameters added to the original `paymentUrl`.
        ///
        /// As a final fallback, you may invoke a URL with a custom scheme registered to your
        /// application. In addition to changing the scheme, that URL may also add query parameters,
        /// but should be otherwise equal to the original `paymentUrl`. When you receive such a URL
        /// in your `UIApplicationDelegate.application(_:open:options:)` method, forward it to
        /// the SDK by calling `SwedbankPaySDK.open(url:)`.
        ///
        /// For advanced use-cases, you can customize the URL-matching behaviour described above
        /// in your `SwedbankPayConfiguration.`
        ///
        /// Each `paymentUrl` you create should be unique inside your application.
        public var paymentUrl: URL?
        /// A URL on your server that receives status callbacks related to the payment.
        ///
        /// The SDK does not interact with this server-to-server URL and as such places no
        /// requirements on it.
        public var callbackUrl: URL?
        /// A URL to your Terms of Service.
        ///
        /// By default, pressing the Terms of Service link present a view controller that
        /// loads this URL in a `WKWebView`. You can override this behaviour through
        /// `SwedbankPaySDKDelegate.overrideTermsOfServiceTapped(url:)`.
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
    
    /// Information about the payee (recipient) of a payment order
    struct PayeeInfo : Codable, Equatable {
        /// The unique identifier of this payee set by Swedbank Pay.
        ///
        /// This is usually the Merchant ID. However, usually best idea to set this value in your backend
        /// instead. Thus, this property defaults to the empty string, but it is included in the data
        /// model for completeness.
        public var payeeId: String
        
        /// A unique reference for this operation.
        ///
        /// See `https://developer.swedbankpay.com/checkout/other-features#payee-reference`
        ///
        /// Like `payeeId`, this is usually best to set in your backend, and this property thus defaults
        /// to the empty string.
        public var payeeReference: String
        
        /// Name of the payee, usually the name of the merchant.
        public var payeeName: String?
        
        /// A product category or number sent in from the payee/merchant.
        ///
        /// This is not validated by Swedbank Pay, but will be passed through the payment process and may
        /// be used in the settlement process.
        public var productCategory: String?
        
        /// A reference to your own merchant system.
        public var orderReference: String?
        
        /// Used for split settlement.
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
    
    /// Information about the payer of a payment order
    /// V3: Bounds on the consumer profile we want to obtain through the Checkin flow.
    struct PaymentOrderPayer : Codable, Equatable {
        /// Set to true by merchants who want to receive profile information from Swedbank Pay. This applies both when the merchant needs email and/or msisdn for digital goods, and when full shipping address is needed. If set to false, Swedbank Pay will depend on the merchant to send the email and/or msisdn for digital products, and also the shipping address if the order is shipped.
        public var requireConsumerInfo: Bool?
        
        /// Set to true for merchants who only sell digital goods and only require email and/or msisdn as shipping details. Set to false if the merchant also sells physical goods.
        public var digitalProducts: Bool?
        
        /// List of supported shipping countries for merchant. Using [ISO-3166] standard, e.g: [ "NO", "US", "SE" ]
        public var shippingAddressRestrictedToCountryCodes: [String]?
        
        // NOTE: All below is V2 only and will be removed
        
        /// A consumer profile reference obtained through the Checkin flow. Note that everything regarding V2 will be removed.
        ///
        /// If you have your `SwedbankPaySDKController` to do the Checkin flow, your
        /// `SwedbankPaySDKConfiguration.postPaymentorders` will be called with
        /// the `consumerProfileRef` received from the Checkin flow. Your
        /// `SwedbankPaySDKConfiguration` can then use that value here to forward it
        /// to your backend for payment order creation.
        public var consumerProfileRef: String?
        
        /// The email address of the payer.
        ///
        /// Can be used even if you do not set a `consumerProfileRef`; will be used to prefill
        /// appropriate fields.
        public var email: String?
        
        /// The phone number of the payer.
        ///
        /// Can be used even if you do not set a `consumerProfileRef`; will be used to prefill
        /// appropriate fields.
        public var msisdn: String?
        
        /// An opaque, unique reference to the payer. Alternative to the other fields.
        ///
        /// Using `payerReference` is required when generating or using payment tokens
        /// (N.B! not recurrence tokens).
        ///
        /// If you use `payerReference`, you should not set the other fields.
        /// The `payerReference` must be unique to a payer, and your backend must have access control
        /// such that is ensures that the `payerReference` is owned by the authenticated user.
        /// It is usually best to only populate this field in the backend.
        public var payerReference: String?
         
        public init(
            consumerProfileRef: String? = nil,
            email: String? = nil,
            msisdn: String? = nil,
            payerReference: String? = nil
        ) {
            self.consumerProfileRef = consumerProfileRef
            self.email = email
            self.msisdn = msisdn
            self.payerReference = payerReference
        }
        
        public init(
            requireConsumerInfo: Bool? = nil,
            digitalProducts: Bool? = nil,
            shippingAddressRestrictedToCountryCodes: [String]? = nil,
            payerReference: String? = nil
        ) {
            self.consumerProfileRef = nil
            self.requireConsumerInfo = requireConsumerInfo
            self.digitalProducts = digitalProducts
            self.shippingAddressRestrictedToCountryCodes = shippingAddressRestrictedToCountryCodes
            self.payerReference = payerReference
        }
    }

    /// An item being paid for, part of a `PaymentOrder`.
    ///
    /// OrderItems are an optional, but recommended, part of `PaymentOrder`s.
    /// To use them, create an `OrderItem` for each distinct item the payment order
    /// is for: e.g. if the consumer is paying for one Thingamajig and two
    /// Watchamacallits, which will be shipped to the consumer's address,
    /// you would create three `OrderItem`s: one for the lone Thingamajig,
    /// one for the two Watchamacallits, and one for the shipping fee.
    ///
    /// When using `OrderItem`s, make sure that the sum of the `OrderItem`s'
    /// `amount` and `vatAmount` are equal to the `PaymentOrder`'s `amount`
    /// and `vatAmount` properties, respectively.
    struct OrderItem : Codable, Equatable {
        /// A reference that identifies the item in your own systems.
        public var reference: String
        /// Name of the item
        public var name: String
        /// Type of the item
        public var type: ItemType
        /// A classification of the item. Must not contain spaces.
        ///
        /// Can be used for assigning the order item to a specific product category,
        /// such as `"MobilePhone"`.
        ///
        /// Swedbank Pay may use this field for statistics.
        public var `class`: String
        /// URL of a web page that contains information about the item
        public var itemUrl: URL?
        /// URL to an image of the item
        public var imageUrl: URL?
        /// Human-friendly description of the item
        public var description: String?
        /// Human-friendly description of the discount on the item, if applicable
        public var discountDescription: String?
        /// Quantity of the item being purchased
        public var quantity: Int
        /// Unit of the quantity
        ///
        /// E.g. `"pcs"`, `"grams"`
        public var quantityUnit: String
        /// Price of a single unit, including VAT.
        public var unitPrice: Int64
        /// The discounted price of the item, if applicable
        public var discountPrice: Int64?
        /// The VAT percent value, multiplied by 100.
        ///
        /// E.g. 25% would be represented as `2500`.
        public var vatPercent: Int
        /// The total amount, including VAT, paid for the specified quantity of the item.
        ///
        /// Denoted in the smallest monetary unit applicable, typically 1/100.
        /// E.g. 50.00 SEK would be represented as `5000`.
        public var amount: Int64
        /// The total amount of VAT paid for the specified quantity of the item.
        ///
        /// Denoted in the smallest monetary unit applicable, typically 1/100.
        /// E.g. 50.00 SEK would be represented as `5000`.
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
    
    /// Optional information to reduce the risk factor of a payment.
    ///
    /// You should populate this data as completely as possible to decrease the likelihood of 3-D Secure
    /// Strong Authentication.
    struct RiskIndicator : Codable, Equatable {
        /// For electronic delivery, the e-mail address where the merchandise is delivered
        public var deliveryEmailAddress: String?
        /// Indicator of merchandise delivery timeframe.
        public var deliveryTimeFrameIndicator: DeliveryTimeFrameIndicator?
        /// If this is a pre-order, the expected date that the merchandise will be available on.
        ///
        /// Format is `YYYYMMDD`. The initializer formats a `DateComponents` value to the correct
        /// format for this field.
        public var preOrderDate: String?
        /// Indicates whether this is a pre-order.
        public var preOrderPurchaseIndicator: PreOrderPurchaseIndicator?
        /// Indicates the shipping method for this order.
        ///
        /// Values are according to the Swedbank Pay documentation;
        /// see `https://developer.swedbankpay.com/checkout/payment-menu#request`.
        /// The initializer takes a  a [SwedbankPaySDK.ShipIndicator] argument, which
        /// models the different options in a Swift-native way.
        public var shipIndicator: ShipIndicator.Raw?
        /// If `shipIndicator` is `"04"`, i.e. `.PickUpAtStore`,
        /// this field should be populated.
        ///
        /// The initializer takes care of setting this field correctly according
        /// to the passed-in `SwedbankPaySDK.ShipIndicator`.
        public var pickUpAddress: PickUpAddress?
        /// `true` if this is a purchase of a gift card
        public var giftCardPurchase: Bool?
        /// Indicates whether this is a re-order of previously purchased merchandise.
        public var reOrderPurchaseIndicator: ReOrderPurchaseIndicator?
        
        public init(
            deliveryEmailAddress: String? = nil,
            deliveryTimeFrameIndicator: SwedbankPaySDK.DeliveryTimeFrameIndicator? = nil,
            preOrderDate: DateComponents? = nil,
            preOrderPurchaseIndicator: SwedbankPaySDK.PreOrderPurchaseIndicator? = nil,
            shipIndicator: SwedbankPaySDK.ShipIndicator? = nil,
            giftCardPurchase: Bool? = nil,
            reOrderPurchaseIndicator: SwedbankPaySDK.ReOrderPurchaseIndicator? = nil
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
    
    /// Product delivery timeframe for a `SwedbankPaySDK.RiskIndicator`.
    enum DeliveryTimeFrameIndicator : String, Codable {
        /// Product is delivered electronically; no physical shipping.
        case ElectronicDelivery = "01"
        
        /// Product is delivered on the same day.
        case SameDayShipping = "02"
        
        /// Product is delivered on the next day.
        case OvernightShipping = "03"
        
        /// Product is delivered in two days or later.
        case TwoDayOrMoreShipping = "04"
    }
    
    /// Pre-order purchase indicator values for `SwedbankPaySDK.RiskIndicator`
    enum PreOrderPurchaseIndicator : String, Codable {
        /// Merchandise available now
        case MerchandiseAvailable = "01"
        
        /// Merchandise will be available in the future
        case FutureAvailability = "02"
    }
    
    /// Re-order purchase indicator values for `SwedbankPaySDK.RiskIndicator`
    enum ReOrderPurchaseIndicator : String, Codable {
        /// First purchase of this merchandise
        case FirstTimeOrdered = "01"
        
        /// Re-order of previously purchased merchandise
        case Reordered = "02"
    }
    
    /// Shipping method for `SwedbankPaySDK.RiskIndicator`
    enum ShipIndicator {
        /// Ship to cardholder's billing address
        case ShipToBillingAddress
        /// Ship to another verified address on file with the merchant
        case ShipToVerifiedAddress
        /// Ship to an address different to the cardholder's billing address
        case ShipToDifferentAddress
        /// Ship to store/pick-up at store. Populate the pick-up address as completely as possible.
        case PickUpAtStore(pickUpAddress: PickUpAddress)
        /// Digital goods, no physical delivery
        case DigitalGoods
        /// Travel and event tickets, no shipping
        case Tickets
        /// Other, e.g. gaming, digital service
        case Other
    }
    
    /// Pick-up address data for `SwedbankPaySDK.RiskIndicator`
    ///
    /// When using `ShipIndicator.PickUpAtStore`, you should populate this data as completely as
    /// possible to decrease the risk factor of the purchase.
    struct PickUpAddress : Codable, Equatable {
        /// Name of the payer
        public var name: String?
        /// Street address of the payer
        public var streetAddress: String?
        /// C/O address of the payer
        public var coAddress: String?
        /// City of the payer
        public var city: String?
        /// Zip code of the payer
        public var zipCode: String?
        /// Country code of the payer
        public var countryCode: String?
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
