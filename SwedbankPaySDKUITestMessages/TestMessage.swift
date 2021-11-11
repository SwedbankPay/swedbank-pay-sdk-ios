enum TestMessage: Equatable, Codable {
    case complete
    case canceled
    case error(errorMessage: String)
}
