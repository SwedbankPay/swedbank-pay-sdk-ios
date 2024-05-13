//
// Copyright 2024 Swedbank AB
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

protocol EndpointRouterProtocol {
    var body: [String: Any?]? { get }
}

struct SwedbankPayAPIEnpointRouter: EndpointRouterProtocol {
    let model: OperationOutputModel

    var body: [String: Any?]? {
        return nil
    }
}

extension SwedbankPayAPIEnpointRouter {
    func makeRequest(handler: @escaping (Result<Void, Error>) -> Void) {
        requestWithDataResponse { result in
            switch result {
            case .success:
                handler(.success(()))
            case .failure(let error):
                handler(.failure(error))
            }
        }
    }

    private func requestWithDataResponse(handler: @escaping (Result<Data, Error>) -> Void) {
        guard let href = model.href,
              var components = URLComponents(string: href) else {
            handler(.failure(SwedbankPayAPIError.invalidUrl))
            return
        }

        if components.scheme == "http" {
            components.scheme = "https"
        }

        guard let url = components.url else {
            handler(.failure(SwedbankPayAPIError.invalidUrl))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = model.method
        request.allHTTPHeaderFields = SwedbankPayAPIConstants.commonHeaders

        if let body = body, let jsonData = try? JSONSerialization.data(withJSONObject: body) {
            request.httpBody = jsonData
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let response = response as? HTTPURLResponse, 200...299 ~= response.statusCode else {
                handler(.failure(error ?? SwedbankPayAPIError.unknown))
                return
            }

            guard let data else {
                handler(.failure(error ?? SwedbankPayAPIError.unknown))
                return
            }

            handler(.success(data))
        }.resume()
    }
}
