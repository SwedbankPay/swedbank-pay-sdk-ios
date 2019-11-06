import Alamofire
import ObjectMapper

final class SwedbankPaySDKViewModel: NSObject {

    private(set) var configuration: SwedbankPaySDK.Configuration?
    private(set) var consumerData: SwedbankPaySDK.Consumer?
    private(set) var merchantData: Any?
    private(set) var consumerProfileRef: String?
    
    /// Sets the `SwedbankPaySDK.Configuration`
    /// - parameter configuration: Configuration to be set
    public func setConfiguration(_ configuration: SwedbankPaySDK.Configuration) {
        self.configuration = configuration
        
        // If `configuration.domainWhitelist` is empty, add backendUrl as whitelisted domain
        if let empty = self.configuration?.domainWhitelist?.isEmpty, empty {
            if let backendUrl = self.configuration?.backendUrl {
                let host = URL.init(string: backendUrl)?.host
                let domain = SwedbankPaySDK.WhitelistedDomain.init(
                    domain: host,
                    includeSubdomains: true
                )
                self.configuration?.domainWhitelist = [domain]
            }
        }
    }
    
    /// Sets the `SwedbankPaySDK.Consumer`
    /// - parameter consumerData: consumerData to set
    public func setConsumerData(_ consumerData: SwedbankPaySDK.Consumer?) {
        self.consumerData = consumerData
    }
    
    /// Sets the `merchantData`
    /// - parameter merchantData: merchantData to set
    public func setMerchantData(_ merchantData: Any?) {
        self.merchantData = merchantData
    }
    
    /// Sets the `consumerProfileRef`
    /// - parameter ref: consumerProfileRef to set
    public func setConsumerProfileRef(_ ref: String?) {
        self.consumerProfileRef = ref
    }
    
    /// Check if the request is being made to a whitelisted domain
    /// - parameter url: request URL as a String to check
    /// - returns: Boolean idicating was the domain whitelisted or not
    public func isDomainWhitelisted(_ url: String) -> Bool {
        if let url = URL(string: url), let host = url.host, let whitelist = configuration?.domainWhitelist {
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
    private func getEndPoints(_ backendUrl: String, successCallback: Closure<Dictionary<String, String>?>? = nil, errorCallback: Closure<SwedbankPaySDK.Problem>? = nil) {
        
        request(backendUrl, method: .get, parameters: nil, encoding: JSONEncoding.default, headers: configuration?.headers).responseJSON(completionHandler: { response in
            if let responseValue = response.result.value {
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
                        errorCallback?(self.getGenericProblem(statusCode))
                    }
                }
            }
        })
    }
    
    /// Creates the actual payment order, anonymous if consumerData was not given
    /// - parameter backendUrl: backend URL
    /// - parameter successCallback: called on success
    /// - parameter errorCallback: called on failure
    /// - returns: `OperationsList` on successCallback, `SwedbankPaySDK.Problem` on errorCallback
    public func createPaymentOrder(_ backendUrl: String, successCallback: Closure<OperationsList>? = nil, errorCallback: Closure<SwedbankPaySDK.Problem>? = nil) {
        
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
            
            guard let merchantData = self?.merchantData else {
                let msg: String = SDKProblemString.merchantDataMissing.rawValue
                errorCallback?(SwedbankPaySDK.Problem.Client(.MobileSDK(.InvalidRequest(message: msg, raw: nil))))
                return
            }
            
            var parameters: [String: Any]? = [
                "merchantData": merchantData
            ]
            
            if self?.consumerProfileRef != nil {
                parameters?["consumerProfileRef"] = self?.consumerProfileRef
            }
            
            request(backendUrl + endPoint, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: self?.configuration?.headers).responseJSON(completionHandler: { [weak self] response in
                self?.handleResponse(response, successCallback: { operationsList in
                    successCallback?(operationsList)
                }, errorCallback: { problem in
                    errorCallback?(problem)
                })
            })
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
    public func identifyConsumer(_ backendUrl: String, successCallback: Closure<OperationsList>? = nil, errorCallback: Closure<SwedbankPaySDK.Problem>? = nil) {
        
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
            
            guard let url = URL.init(string: backendUrl + endPoint) else {
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
                
                request(urlRequest).responseJSON(completionHandler: { [weak self] response in
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
    private func handleResponse(_ response: DataResponse<Any>, successCallback: Closure<OperationsList>? = nil, errorCallback: Closure<SwedbankPaySDK.Problem>? = nil) {
        if let responseValue = response.result.value {
            if let statusCode = response.response?.statusCode {
                if (200...299).contains(statusCode) {
                    // Success
                    if let result = Mapper<OperationsList>().map(JSONObject: responseValue) {
                        successCallback?(result)
                    }
                } else if let response = response.result.value as? Dictionary<String, Any> {
                    // Error
                    self.handleError(statusCode, response: response, callback: { problem in
                        errorCallback?(problem)
                    })
                } else {
                   // Error response was of unknown format, return generic error
                   errorCallback?(getGenericProblem(statusCode))
                }
            }
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
            callback?(getGenericProblem(statusCode))
        }
    }
    
    // MARK: Helper methods for error handling
    
    private func getClientProblem(_ statusCode: Int, problemType: String, response: Dictionary<String, Any>) -> SwedbankPaySDK.Problem {
        
        switch problemType {
        case SwedbankPaySDK.ClientProblemType.Unauthorized.rawValue:
            let problem = SwedbankPaySDK.Problem.Client(.MobileSDK(.Unauthorized(message: response["title"] as? String, raw: response["detail"] as? String)))
            return problem
        case SwedbankPaySDK.ClientProblemType.BadRequest.rawValue:
            let problem = SwedbankPaySDK.Problem.Client(.MobileSDK(.InvalidRequest(message: response["title"] as? String, raw: response["detail"] as? String)))
            return problem
        
        case SwedbankPaySDK.ClientProblemType.InputError.rawValue:
            let problem = getClientSwedbankPayProblem(SwedbankPaySDK.ClientProblem.SwedbankPayProblem.InputError, response: response)
            return problem
        case SwedbankPaySDK.ClientProblemType.Forbidden.rawValue:
            let problem = getClientSwedbankPayProblem(SwedbankPaySDK.ClientProblem.SwedbankPayProblem.Forbidden, response: response)
            return problem
        case SwedbankPaySDK.ClientProblemType.NotFound.rawValue:
            let problem = getClientSwedbankPayProblem(SwedbankPaySDK.ClientProblem.SwedbankPayProblem.NotFound, response: response)
            return problem
        
        default:
            // Return default error to make switch exhaustive
            return getGenericProblem(statusCode)
        }
    }
    
    private func getServerProblem(_ statusCode: Int, problemType: String, response: Dictionary<String, Any>) -> SwedbankPaySDK.Problem {
        
        switch problemType {
        case SwedbankPaySDK.ServerProblemType.InternalServerError.rawValue:
            let problem = SwedbankPaySDK.Problem.Server(.MobileSDK(.InvalidBackendResponse(body: response["title"] as? String, raw: response["status"] as? String)))
            return problem
        case SwedbankPaySDK.ServerProblemType.BadGateway.rawValue:
            let problem = SwedbankPaySDK.Problem.Server(.MobileSDK(.BackendConnectionFailure(message: response["title"] as? String, raw: response["detail"] as? String)))
            return problem
        case SwedbankPaySDK.ServerProblemType.GatewayTimeOut.rawValue:
            let problem = SwedbankPaySDK.Problem.Server(.MobileSDK(.BackendConnectionTimeout(message: response["title"] as? String, raw: response["detail"] as? String)))
            return problem

        case SwedbankPaySDK.ServerProblemType.SystemError.rawValue:
            let problem = getServerSwedbankPayProblem(.SystemError, response: response)
            return problem
        case SwedbankPaySDK.ServerProblemType.ConfigurationError.rawValue:
            let problem = getServerSwedbankPayProblem(.ConfigurationError, response: response)
            return problem
            
        default:
            // Return default error to make switch exhaustive
            return getGenericProblem(statusCode)
        }
    }
    
    private func getGenericProblem(_ statusCode: Int) -> SwedbankPaySDK.Problem {
        let problem = SwedbankPaySDK.Problem.Server(.Unknown(type: nil, title: "Unknown error occurred", status: statusCode, detail: nil, instance: nil, raw: nil))
        return problem
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
        let subProblems: [SwedbankPaySDK.SwedbankPaySubProblem]? = getSubProblems(response["problems"] as? [Dictionary<String, Any>])
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
    
    private func getSubProblems(_ string: [Dictionary<String, Any>]?) -> [SwedbankPaySDK.SwedbankPaySubProblem]? {
        var subProblems: [SwedbankPaySDK.SwedbankPaySubProblem]? = nil
        if let string = string {
            subProblems = Mapper<SwedbankPaySDK.SwedbankPaySubProblem>().mapArray(JSONObject: string)
        }
        return subProblems
    }
}
