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
import Alamofire

struct MerchantBackendApi {
    typealias DecoratorCall = (
        SwedbankPaySDKRequestDecorator,
        inout URLRequest
    ) -> Void
    
    var session: Session
    var domainWhitelist: [SwedbankPaySDK.WhitelistedDomain]
    var requestDecorator: SwedbankPaySDKRequestDecorator?
    
    func request<B: Encodable, T: Decodable>(
        method: HTTPMethod,
        url: URL,
        body: B?,
        decoratorCall: @escaping DecoratorCall,
        completion: @escaping (Result<T, SwedbankPaySDK.MerchantBackendError>) -> Void
    ) {
        do {
            let request = try buildRequest(
                method: method, url: url, body: body, decoratorCall: decoratorCall
            )
            perform(request: request, completion: completion)
        } catch let error {
            let merchantBackendError = error as? SwedbankPaySDK.MerchantBackendError
                ?? .networkError(error)
            DispatchQueue.main.async {
                completion(.failure(merchantBackendError))
            }
        }
    }
    
    private func buildRequest<B: Encodable>(
        method: HTTPMethod,
        url: URL,
        body: B?,
        decoratorCall: @escaping DecoratorCall
    ) throws -> DataRequest {
        guard isDomainWhitelisted(url) else {
            throw SwedbankPaySDK.MerchantBackendError.nonWhitelistedDomain(
                failingUrl: url
            )
        }
        let interceptor = requestDecorator.map {
            RequestDecoratorInterceptor.init(
                requestDecorator: $0,
                decoratorCall: decoratorCall
            )
        }
        return session.request(
            url,
            method: method,
            parameters: body,
            encoder: JSONParameterEncoder.default,
            interceptor: interceptor
        )
    }
    
    private func isDomainWhitelisted(_ url: URL) -> Bool {
        if let host = url.host {
            for whitelistObj in domainWhitelist {
                if whitelistObj.includeSubdomains {
                    if let domain = whitelistObj.domain, host == domain || host.hasSuffix(".\(domain)") {
                        return true
                    }
                } else {
                    if whitelistObj.domain == host {
                        return true
                    }
                }
            }
        }
        return false
    }
    
    private struct RequestDecoratorInterceptor: RequestInterceptor {
        let requestDecorator: SwedbankPaySDKRequestDecorator
        let decoratorCall: DecoratorCall
        
        func adapt(
            _ urlRequest: URLRequest,
            for session: Session,
            completion: @escaping (Result<URLRequest, Error>) -> Void
        ) {
            var request = urlRequest
            DispatchQueue.main.async {
                requestDecorator.decorateAny(request: &request)
                decoratorCall(requestDecorator, &request)
                completion(.success(request))
            }
        }
    }
    
    private func perform<T: Decodable>(
        request: DataRequest,
        completion: @escaping (Result<T, SwedbankPaySDK.MerchantBackendError>) -> Void
    ) {
        request.responseData(queue: .global(qos: .userInitiated)) { response in
            let result: Result<T, SwedbankPaySDK.MerchantBackendError>
            do {
                try checkError(response: response)
                result = .success(try parse(response: response))
            } catch let error {
                let merchantBackendError = error as? SwedbankPaySDK.MerchantBackendError
                    ?? .networkError(error)
                result = .failure(merchantBackendError)
            }
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
    
    private func checkError(response: AFDataResponse<Data>) throws {
        if let code = response.response?.statusCode, (400...599).contains(code) {
            throw SwedbankPaySDK.MerchantBackendError.problem(
                getProblem(response: response)
            )
        }
    }
    
    private func checkContentType(
        _ response: AFDataResponse<Data>,
        _ expectedContentType: String
    ) throws {
        let contentType = try requireSome(response.response?.mimeType)
        let separatorIndex = contentType.firstIndex(of: ";") ?? contentType.endIndex
        try require(contentType[..<separatorIndex] == expectedContentType)
    }
    
    private func getProblem(response: AFDataResponse<Data>) -> SwedbankPaySDK.Problem {
        do {
            try checkContentType(response, "application/problem+json")
            return Problems.parseProblem(response: response)
        } catch {
            return Problems.makeUnexpectedContentProblem(response: response)
        }
    }
    
    private func parse<T: Decodable>(response: AFDataResponse<Data>) throws -> T {
        let data = try response.result.get() // any network error will be thrown out of here
        
        do {
            try checkContentType(response, "application/json")
            let decoder = JSONDecoder()
            if let url = response.request?.url {
                decoder.prepareForDecodingLinks(relativeTo: url)
            }
            return try decoder.decode(T.self, from: data)
        } catch {
            throw SwedbankPaySDK.MerchantBackendError.problem(
                Problems.makeUnexpectedContentProblem(response: response)
            )
        }
    }
}
