import Foundation
import XCTest
@testable import SwedbankPaySDK

class ViewModelCodingTests: XCTestCase {
    private let timeout = 5 as TimeInterval
    
    private var configuration: SwedbankPaySDKConfiguration {
        MockMerchantBackend.configuration(for: self)
    }
    
    override func tearDown() {
        MockURLProtocol.reset()
    }
    
    func testIdle() throws {
        try testCoding(vm: makeViewModel())
    }
    
    func testCodableUserData() throws {
        SwedbankPaySDK.registerCodable(CodableUserData.self)
        try testCoding(
            vm: makeViewModel(userData: CodableUserData(payload: "payload")),
            userDataType: CodableUserData.self
        )
    }
    
    func testInitConsumerSession() throws {
        MockURLProtocol.stubBackendUrl(for: self)
        
        try testAwakeAfterDecode(start: { vm in
            vm.start(useCheckin: true, configuration: configuration)
        }, expectedRequestUrl: MockMerchantBackend.absoluteConsumersUrl(for: self), expectedRequestBody: .postJson({
            let countryCodes = $0["shippingAddressRestrictedToCountryCodes"]
            let countryCodesArray = try XCTUnwrap(countryCodes as? [Any])
            let countryCode = countryCodesArray.first
            let countryCodeString = try XCTUnwrap(countryCode as? String)
            XCTAssertEqual(countryCodeString, TestConstants.consumerCountryCode)
        }))
    }
    
    func testIdentifyingConsumer() throws {
        MockURLProtocol.stubBackendUrl(for: self)
        MockURLProtocol.stubConsumers(for: self)
        
        let vm = makeViewModel()
        vm.start(useCheckin: true, configuration: configuration)
        expectState(vm: vm) { state in
            switch state {
            case .identifyingConsumer: return true
            default: return false
            }
        }
        waitForExpectations(timeout: timeout)
        try testCoding(vm: vm)
        
        MockURLProtocol.assertNoUnusedStubs()
    }
    
    func testCreatingPaymentOrder() throws {
        MockURLProtocol.stubBackendUrl(for: self)
        
        try testAwakeAfterDecode(start: { vm in
            vm.start(useCheckin: false, configuration: configuration)
        }, expectedRequestUrl: MockMerchantBackend.absolutePaymentordersUrl(for: self), expectedRequestBody: .postJson({
            let paymentorder = $0["paymentorder"]
            let paymentorderObj = try XCTUnwrap(paymentorder as? [String : Any])
            XCTAssertNotNil(paymentorderObj)
        }))
        
        MockURLProtocol.assertNoUnusedStubs()
    }
    
    func testPaying() throws {
        MockURLProtocol.stubBackendUrl(for: self)
        MockURLProtocol.stubPaymentorders(for: self)

        let vm = makeViewModel()
        vm.start(useCheckin: false, configuration: configuration)
        expectState(vm: vm) { state in
            switch state {
            case .paying: return true
            default: return false
            }
        }
        waitForExpectations(timeout: timeout)
        try testCoding(vm: vm)
        
        MockURLProtocol.assertNoUnusedStubs()
    }
    
    func testComplete() throws {
        let vm = makeViewModel()
        vm.onComplete()
        try testCoding(vm: vm)
    }
    
    func testCanceled() throws {
        let vm = makeViewModel()
        vm.onCanceled()
        try testCoding(vm: vm)
    }
    
    func testFailed() throws {
        SwedbankPaySDK.registerCodable(TestError.self)

        let vm = makeViewModel()
        vm.onFailed(error: TestError.theError)
        try testCoding(vm: vm, errorType: TestError.self)
    }
    
    private func makeViewModel(userData: Any? = nil) -> SwedbankPaySDKViewModel {
        return SwedbankPaySDKViewModel(
            consumer: TestConstants.consumerData,
            paymentOrder: MockMerchantBackend.paymentOrder(for: self),
            userData: userData
        )
    }
    
    private func expectState(vm: SwedbankPaySDKViewModel, predicate: @escaping (SwedbankPaySDKViewModel.State) -> Bool) {
        let expectation = self.expectation(description: "SwedbankPaySDKViewModel reached expected state")
        if predicate(vm.state) {
            expectation.fulfill()
        } else {
            vm.onStateChanged = {
                if predicate(vm.state) {
                    vm.onStateChanged = nil
                    expectation.fulfill()
                }
            }
        }
    }
    
    private func exceriseCoding(vm: SwedbankPaySDKViewModel) throws -> SwedbankPaySDKViewModel {
        let data = try PropertyListEncoder().encode(vm)
        let decoded = try PropertyListDecoder().decode(SwedbankPaySDKViewModel.self, from: data)
        decoded.awakeAfterDecode(configuration: configuration)
        return decoded
    }
    
    private func testCoding(vm: SwedbankPaySDKViewModel) throws {
        try testCoding(vm: vm, errorType: Never.self)
    }
    
    private func testCoding<Err>(
        vm: SwedbankPaySDKViewModel,
        errorType: Err.Type
    ) throws where Err: Error, Err: Equatable {
        try testCoding(vm: vm, userDataType: Optional<Never>.self, errorType: errorType)
    }
    
    private func testCoding<UserData>(
        vm: SwedbankPaySDKViewModel,
        userDataType: UserData.Type
    ) throws where UserData: Equatable {
        try testCoding(vm: vm, userDataType: userDataType, errorType: Never.self)
    }
    
    private func testCoding<UserData, Err>(
        vm: SwedbankPaySDKViewModel,
        userDataType: UserData.Type,
        errorType: Err.Type
    ) throws where UserData: Equatable, Err: Error, Err: Equatable {
        let decoded = try exceriseCoding(vm: vm)
        
        try vm.state.assertEquals(other: decoded.state, userInfoType: Optional<Never>.self, errorType: errorType)
        XCTAssertEqual(vm.consumer, decoded.consumer)
        XCTAssertEqual(vm.paymentOrder, decoded.paymentOrder)
        let userData = try XCTUnwrap(vm.userData as? UserData, "\(String(describing: decoded.userData)) is not an instance of \(userDataType)")
        let otherUserData = try XCTUnwrap(vm.userData as? UserData, "\(String(describing: decoded.userData)) is not an instance of \(userDataType)")
        XCTAssertEqual(userData, otherUserData)
    }
    
    private func testAwakeAfterDecode(
        start: (SwedbankPaySDKViewModel) -> Void,
        expectedRequestUrl: URL,
        expectedRequestBody: ExpectedRequest
    ) throws {
        let vm = makeViewModel()
        
        expectRequest(to: expectedRequestUrl, expectedRequest: expectedRequestBody)
        start(vm)
        
        var expectedRequestError: Error? = nil
        waitForExpectations(timeout: timeout) {
            expectedRequestError = $0
        }
        if let expectedRequestError = expectedRequestError {
            throw expectedRequestError
        }
        
        expectRequest(to: expectedRequestUrl, expectedRequest: expectedRequestBody)
        try testCoding(vm: vm)
        
        waitForExpectations(timeout: timeout)
    }
    
    struct CodableUserData: Equatable, Codable {
        var payload: String
    }
    
    enum TestError: Error, Equatable {
        case theError
    }
}

extension ViewModelCodingTests.TestError: Codable {
    init(from decoder: Decoder) throws {
        self = .theError
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .theError:
            try container.encode(true)
        }
    }
}
