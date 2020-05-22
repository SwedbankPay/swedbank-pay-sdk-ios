import Foundation

struct MockURLResult {
    var response: (URLResponse, URLCache.StoragePolicy)? = nil
    var data: Data? = nil
    var error: Error? = nil
}

extension MockURLResult {
    init(
        response: URLResponse,
        data: Data
    ) {
        self.init(response: (response, .notAllowed), data: data, error: nil)
    }
    
    init(
        response: URLResponse,
        error: Error
    ) {
        self.init(response: (response, .notAllowed), data: nil, error: error)
    }
    
    init(error: Error) {
        self.init(response: nil, data: nil, error: error)
    }
}
