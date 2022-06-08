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
