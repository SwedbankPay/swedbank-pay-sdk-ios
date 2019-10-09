import Alamofire
import ObjectMapper

final class PayexSDKViewModel: NSObject {
    
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
    public func getEndPoints(successCallback: Closure<Dictionary<String, String>?>? = nil, errorCallback: Closure<PayexSDK.Problem>? = nil) {
        
        guard let backendUrl = backendUrl else {
            let msg: String = SDKProblemString.backendUrlMissing.rawValue
            errorCallback?(PayexSDK.Problem.Client(.MobileSDK(.InvalidRequest(message: msg, raw: nil))))
            return
        }
        
        request(backendUrl, method: .get, parameters: nil, encoding: JSONEncoding.default, headers: getHeaders()).responseJSON(completionHandler: { response in
            if let responseValue = response.result.value {
                if let statusCode = response.response?.statusCode {
                    if (200...299).contains(statusCode), let res = responseValue as? Dictionary<String, String> {
                        #if DEBUG
                        for (name, value) in res {
                            debugPrint("PayexSDK: EndPoint: \(name) : \(value)")
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
                        errorCallback?(self.getServerGenericProblem(statusCode))
                    }
                }
            }
        })
    }
    
    /// Creates the actual payment order, anonymous if consumerData was not given
    public func createPaymentOrder(successCallback: Closure<OperationsList>? = nil, errorCallback: Closure<PayexSDK.Problem>? = nil) {
        
        guard let backendUrl = backendUrl else {
            let msg: String = SDKProblemString.backendUrlMissing.rawValue
            errorCallback?(PayexSDK.Problem.Client(.MobileSDK(.InvalidRequest(message: msg, raw: nil))))
            return
        }
        
        getEndPoints(successCallback: { [weak self] endPoints in
            // getEndPoints success
            guard let endPoints = endPoints else {
                let msg: String = SDKProblemString.endPointsListEmpty.rawValue
                errorCallback?(PayexSDK.Problem.Client(.MobileSDK(.InvalidRequest(message: msg, raw: nil))))
                return
            }
            
            guard let endPoint = endPoints[EndPointName.paymentorders.rawValue] else {
                let msg: String = SDKProblemString.paymentordersEndpointIsMissing.rawValue
                errorCallback?(PayexSDK.Problem.Client(.MobileSDK(.InvalidRequest(message: msg, raw: nil))))
                return
            }
            
            guard let merchantData = self?.merchantData else {
                let msg: String = SDKProblemString.merchantDataMissing.rawValue
                errorCallback?(PayexSDK.Problem.Client(.MobileSDK(.InvalidRequest(message: msg, raw: nil))))
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
    public func identifyUser(successCallback: Closure<OperationsList>? = nil, errorCallback: Closure<PayexSDK.Problem>? = nil) {
        
        guard let backendUrl = backendUrl else {
            let msg: String = SDKProblemString.backendUrlMissing.rawValue
            errorCallback?(PayexSDK.Problem.Client(.MobileSDK(.InvalidRequest(message: msg, raw: nil))))
            return
        }
        
        getEndPoints(successCallback: { [weak self] endPoints in
            // getEndPoints success
            guard let endPoints = endPoints else {
                let msg: String = SDKProblemString.endPointsListEmpty.rawValue
                errorCallback?(PayexSDK.Problem.Client(.MobileSDK(.InvalidRequest(message: msg, raw: nil))))
                return
            }
            
            guard let endPoint = endPoints[EndPointName.consumers.rawValue] else {
                let msg: String = SDKProblemString.consumersEndpointMissing.rawValue
                errorCallback?(PayexSDK.Problem.Client(.MobileSDK(.InvalidRequest(message: msg, raw: nil))))
                return
            }
            
            guard let url = URL.init(string: backendUrl + endPoint) else {
                let msg: String = SDKProblemString.backendRequestUrlCreationFailed.rawValue
                errorCallback?(PayexSDK.Problem.Client(.MobileSDK(.InvalidRequest(message: msg, raw: nil))))
                return
            }
            
            guard let consumerData = self?.consumerData else {
                let msg: String = SDKProblemString.consumerDataMissing.rawValue
                errorCallback?(PayexSDK.Problem.Client(.MobileSDK(.InvalidRequest(message: msg, raw: nil))))
                return
            }
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            if let consumerData: PayexSDK.Consumer = consumerData as? PayexSDK.Consumer, let data = try? encoder.encode(consumerData) {

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
                errorCallback?(PayexSDK.Problem.Client(.MobileSDK(.InvalidRequest(message: msg, raw: nil))))
            }
        }, errorCallback: { problem in
            // getEndPoints failed
            errorCallback?(problem)
            return
        })
    }
    
    /// Response handler
    private func handleResponse(_ response: DataResponse<Any>, successCallback: Closure<OperationsList>? = nil, errorCallback: Closure<PayexSDK.Problem>? = nil) {
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
    private func handleError(_ statusCode: Int, response: Dictionary<String, Any>, callback: Closure<PayexSDK.Problem>? = nil) {
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
    private func getClientProblem(_ statusCode: Int, problemType: String, response: Dictionary<String, Any>) -> PayexSDK.Problem {
        
        switch problemType {
        case PayexSDK.ClientProblemType.Unauthorized.rawValue:
            let problem = PayexSDK.Problem.Client(.MobileSDK(.Unauthorized(message: response["title"] as? String, raw: response["detail"] as? String)))
            return problem
        case PayexSDK.ClientProblemType.BadRequest.rawValue:
            let problem = PayexSDK.Problem.Client(.MobileSDK(.InvalidRequest(message: response["title"] as? String, raw: response["detail"] as? String)))
            return problem
        
        case PayexSDK.ClientProblemType.InputError.rawValue:
            let problem = getClientPayexProblem(PayexSDK.ClientProblem.PayExProblem.InputError, response: response)
            return problem
        case PayexSDK.ClientProblemType.Forbidden.rawValue:
            let problem = getClientPayexProblem(PayexSDK.ClientProblem.PayExProblem.Forbidden, response: response)
            return problem
        case PayexSDK.ClientProblemType.NotFound.rawValue:
            let problem = getClientPayexProblem(PayexSDK.ClientProblem.PayExProblem.NotFound, response: response)
            return problem
        
        default:
            // Return default error to make switch exhaustive
            return getServerGenericProblem(statusCode)
        }
    }
    
    private func getServerProblem(_ statusCode: Int, problemType: String, response: Dictionary<String, Any>) -> PayexSDK.Problem {
        
        switch problemType {
        case PayexSDK.ServerProblemType.InternalServerError.rawValue:
            let problem = PayexSDK.Problem.Server(.MobileSDK(.InvalidBackendResponse(body: response["title"] as? String, raw: response["status"] as? String)))
            return problem
        case PayexSDK.ServerProblemType.BadGateway.rawValue:
            let problem = PayexSDK.Problem.Server(.MobileSDK(.BackendConnectionFailure(message: response["title"] as? String, raw: response["detail"] as? String)))
            return problem
        case PayexSDK.ServerProblemType.GatewayTimeOut.rawValue:
            let problem = PayexSDK.Problem.Server(.MobileSDK(.BackendConnectionTimeout(message: response["title"] as? String, raw: response["detail"] as? String)))
            return problem

        case PayexSDK.ServerProblemType.SystemError.rawValue:
            let problem = getServerPayexProblem(.SystemError, response: response)
            return problem
        case PayexSDK.ServerProblemType.ConfigurationError.rawValue:
            let problem = getServerPayexProblem(.ConfigurationError, response: response)
            return problem
            
        default:
            // Return default error to make switch exhaustive
            return getServerGenericProblem(statusCode)
        }
    }
    
    private func getServerGenericProblem(_ statusCode: Int) -> PayexSDK.Problem {
        let problem = PayexSDK.Problem.Server(.Unknown(type: nil, title: "Unknown error occurred", status: statusCode, detail: nil, instance: nil, raw: nil))
        return problem
    }
    
    private func getClientPayexProblem(_ problemType: PayexSDK.ClientProblem.PayExProblem, response: Dictionary<String, Any>) -> PayexSDK.Problem {
        let subProblems: [PayexSDK.PayexSubProblem]? = getSubProblems(response["problems"] as? [Dictionary<String, Any>])
        let problem = PayexSDK.Problem.Client(
            .PayEx(
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
    
    private func getServerPayexProblem(_ problemType: PayexSDK.ServerProblem.PayExProblem, response: Dictionary<String, Any>) -> PayexSDK.Problem {
        let subProblems: [PayexSDK.PayexSubProblem]? = getSubProblems(response["problems"] as? [Dictionary<String, Any>])
        let problem = PayexSDK.Problem.Server (
            .PayEx(
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
    
    private func getSubProblems(_ string: [Dictionary<String, Any>]?) -> [PayexSDK.PayexSubProblem]? {
        var subProblems: [PayexSDK.PayexSubProblem]? = nil
        if let string = string {
            subProblems = Mapper<PayexSDK.PayexSubProblem>().mapArray(JSONObject: string)
        }
        return subProblems
    }
}
