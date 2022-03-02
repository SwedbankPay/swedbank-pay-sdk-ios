enum TestMessage: Equatable, Codable {
    case complete
    case canceled
    case didShow
    case instrumentSelected
    case error(errorMessage: String)
}
