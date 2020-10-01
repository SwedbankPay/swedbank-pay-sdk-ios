import XCTest

extension Result {
    func assertSuccess(whereValueSatisfies assertions: (Success) -> Void = { _ in }) {
        switch self {
        case .success(let value):
            assertions(value)
        case .failure:
            XCTFail("Result was \(self) (expected success)")
        }
    }
    
    func assertFailure(whereErrorSatisfies assertions: (Failure) -> Void = { _ in }) {
        switch self {
        case .success:
            XCTFail("Result was \(self) (expected failure)")
        case .failure(let error):
            assertions(error)
        }
    }
}
