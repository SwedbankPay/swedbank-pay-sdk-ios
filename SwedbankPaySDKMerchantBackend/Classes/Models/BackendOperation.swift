//
//  BackendOperation.swift
//  SwedbankPaySDKMerchantBackend
//
//  Created by Olof Thorén on 2022-03-08.
//  Copyright © 2022 Swedbank. All rights reserved.
//

import Foundation
import SwedbankPaySDK
import Alamofire

protocol BackendOperation {
    
    var href: URL { get }
    init(href: URL)
}

extension BackendOperation {
    
    /// A general request
    func request<B: Encodable, T: Decodable>(
        api: MerchantBackendApi,
        url: URL,
        method: HTTPMethod,
        body: B,
        completion: @escaping (Result<T, SwedbankPaySDK.MerchantBackendError>) -> Void,
        decoratorCall: @escaping MerchantBackendApi.DecoratorCall
    ) -> SwedbankPaySDKRequest? {
        return api.request(
            method: method,
            url: url,
            body: body,
            decoratorCall: decoratorCall,
            completion: completion
        )
    }
}
