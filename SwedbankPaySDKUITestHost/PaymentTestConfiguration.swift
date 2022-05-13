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

let paymentTestConfigurations = [paymentTestConfigurationEnterprise, paymentTestConfigurationPaymentsOnly]
var currentConfig = paymentTestConfigurations[0]

let testPaymentOrder = SwedbankPaySDK.PaymentOrder(
    currency: "SEK",
    amount: 100,
    vatAmount: 20,
    description: "Test Purchase",
    urls: .init(configuration: currentConfig, language: .English)
)

let testPaymentOrderCheckin = SwedbankPaySDK.PaymentOrder(
    currency: "SEK",
    amount: 100,
    vatAmount: 20,
    description: "Test Purchase",
    urls: .init(configuration: currentConfig, language: .English),
    payer: .init(requireConsumerInfo: false, digitalProducts: false, shippingAddressRestrictedToCountryCodes: ["NO"], payerReference: "test payer")
)
