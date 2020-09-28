//
// Copyright 2020 Swedbank AB
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

let linkBaseUrlUserInfoKey = CodingUserInfoKey(rawValue: "linkBaseUrl")!

extension JSONDecoder {
    func prepareForDecodingLinks(relativeTo baseURL: URL) {
        userInfo[linkBaseUrlUserInfoKey] = baseURL
    }
}

protocol Link: Decodable {
    var href: URL { get }
    init(href: URL)
}

extension Link {
    init(from decoder: Decoder) throws {
        guard let requestUrl = decoder.userInfo[linkBaseUrlUserInfoKey] as? URL else {
            fatalError("No URL found for linkBaseUrlUserInfoKey in decoder.userInfo")
        }
        let container = try decoder.singleValueContainer()
        let link = try container.decode(String.self)
        guard let href = URL(string: link, relativeTo: requestUrl) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid URL")
        }
        self.init(href: href)
    }
}

extension Link {
    func get<T: Decodable>(
        api: MerchantBackendApi,
        completion: @escaping (Result<T, SwedbankPaySDK.MerchantBackendError>) -> Void,
        decoratorCall: @escaping MerchantBackendApi.DecoratorCall
    ) {
        // GET has nil body, but the generic request method
        // needs a type for the body argument. Ideally, this would
        // be Never?, but if we do that then we also need to
        // supply a (degenerate) implementation of Encodable
        // for Never. There should be no harm in doing so,
        // but it is also not strictly necessary. String? is fine.
        api.request(
            method: .get,
            url: href,
            body: nil as String?,
            decoratorCall: decoratorCall,
            completion: completion
        )
    }
    
    func post<B: Encodable, T: Decodable>(
        api: MerchantBackendApi,
        body: B,
        completion: @escaping (Result<T, SwedbankPaySDK.MerchantBackendError>) -> Void,
        decoratorCall: @escaping MerchantBackendApi.DecoratorCall
    ) {
        api.request(
            method: .post,
            url: href,
            body: body,
            decoratorCall: decoratorCall,
            completion: completion
        )
    }
}
