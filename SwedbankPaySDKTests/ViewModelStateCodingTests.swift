import Foundation
import XCTest
@testable import SwedbankPaySDK

class ViewModelStateCodingTests: XCTestCase {
    
    private static let viewPaymentOrderInfo = makeViewPaymentOrderInfo(userInfo: nil)
    
    private static let viewPaymentOrderInfoWithCodableUserInfo = makeViewPaymentOrderInfo(
        userInfo: CodableUserInfo(payload: "payload")
    )
    
    private static let viewPaymentOrderInfoWithNSCodingUserInfo = makeViewPaymentOrderInfo(
        userInfo: ViewModelStateCodingTestsNSCodingUserInfo(payload: "payload")
    )
    
    private static func makeViewPaymentOrderInfo(userInfo: Any?) -> SwedbankPaySDK.ViewPaymentOrderInfo {
        return SwedbankPaySDK.ViewPaymentOrderInfo(
            webViewBaseURL: URL(string: "about:blank")!,
            viewPaymentorder: URL(string: TestConstants.viewPaymentorderLink)!,
            completeUrl: URL(string: "about:blank")!,
            cancelUrl: nil,
            paymentUrl: nil,
            termsOfServiceUrl: nil,
            userInfo: userInfo
        )
    }
    
    func testSimpleCases() throws {
        try testCoding(state: .idle)
        try testCoding(state: .initializingConsumerSession)
        try testCoding(state: .identifyingConsumer(SwedbankPaySDK.ViewConsumerIdentificationInfo(
            webViewBaseURL: URL(string: "about:blank")!,
            viewConsumerIdentification: URL(string: TestConstants.viewConsumerSessionLink)!
        )))
        try testCoding(state: .creatingPaymentOrder(TestConstants.consumerProfileRef))
        try testCoding(state: .paying(ViewModelStateCodingTests.viewPaymentOrderInfo))
        try testCoding(state: .complete(ViewModelStateCodingTests.viewPaymentOrderInfo))
        try testCoding(state: .canceled(ViewModelStateCodingTests.viewPaymentOrderInfo))
    }
    
    func testCodableUserData() throws {
        SwedbankPaySDK.registerCodable(CodableUserInfo.self)
        try testCodingWithCodableUserInfo(
            state: .paying(ViewModelStateCodingTests.viewPaymentOrderInfoWithCodableUserInfo)
        )
    }
    
    func testNSCodingUserData() throws {
        try testCodingWithNSCodingUserInfo(
            state: .paying(ViewModelStateCodingTests.viewPaymentOrderInfoWithNSCodingUserInfo)
        )
    }
    
    func testCodableError() throws {
        SwedbankPaySDK.registerCodable(TestError.self)
        try testCoding(
            state: .failed(ViewModelStateCodingTests.viewPaymentOrderInfo, TestError.theError("error")),
            errorType: TestError.self
        )
    }
    
    func testNSError() throws {
        try testCoding(
            state: .failed(ViewModelStateCodingTests.viewPaymentOrderInfo, ViewModelStateCodingTestsNSError(payload: "error")),
            errorType: ViewModelStateCodingTestsNSError.self
        )
    }
    
    private func testCoding(state: SwedbankPaySDKViewModel.State) throws {
        try testCoding(state: state, errorType: Never.self)
    }
    
    private func testCoding<Err>(
        state: SwedbankPaySDKViewModel.State,
        errorType: Err.Type
    ) throws where Err: Error, Err: Equatable {
        try testCoding(state: state, userInfoType: Optional<Never>.self, errorType: errorType)
    }
    
    private func testCodingWithCodableUserInfo(state: SwedbankPaySDKViewModel.State) throws {
        try testCoding(state: state, userInfoType: CodableUserInfo.self, errorType: Never.self)
    }
    
    private func testCodingWithNSCodingUserInfo(state: SwedbankPaySDKViewModel.State) throws {
        try testCoding(state: state, userInfoType: ViewModelStateCodingTestsNSCodingUserInfo.self, errorType: Never.self)
    }
    
    private func testCoding<UserInfo, Err>(
        state: SwedbankPaySDKViewModel.State,
        userInfoType: UserInfo.Type,
        errorType: Err.Type
    ) throws where UserInfo: Equatable, Err: Error, Err: Equatable {
        let data = try PropertyListEncoder().encode(state)
        let decoded = try PropertyListDecoder().decode(SwedbankPaySDKViewModel.State.self, from: data)
        try state.assertEquals(other: decoded, userInfoType: userInfoType, errorType: errorType)
    }
    
    enum TestError: Error, Equatable {
        case theError(String)
    }
        
    struct CodableUserInfo: Equatable, Codable {
        var payload: String
    }
}

class ViewModelStateCodingTestsNSCodingUserInfo: NSObject, NSCoding {
    let payload: String
    
    init(payload: String) {
        self.payload = payload
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(payload, forKey: "payload")
    }
    
    required init?(coder: NSCoder) {
        guard let payload = coder.decodeObject(of: NSString.self, forKey: "payload") else {
            return nil
        }
        self.payload = payload as String
    }
    
    override func isEqual(_ object: Any?) -> Bool {
        return (object as? ViewModelStateCodingTestsNSCodingUserInfo)?.payload == payload
    }
}

class ViewModelStateCodingTestsNSError: NSError {
    convenience init(payload: String) {
        self.init(domain: "ViewModelStateCodingTestsNSError", code: 1, userInfo: ["payload": payload])
    }
    
    var payload: String? {
        userInfo["payload"] as? String
    }
}

extension ViewModelStateCodingTests.TestError: Codable {
    init(from decoder: Decoder) throws {
        self = .theError(try decoder.singleValueContainer().decode(String.self))
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .theError(let payload):
            try container.encode(payload)
        }
    }
}
