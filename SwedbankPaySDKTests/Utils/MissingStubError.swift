struct MissingStubError : Error {}

extension MockURLResult {
    static let missingStub = MockURLResult(error: MissingStubError())
}
