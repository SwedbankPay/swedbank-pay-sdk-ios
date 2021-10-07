#if swift(>=5.5)

import Foundation
import SwedbankPaySDK

@available(iOS 15.0, *)
struct AsyncTestConfiguration: SwedbankPaySDKConfigurationAsync {
    func postConsumers(consumer: SwedbankPaySDK.Consumer?, userData: Any?) async throws -> SwedbankPaySDK.ViewConsumerIdentificationInfo {
        return SwedbankPaySDK.ViewConsumerIdentificationInfo(
            webViewBaseURL: URL(string: "about:blank")!,
            viewConsumerIdentification: URL(string: TestConstants.viewConsumerSessionLink)!
        )
    }
    
    func postPaymentorders(paymentOrder: SwedbankPaySDK.PaymentOrder?, userData: Any?, consumerProfileRef: String?) async throws -> SwedbankPaySDK.ViewPaymentOrderInfo {
        return SwedbankPaySDK.ViewPaymentOrderInfo(
            webViewBaseURL: URL(string: "about:blank")!,
            viewPaymentorder: URL(string: TestConstants.viewPaymentorderLink)!,
            completeUrl: paymentOrder!.urls.completeUrl,
            cancelUrl: paymentOrder!.urls.cancelUrl,
            paymentUrl: paymentOrder!.urls.paymentUrl,
            termsOfServiceUrl: paymentOrder!.urls.termsOfServiceUrl
        )
    }
}

#endif // swift(>=5.5)
