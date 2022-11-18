//
//  AbortPaymentOperation.swift
//  SwedbankPaySDKMerchantBackend
//
//  Created by Olof Thorén on 2022-03-08.
//  Copyright © 2022 Swedbank. All rights reserved.
//

import Foundation
import SwedbankPaySDK

struct AbortPaymentOperation: BackendOperation {
    
    /// the relayed URL to call from the backend.
    let href: URL
    
    static func create(
        paymentInfo: SwedbankPaySDK.ViewPaymentOrderInfo
    ) -> AbortPaymentOperation? {
        
        guard let operation = paymentInfo.operations?.findOperation(rel: .abort),
              let href = operation.url
        else {
            return nil
        }
        return AbortPaymentOperation(href: href)
    }
    
    /// - returns: function that cancels this operation
    func patch(
        api: MerchantBackendApi,
        url: URL,
        abortReason: String = "CancelledByConsumer",
        userData: Any?,
        completion: @escaping (Result<PaymentOrderIn, SwedbankPaySDK.MerchantBackendError>) -> Void
    ) -> SwedbankPaySDKRequest? {
        
        let body = Body(href: href, abortReason: abortReason)
        return request(api: api, url: url, method: .patch, body: body, completion: completion) { decorator, request in
            decorator.decorateOperation(request: &request, operation: .abort, userData: userData)
        }
    }
    
    internal struct Body: Encodable {
        init(href: URL, abortReason: String) {
            
            self.href = href
            paymentorder = PaymentOrder(abortReason: abortReason)
        }
        
        private let href: URL
        private let paymentorder: PaymentOrder
        internal struct PaymentOrder: Encodable {
            let operation = "Abort"
            let abortReason: String
        }
    }
}
