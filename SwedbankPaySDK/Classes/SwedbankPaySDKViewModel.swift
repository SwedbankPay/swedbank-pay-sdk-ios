//
// Copyright 2019 Swedbank AB
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

import Alamofire

private extension SwedbankPaySDK.Configuration {
    var afHeaders: HTTPHeaders? {
        return headers.map(HTTPHeaders.init)
    }
}

final class SwedbankPaySDKViewModel: NSObject {
    
    static var overrideUrlSessionConfigurationForTests: URLSessionConfiguration?
    
    private(set) var configuration: SwedbankPaySDK.Configuration?
    private(set) var consumerData: SwedbankPaySDK.Consumer?
    private(set) var paymentOrder: SwedbankPaySDK.PaymentOrder?
    private(set) var consumerProfileRef: String?
        
    var sessionManager: Session = Alamofire.Session(
        configuration: overrideUrlSessionConfigurationForTests ?? URLSessionConfiguration.default
    )
    
    var viewPaymentOrderLink: String?
    
    /// Sets the `SwedbankPaySDK.Configuration`
    /// - parameter configuration: Configuration to be set
    func setConfiguration(_ configuration: SwedbankPaySDK.Configuration) {
        self.configuration = configuration
        
        /// If `configuration.domainWhitelist` is nil or empty, add backendUrl as whitelisted domain
        let list = self.configuration?.domainWhitelist
        if list == nil || list?.isEmpty == true {
            if let backendUrl = self.configuration?.backendUrl {
                let host = backendUrl.host
                let domain = SwedbankPaySDK.WhitelistedDomain.init(
                    domain: host,
                    includeSubdomains: true
                )
                self.configuration?.domainWhitelist = [domain]
            }
        }
        
        /// If `configuration.pinCertificates` is not empty, pin certificates found in Bundle
        if let pinPublicKeys = self.configuration?.pinPublicKeys, !pinPublicKeys.isEmpty {
            var pinEvaluators: [String: PublicKeysTrustEvaluator] = [:]
            for certificate in pinPublicKeys {
                pinEvaluators[certificate.pattern] = PublicKeysTrustEvaluator(
                    keys: certificate.publicKeys,
                    performDefaultValidation: true,
                    validateHost: true
                )
            }
            sessionManager = Alamofire.Session(
                configuration: URLSessionConfiguration.default,
                serverTrustManager: ServerTrustManager(
                    evaluators: pinEvaluators
                )
            )
        }
    }
    
    /// Sets the `SwedbankPaySDK.Consumer`
    /// - parameter consumerData: consumerData to set
    func setConsumerData(_ consumerData: SwedbankPaySDK.Consumer?) {
        self.consumerData = consumerData
    }
    
    /// Sets the `SwedbankPaySDK.PaymentOrder`
    /// - parameter paymentOrder: paymentOrder to set
    func setPaymentOrder(_ paymentOrder: SwedbankPaySDK.PaymentOrder) {
        self.paymentOrder = paymentOrder
    }
    
    /// Sets the `consumerProfileRef`
    /// - parameter ref: consumerProfileRef to set
    func setConsumerProfileRef(_ ref: String?) {
        self.consumerProfileRef = ref
    }
    
    /// Check if the request is being made to a whitelisted domain
    /// - parameter url: request URL as a String to check
    /// - returns: Boolean idicating was the domain whitelisted or not
    func isDomainWhitelisted(_ url: URL) -> Bool {
        if let host = url.host, let whitelist = configuration?.domainWhitelist {
            for whitelistObj in whitelist {
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
    
    /// Makes a request to the `backendUrl` and returns the endpoints
    /// - parameter backendUrl: backend URL
    /// - parameter successCallback: called on success
    /// - parameter errorCallback: called on failure
    /// - returns: Dictionary containing the endpoints in successCallback, `SwedbankPaySDK.Problem` in errorCallback
    private func getEndPoints(_ backendUrl: URL, successCallback: Closure<Dictionary<String, String>?>? = nil, errorCallback: Closure<SwedbankPaySDK.Problem>? = nil) {
        sessionManager
            .request(
                backendUrl,
                method: .get,
                parameters: nil,
                encoding: JSONEncoding.default,
                headers: configuration?.afHeaders)
            .responseJSON(completionHandler: { response in
                if let responseValue = response.value {
                    // Alamofire request succeeded (backend might have responded with error)
                    if let statusCode = response.response?.statusCode {
                        if (200...299).contains(statusCode), let res = responseValue as? Dictionary<String, String> {
                            #if DEBUG
                            for (name, value) in res {
                                debugPrint("SwedbankPaySDK: EndPoint: \(name) : \(value)")
                            }
                            #endif
                            successCallback?(res)
                        } else if let response = responseValue as? Dictionary<String, Any> {
                            // Error
                            self.handleError(statusCode, response: response, callback: { problem in
                                errorCallback?(problem)
                            })
                        } else {
                            // Error response was of unknown format, return generic error
                            errorCallback?(self.getGenericProblem(statusCode, raw: response.description))
                        }
                    }
                } else {
                    // Alamofire request failed for some reason
                    errorCallback?(self.getGenericProblem(-1, raw: response.description))
                }
            })
    }
    
    /// Creates the actual payment order, anonymous if consumerData was not given
    /// - parameter backendUrl: backend URL
    /// - parameter successCallback: called on success
    /// - parameter errorCallback: called on failure
    /// - returns: `OperationsList` on successCallback, `SwedbankPaySDK.Problem` on errorCallback
    func createPaymentOrder(_ backendUrl: URL, successCallback: Closure<OperationsList>? = nil, errorCallback: Closure<SwedbankPaySDK.Problem>? = nil) {
        
        getEndPoints(backendUrl, successCallback: { [weak self] endPoints in
            // getEndPoints success
            guard let endPoints = endPoints else {
                let msg: String = SDKProblemString.endPointsListEmpty.rawValue
                errorCallback?(SwedbankPaySDK.Problem.Client(.MobileSDK(.InvalidRequest(message: msg, raw: nil))))
                return
            }
            
            guard let endPoint = endPoints[EndPointName.paymentorders.rawValue] else {
                let msg: String = SDKProblemString.paymentordersEndpointIsMissing.rawValue
                errorCallback?(SwedbankPaySDK.Problem.Client(.MobileSDK(.InvalidRequest(message: msg, raw: nil))))
                return
            }
            
            guard let endPointUrl = URL.init(string: endPoint, relativeTo: backendUrl) else {
                let msg: String = SDKProblemString.backendRequestUrlCreationFailed.rawValue
                errorCallback?(SwedbankPaySDK.Problem.Client(.MobileSDK(.InvalidRequest(message: msg, raw: nil))))
                return
            }
            
            guard var paymentOrder = self?.paymentOrder else {
                let msg: String = SDKProblemString.merchantDataMissing.rawValue
                errorCallback?(SwedbankPaySDK.Problem.Client(.MobileSDK(.InvalidRequest(message: msg, raw: nil))))
                return
            }
            if let consumerProfileRef = self?.consumerProfileRef {
                paymentOrder.payer = .init(consumerProfileRef: consumerProfileRef)
            }
            
            let json = try! JSONEncoder().encode(["paymentorder": paymentOrder])
            
            var request = URLRequest(url: endPointUrl)
            request.method = .post
            if let headers = self?.configuration?.afHeaders {
                request.headers = headers
            }
            if request.value(forHTTPHeaderField: "Content-Type") == nil {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
            request.httpBody = json
            
            self?.sessionManager
                .request(request)
                .responseDecodable(
                    of: OperationsList.self,
                    completionHandler: { [weak self] response in
                        self?.handleResponse(response, successCallback: { operationsList in
                            successCallback?(operationsList)
                        }, errorCallback: { problem in
                            errorCallback?(problem)
                        })
                    }
                )
        }, errorCallback: { problem in
            // getEndPoints failed
            errorCallback?(problem)
        })
    }
    
    
    
    /// Creates consumer identification request for registered consumer
    /// - parameter backendUrl: backend URL
    /// - parameter successCallback: called on success
    /// - parameter errorCallback: called on failure
    /// - returns: `OperationsList` on successCallback, `SwedbankPaySDK.Problem` on errorCallback
    func identifyConsumer(_ backendUrl: URL, successCallback: Closure<OperationsList>? = nil, errorCallback: Closure<SwedbankPaySDK.Problem>? = nil) {
        
        getEndPoints(backendUrl, successCallback: { [weak self] endPoints in
            // getEndPoints success
            guard let endPoints = endPoints else {
                let msg: String = SDKProblemString.endPointsListEmpty.rawValue
                errorCallback?(SwedbankPaySDK.Problem.Client(.MobileSDK(.InvalidRequest(message: msg, raw: nil))))
                return
            }
            
            guard let endPoint = endPoints[EndPointName.consumers.rawValue] else {
                let msg: String = SDKProblemString.consumersEndpointMissing.rawValue
                errorCallback?(SwedbankPaySDK.Problem.Client(.MobileSDK(.InvalidRequest(message: msg, raw: nil))))
                return
            }
            
            guard let url = URL.init(string: endPoint, relativeTo: backendUrl) else {
                let msg: String = SDKProblemString.backendRequestUrlCreationFailed.rawValue
                errorCallback?(SwedbankPaySDK.Problem.Client(.MobileSDK(.InvalidRequest(message: msg, raw: nil))))
                return
            }
            
            guard let consumerData = self?.consumerData else {
                let msg: String = SDKProblemString.consumerDataMissing.rawValue
                errorCallback?(SwedbankPaySDK.Problem.Client(.MobileSDK(.InvalidRequest(message: msg, raw: nil))))
                return
            }
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            
            if let data = try? encoder.encode(consumerData) {
                var urlRequest = URLRequest(url: url)
                urlRequest.allHTTPHeaderFields = self?.configuration?.headers
                urlRequest.httpMethod = HTTPMethod.post.rawValue
                urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                urlRequest.httpBody = data
                
                self?.sessionManager
                    .request(urlRequest)
                    .responseDecodable(
                        of: OperationsList.self,
                        completionHandler: { [weak self] response in
                            self?.handleResponse(response, successCallback: { operationsList in
                                successCallback?(operationsList)
                            }, errorCallback: { problem in
                                errorCallback?(problem)
                            })
                        })
            } else {
                let msg: String = SDKProblemString.consumerDataEncodingFailed.rawValue
                errorCallback?(SwedbankPaySDK.Problem.Client(.MobileSDK(.InvalidRequest(message: msg, raw: nil))))
            }
        }, errorCallback: { problem in
            // getEndPoints failed
            errorCallback?(problem)
            return
        })
    }
    
    /// Response handler
    /// - parameter response: `DataResponse`
    /// - parameter successCallback: called on success
    /// - parameter errorCallback: called on failure
    /// - returns: `OperationsList` on successCallback, `SwedbankPaySDK.Problem` on errorCallback
    private func handleResponse(
        _ response: AFDataResponse<OperationsList>,
        successCallback: Closure<OperationsList>? = nil,
        errorCallback: Closure<SwedbankPaySDK.Problem>? = nil
    ) {
        if let responseValue = response.value {
            // Alamofire request succeeded (backend might have responded with error)
            if let statusCode = response.response?.statusCode {
                if (200...299).contains(statusCode) {
                    // Success
                    successCallback?(responseValue)
                } else if let data = response.data,
                    let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // Error
                    self.handleError(statusCode, response: json, callback: { problem in
                        errorCallback?(problem)
                    })
                } else {
                    // Error response was of unknown format, return generic error
                    errorCallback?(getGenericProblem(statusCode, raw: response.description))
                }
            }
        } else {
            // Alamofire request failed for some reason
            errorCallback?(getGenericProblem(response.response?.statusCode ?? -1, raw: response.description))
        }
    }
    
    /// Error handler, all backend request errors go through this
    /// - parameter statusCode: HTTP Status code
    /// - parameter response: Response Dictionary
    /// - parameter callback: return callback
    /// - returns: `Problem` on callback
    private func handleError(_ statusCode: Int, response: Dictionary<String, Any>, callback: Closure<SwedbankPaySDK.Problem>? = nil) {
        if let type = response["type"] as? String {
            if (400...499).contains(statusCode) {
                let problem = getClientProblem(statusCode, problemType: type, response: response)
                callback?(problem)
            } else if (500...599).contains(statusCode) {
                let problem = getServerProblem(statusCode, problemType: type, response: response)
                callback?(problem)
            }
        } else {
            // Error response was of unknown format, return generic error
            callback?(getGenericProblem(statusCode, raw: response.description))
        }
    }
    
    // MARK: Helper methods for error handling
    
    private func getClientProblem(_ statusCode: Int, problemType: String, response: Dictionary<String, Any>) -> SwedbankPaySDK.Problem {
        
        switch problemType {
        case ClientProblemType.Unauthorized.rawValue:
            let problem = SwedbankPaySDK.Problem.Client(.MobileSDK(.Unauthorized(message: response["title"] as? String, raw: response["detail"] as? String)))
            return problem
        case ClientProblemType.BadRequest.rawValue:
            let problem = SwedbankPaySDK.Problem.Client(.MobileSDK(.InvalidRequest(message: response["title"] as? String, raw: response["detail"] as? String)))
            return problem
        
        case ClientProblemType.InputError.rawValue:
            let problem = getClientSwedbankPayProblem(SwedbankPaySDK.ClientProblem.SwedbankPayProblem.InputError, response: response)
            return problem
        case ClientProblemType.Forbidden.rawValue:
            let problem = getClientSwedbankPayProblem(SwedbankPaySDK.ClientProblem.SwedbankPayProblem.Forbidden, response: response)
            return problem
        case ClientProblemType.NotFound.rawValue:
            let problem = getClientSwedbankPayProblem(SwedbankPaySDK.ClientProblem.SwedbankPayProblem.NotFound, response: response)
            return problem
        
        default:
            // Return default error to make switch exhaustive
            return getGenericProblem(statusCode, raw: response.description)
        }
    }
    
    private func getServerProblem(_ statusCode: Int, problemType: String, response: Dictionary<String, Any>) -> SwedbankPaySDK.Problem {
        
        switch problemType {
        case ServerProblemType.InternalServerError.rawValue:
            let problem = SwedbankPaySDK.Problem.Server(.MobileSDK(.InvalidBackendResponse(body: response["title"] as? String, raw: response["status"] as? String)))
            return problem
        case ServerProblemType.BadGateway.rawValue:
            let problem = SwedbankPaySDK.Problem.Server(.MobileSDK(.BackendConnectionFailure(message: response["title"] as? String, raw: response["detail"] as? String)))
            return problem
        case ServerProblemType.GatewayTimeOut.rawValue:
            let problem = SwedbankPaySDK.Problem.Server(.MobileSDK(.BackendConnectionTimeout(message: response["title"] as? String, raw: response["detail"] as? String)))
            return problem

        case ServerProblemType.SystemError.rawValue:
            let problem = getServerSwedbankPayProblem(.SystemError, response: response)
            return problem
        case ServerProblemType.ConfigurationError.rawValue:
            let problem = getServerSwedbankPayProblem(.ConfigurationError, response: response)
            return problem
            
        default:
            // Return default error to make switch exhaustive
            return getGenericProblem(statusCode, raw: response.description)
        }
    }
    
    private func getGenericProblem(_ statusCode: Int, raw: String? = nil) -> SwedbankPaySDK.Problem {
        if statusCode >= 500 {
            let problem = SwedbankPaySDK.Problem.Server(.Unknown(type: nil, title: "Unknown Server error occurred", status: statusCode, detail: nil, instance: nil, raw: raw))
            return problem
        } else {
            let problem = SwedbankPaySDK.Problem.Client(.Unknown(type: nil, title: "Unknown Client error occurred", status: statusCode, detail: nil, instance: nil, raw: raw))
            return problem
        }
    }
    
    private func getClientSwedbankPayProblem(_ problemType: SwedbankPaySDK.ClientProblem.SwedbankPayProblem, response: Dictionary<String, Any>) -> SwedbankPaySDK.Problem {
        let subProblems: [SwedbankPaySDK.SwedbankPaySubProblem]? = getSubProblems(response["problems"] as? [Dictionary<String, Any>])
        let problem = SwedbankPaySDK.Problem.Client(
            .SwedbankPay(
                type: problemType,
                title: response["title"] as? String,
                detail: response["detail"] as? String,
                instance: response["instance"] as? String,
                action: response["action"] as? String,
                problems: subProblems,
                raw: response["raw"] as? String)
        )
        return problem
    }
    
    private func getServerSwedbankPayProblem(_ problemType: SwedbankPaySDK.ServerProblem.SwedbankPayProblem, response: Dictionary<String, Any>) -> SwedbankPaySDK.Problem {
        let subProblems: [SwedbankPaySDK.SwedbankPaySubProblem]? = getSubProblems(
            response["problems"] as? [[String: Any]]
        )
        let problem = SwedbankPaySDK.Problem.Server (
            .SwedbankPay(
                type: problemType,
                title: response["title"] as? String,
                detail: response["detail"] as? String,
                instance: response["instance"] as? String,
                action: response["action"] as? String,
                problems: subProblems,
                raw: response["raw"] as? String)
        )
        return problem
    }
    
    private func getSubProblems(_ json: [[String: Any]]?) -> [SwedbankPaySDK.SwedbankPaySubProblem]? {
        return json?.map {
            SwedbankPaySDK.SwedbankPaySubProblem.init(
                name: $0["name"] as? String,
                description: $0["description"] as? String
            )
        }
    }
}
