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
    
    func postPaymentorders(paymentOrder: SwedbankPaySDK.PaymentOrder?, userData: Any?, consumerProfileRef: String?, options: SwedbankPaySDK.VersionOptions) async throws -> SwedbankPaySDK.ViewPaymentOrderInfo {
        return SwedbankPaySDK.ViewPaymentOrderInfo(
            
            isV3: options.contains(.isV3),
            webViewBaseURL: URL(string: "about:blank")!,
            viewPaymentLink: URL(string: TestConstants.viewPaymentorderLink)!,
            completeUrl: paymentOrder!.urls.completeUrl,
            cancelUrl: paymentOrder!.urls.cancelUrl,
            paymentUrl: paymentOrder!.urls.paymentUrl,
            termsOfServiceUrl: paymentOrder!.urls.termsOfServiceUrl
        )
    }
}

#endif // swift(>=5.5)
