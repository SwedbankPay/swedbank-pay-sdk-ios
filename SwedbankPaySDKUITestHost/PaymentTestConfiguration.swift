import Foundation
import SwedbankPaySDK
import SwedbankPaySDKMerchantBackend

let paymentTestConfiguration = SwedbankPaySDK.MerchantBackendConfiguration(
    backendUrl: URL(string: "https://payex-merchant-samples.ey.r.appspot.com/")!,
    callbackScheme: "com.swedbankpay.mobilesdk.test",
    headers: [
        "x-payex-sample-apikey": "c339f53d-8a36-4ea9-9695-75048e592cc0",
        "x-payex-sample-access-token": "token123"
    ]
)

let testPaymentOrder = SwedbankPaySDK.PaymentOrder(
    currency: "SEK",
    amount: 100,
    vatAmount: 20,
    description: "Test Purchase",
    urls: .init(configuration: paymentTestConfiguration, language: .English),
    payer: .init(requireConsumerInfo: true, digitalProducts: false, shippingAddressRestrictedToCountryCodes: ["NO"])
)
