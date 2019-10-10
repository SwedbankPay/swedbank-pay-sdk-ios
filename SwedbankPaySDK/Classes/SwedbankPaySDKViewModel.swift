import Alamofire
import ObjectMapper

final class SwedbankPaySDKViewModel: NSObject {
    
    var headers: HTTPHeaders?
    
    var backendUrl: String?
    var consumerData: Any?
    var consumerProfileRef: String?
    var merchantData: Any?
    
    /// Creates HTTP Headers for the backendUrl requests
    public func setHeaders(_ headers: Dictionary<String, String>) {
        self.headers = headers
    }
    
    /// Returns HTTP Headers
    public func getHeaders() -> HTTPHeaders? {
        return headers
    }
    
    /** Makes a request to the backendUrl and returns the endpoints
     
     - Returns: Dictionary containing the endpoints
     */
    public func getEndPoints(successCallback: Closure<Dictionary<String, String>?>? = nil, errorCallback: Closure<SwedbankPaySDK.Problem>? = nil) {
        
        guard let backendUrl = backendUrl else {
            let msg: String = SDKProblemString.backendUrlMissing.rawValue
            errorCallback?(SwedbankPaySDK.Problem.Client(.MobileSDK(.InvalidRequest(message: msg, raw: nil))))
            return
        }
        
        request(backendUrl, method: .get, parameters: nil, encoding: JSONEncoding.default, headers: getHeaders()).responseJSON(completionHandler: { response in
            if let responseValue = response.result.value {
                if let statusCode = response.response?.statusCode {
                    if (200...299).contains(statusCode), let res = responseValue as? Dictionary<String, String> {
                        /*
                         #if DEBUG
                        for (name, value) in res {
                            debugPrint("SwedbankPaySDK: EndPoint: \(name) : \(value)")
                        }
                        #endif
                         */
                        successCallback?(res)
                    } else if let response = responseValue as? Dictionary<String, Any> {
                        // Error
                        self.handleError(statusCode, response: response, callback: { problem in
                            errorCallback?(problem)
                        })
                    } else {
                        // Error response was of unknown format, return generic error
                        errorCallback?(self.getServerGenericProblem(statusCode))
                    }
                }
            }
        })
    }
    
    /// Creates the actual payment order, anonymous if consumerData was not given
    public func createPaymentOrder(successCallback: Closure<OperationsList>? = nil, errorCallback: Closure<SwedbankPaySDK.Problem>? = nil) {
        
        guard let backendUrl = backendUrl else {
            let msg: String = SDKProblemString.backendUrlMissing.rawValue
            errorCallback?(SwedbankPaySDK.Problem.Client(.MobileSDK(.InvalidRequest(message: msg, raw: nil))))
            return
        }
        
        getEndPoints(successCallback: { [weak self] endPoints in
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
            
            request(backendUrl + endPoint, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: self?.getHeaders()).responseJSON(completionHandler: { [weak self] response in
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
    
    /// Creates user identification request for registered user
    public func identifyUser(successCallback: Closure<OperationsList>? = nil, errorCallback: Closure<SwedbankPaySDK.Problem>? = nil) {
        
        guard let backendUrl = backendUrl else {
            let msg: String = SDKProblemString.backendUrlMissing.rawValue
            errorCallback?(SwedbankPaySDK.Problem.Client(.MobileSDK(.InvalidRequest(message: msg, raw: nil))))
            return
        }
        
        getEndPoints(successCallback: { [weak self] endPoints in
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
            if let consumerData: SwedbankPaySDK.Consumer = consumerData as? SwedbankPaySDK.Consumer, let data = try? encoder.encode(consumerData) {

                var urlRequest = URLRequest(url: url)
                urlRequest.allHTTPHeaderFields = self?.getHeaders()
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
                   errorCallback?(getServerGenericProblem(statusCode))
                }
            }
        }
    }
    
    /// Error handler, all backend request errors go through this
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
            callback?(getServerGenericProblem(statusCode))
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
            let problem = getClientPayexProblem(SwedbankPaySDK.ClientProblem.SwedbankPayProblem.InputError, response: response)
            return problem
        case SwedbankPaySDK.ClientProblemType.Forbidden.rawValue:
            let problem = getClientPayexProblem(SwedbankPaySDK.ClientProblem.SwedbankPayProblem.Forbidden, response: response)
            return problem
        case SwedbankPaySDK.ClientProblemType.NotFound.rawValue:
            let problem = getClientPayexProblem(SwedbankPaySDK.ClientProblem.SwedbankPayProblem.NotFound, response: response)
            return problem
        
        default:
            // Return default error to make switch exhaustive
            return getServerGenericProblem(statusCode)
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
            let problem = getServerPayexProblem(.SystemError, response: response)
            return problem
        case SwedbankPaySDK.ServerProblemType.ConfigurationError.rawValue:
            let problem = getServerPayexProblem(.ConfigurationError, response: response)
            return problem
            
        default:
            // Return default error to make switch exhaustive
            return getServerGenericProblem(statusCode)
        }
    }
    
    private func getServerGenericProblem(_ statusCode: Int) -> SwedbankPaySDK.Problem {
        let problem = SwedbankPaySDK.Problem.Server(.Unknown(type: nil, title: "Unknown error occurred", status: statusCode, detail: nil, instance: nil, raw: nil))
        return problem
    }
    
    private func getClientPayexProblem(_ problemType: SwedbankPaySDK.ClientProblem.SwedbankPayProblem, response: Dictionary<String, Any>) -> SwedbankPaySDK.Problem {
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
    
    private func getServerPayexProblem(_ problemType: SwedbankPaySDK.ServerProblem.SwedbankPayProblem, response: Dictionary<String, Any>) -> SwedbankPaySDK.Problem {
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
