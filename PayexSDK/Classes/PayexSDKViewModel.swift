import Alamofire

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
    public func getEndPoints(successCallback: Closure<[String: String]?>? = nil, errorCallback: CallbackClosure? = nil) {
        
        guard let backendUrl = backendUrl else {
            debugPrint("PayexSDK: backendUrl not defined")
            errorCallback?()
            return
        }
        
        request(backendUrl, method: .get, parameters: nil, encoding: JSONEncoding.default, headers: getHeaders()).responseJSON(completionHandler: { response in
            if let statusCode = response.response?.statusCode, statusCode == 200, let dict = response.result.value as? [String: String] {
                
                #if DEBUG
                for (name, value) in dict {
                    debugPrint("PayexSDK: EndPoint: \(name) : \(value)")
                }
                #endif
                successCallback?(dict)
            } else {
                debugPrint("PayexSDK: Error fetching backendUrl endpoints")
                errorCallback?()
            }
        })
    }
    
    // Creates the actual payment order, anonymous if consumerData was not given
    public func createPaymentOrder(successCallback: Closure<OperationsList>? = nil, errorCallback: CallbackClosure? = nil) {
        
        guard let backendUrl = backendUrl else {
            debugPrint("PayexSDK: backendUrl not defined")
            errorCallback?()
            return
        }
        
        getEndPoints(successCallback: { [weak self] endPoints in
            // getEndPoints success
            guard let endPoints = endPoints else {
                debugPrint("PayexSDK: endPoints missing")
                errorCallback?()
                return
            }
            
            guard let endPoint = endPoints[EndPointName.paymentorders.rawValue] else {
                debugPrint("PayexSDK: payment order cannot be created")
                errorCallback?()
                return
            }
            
            guard let merchantData = self?.merchantData else {
                debugPrint("PayexSDK: merchantData missing")
                errorCallback?()
                return
            }
            
            var parameters: [String: Any]? = [
                "merchantData": merchantData
            ]
            
            if self?.consumerProfileRef != nil {
                parameters?["consumerProfileRef"] = self?.consumerProfileRef
            }
            
            request(backendUrl + endPoint, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: self?.getHeaders()).responseObject(completionHandler: { (response: DataResponse<OperationsList>) in
                if let statusCode = response.response?.statusCode, statusCode == 200, let operationsList = response.result.value {
                    debugPrint("PayexSDK: Response: \(statusCode) - \(operationsList)")
                    successCallback?(operationsList)
                } else {
                    self?.handleError(response)
                    errorCallback?()
                }
            })
            
        }, errorCallback: {
            // getEndPoints failed
            debugPrint("PayexSDK: fetching endPoints failed")
            errorCallback?()
        })
    }
    
    /// Creates user identification request for registered user
    public func identifyUser(successCallback: Closure<OperationsList>? = nil, errorCallback: CallbackClosure? = nil) {
        
        guard let backendUrl = backendUrl else {
            debugPrint("PayexSDK: backendUrl not defined")
            return
        }
        
        getEndPoints(successCallback: { [weak self] endPoints in
            // getEndPoints success
            guard let endPoints = endPoints else {
                debugPrint("PayexSDK: endPoints missing")
                errorCallback?()
                return
            }
            
            guard let endPoint = endPoints[EndPointName.consumers.rawValue] else {
                debugPrint("PayexSDK: payment order cannot be created")
                errorCallback?()
                return
            }
            
            guard let url = URL.init(string: backendUrl + endPoint) else {
                debugPrint("PayexSDK: backendUrl is malformed")
                errorCallback?()
                return
            }
            
            guard let consumerData = self?.consumerData else {
                debugPrint("PayexSDK: consumerData missing")
                errorCallback?()
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
                
                request(urlRequest).responseObject(completionHandler: { (response: DataResponse<OperationsList>) in
                    if let statusCode = response.response?.statusCode, statusCode == 200, let operationsList = response.result.value {
                        debugPrint("PayexSDK: Response: \(statusCode) - \(operationsList)")
                        successCallback?(operationsList)
                    } else {
                        self?.handleError(response)
                        errorCallback?()
                    }
                })
            } else {
                print("Failed to encode")
                errorCallback?()
            }
        }, errorCallback: {
            // getEndPoints failed
            debugPrint("PayexSDK: fetching endPoints error")
            errorCallback?()
            return
        })
    }
    
    private func handleError(_ response: DataResponse<OperationsList>) {
        if let statusCode = response.response?.statusCode, let message = response.result.value?.message {
            debugPrint("PayexSDK: Error: \(statusCode) - \(message)")
        }
    }
}
