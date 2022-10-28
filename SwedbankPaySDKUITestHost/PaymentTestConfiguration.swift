import Foundation
import SwedbankPaySDK
import SwedbankPaySDKMerchantBackend

let paymentTestConfigurationPaymentsOnly = SwedbankPaySDK.MerchantBackendConfiguration(
    backendUrl: URL(string: "https://payex-merchant-samples.ey.r.appspot.com/")!,
    callbackScheme: "com.swedbankpay.mobilesdk.test",
    headers: [
        "x-payex-sample-apikey": "c339f53d-8a36-4ea9-9695-75048e592cc0",
        "x-payex-sample-access-token": "token123"
    ]
)

let paymentTestConfigurationEnterprise = SwedbankPaySDK.MerchantBackendConfiguration(
    backendUrl: URL(string: "https://enterprise-dev-dot-payex-merchant-samples.ey.r.appspot.com")!,
    callbackScheme: "com.swedbankpay.mobilesdk.test",
    headers: [
        "x-payex-sample-apikey": "c339f53d-8a36-4ea9-9695-75048e592cc0",
        "x-payex-sample-access-token": "token123"
    ]
)

enum TestConfigurations: String {
    case enterprise
    case paymentsOnly
    case nonMerchantConfig
}
var activeConfig: TestConfigurations = .paymentsOnly

let paymentTestConfigurations: [TestConfigurations: SwedbankPaySDK.MerchantBackendConfiguration] = [.enterprise: paymentTestConfigurationEnterprise, .paymentsOnly: paymentTestConfigurationPaymentsOnly]
var currentConfig = paymentTestConfigurationPaymentsOnly

let testPaymentOrder = SwedbankPaySDK.PaymentOrder(
    currency: "SEK",
    amount: 200,
    vatAmount: 50,
    description: "Test Purchase",
    urls: .init(configuration: currentConfig, language: .English)
)

let testPaymentOrderCheckin = SwedbankPaySDK.PaymentOrder(
    currency: "SEK",
    amount: 200,
    vatAmount: 50,
    description: "Test Purchase",
    urls: .init(configuration: currentConfig, language: .English),
    payer: .init(requireConsumerInfo: false, digitalProducts: false, shippingAddressRestrictedToCountryCodes: ["NO"], payerReference: "test payer")
)

// MARK: Allowing tests for a non-MerchantBackendConfiguration

let testNonMerchantPaymentOrder = SwedbankPaySDK.PaymentOrder(
    currency: "SEK",
    amount: 200,
    vatAmount: 50,
    description: "Test Purchase",
    urls: .init(hostUrls: [Constants.webViewaseUrl], completeUrl: Constants.completeUrl, cancelUrl: Constants.cancelUrl, paymentUrl: Constants.paymentUrl)
)

enum SwedbankPayConfigurationError: Error {
    case notImplemented
}
struct Constants {
    static let webViewaseUrl = URL(string: "https://www.nonMerchantConfig.se")!
    static let completeUrl = URL(string: "nonMerchantConfig-test://complete-payment")!
    static let cancelUrl = URL(string: "nonMerchantConfig-test://cancel-payment")
    static let paymentUrl = URL(string: "nonMerchantConfig-test://payment")
}

class SwedbankPayConfiguration {
    let orderInfo: SwedbankPaySDK.ViewPaymentOrderInfo
    
    init(viewPaymentLink: URL) {
        self.orderInfo = SwedbankPaySDK.ViewPaymentOrderInfo(
            isV3: true,
            webViewBaseURL: Constants.webViewaseUrl,
            viewPaymentLink: viewPaymentLink,
            completeUrl: Constants.completeUrl,
            cancelUrl: Constants.cancelUrl,
            paymentUrl: Constants.paymentUrl,
            termsOfServiceUrl: nil
        )
    }
}


extension SwedbankPayConfiguration: SwedbankPaySDKConfiguration {
    
    // This delegate method is not used but required
    func postConsumers(consumer: SwedbankPaySDK.Consumer?, userData: Any?, completion: @escaping (Result<SwedbankPaySDK.ViewConsumerIdentificationInfo, Error>) -> Void) {
        completion(.failure(SwedbankPayConfigurationError.notImplemented))
    }
    
    func postPaymentorders(paymentOrder: SwedbankPaySDK.PaymentOrder?, userData: Any?, consumerProfileRef: String?, options: SwedbankPaySDK.VersionOptions, completion: @escaping (Result<SwedbankPaySDK.ViewPaymentOrderInfo, Error>) -> Void) {
        completion(.success(orderInfo))
    }
    
}
