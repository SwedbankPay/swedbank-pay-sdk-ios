enum TestMessage: Equatable, Codable {
    case complete
    case canceled
    case didShow
    case error(errorMessage: String)
}
