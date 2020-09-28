import Foundation
import XCTest
@testable import SwedbankPaySDK

class ViewModelTests : XCTestCase {
    private let timeout = 5 as TimeInterval
    
    private var viewModel: SwedbankPaySDKViewModel!
    
    override func setUp() {
        viewModel = SwedbankPaySDKViewModel()
        viewModel.configuration = TestConstants.configuration
    }
    
    override func tearDown() {
        MockURLProtocol.reset()
    }
        
    private func expectCallback<T>(
        whereAgrumentSatisfies assertions: @escaping (T) -> Void = { _ in }
    ) -> (T) -> Void {
        let invoked = expectation(description: "Callback invoked")
        return { argument in
            invoked.fulfill()
            assertions(argument)
        }
    }
    
    private func expectSuccess<T>(
        whereValueSatisfies assertions: @escaping (T) -> Void = { _ in }
    ) -> (Result<T, Error>) -> Void {
        expectCallback {
            $0.assertSuccess(whereValueSatisfies: assertions)
        }
    }
    private func expectFailure<T>() -> (Result<T, Error>) -> Void {
        expectCallback {
            $0.assertFailure()
        }
    }
    
    func testItShouldMakeGetRequestToBackendUrl() {
        viewModel.consumerData = TestConstants.consumerData
        
        expectRequest(to: TestConstants.backendUrl, expectedRequest: .get)
        viewModel.identifyConsumer { _ in }
        waitForExpectations(timeout: timeout, handler: nil)
        MockURLProtocol.assertNoUnusedStubs()
    }
    
    func testItShouldRejectInvalidResponseToBackendUrl() {
        viewModel.consumerData = TestConstants.consumerData
        
        MockURLProtocol.stubJson(url: TestConstants.backendUrl, json: [:])
        
        viewModel.identifyConsumer(completion: expectFailure())
        
        waitForExpectations(timeout: timeout, handler: nil)
        MockURLProtocol.assertNoUnusedStubs()
    }
    
    func testItShouldMakePostRequestToConsumersUrl() {
        viewModel.consumerData = TestConstants.consumerData
        
        MockURLProtocol.stubBackendUrl()
        
        expectRequest(to: TestConstants.absoluteConsumersUrl, expectedRequest: .postJson({
            let countryCodes = $0["shippingAddressRestrictedToCountryCodes"]
            let countryCodesArray = try XCTUnwrap(countryCodes as? [Any])
            let countryCode = countryCodesArray.first
            let countryCodeString = try XCTUnwrap(countryCode as? String)
            XCTAssertEqual(countryCodeString, TestConstants.consumerCountryCode)
        }))
        viewModel.identifyConsumer { _ in }
        
        waitForExpectations(timeout: timeout, handler: nil)
        MockURLProtocol.assertNoUnusedStubs()
    }
    
    func testItShouldAcceptValidResponseToConsumersRequest() {
        viewModel.consumerData = TestConstants.consumerData

        MockURLProtocol.stubBackendUrl()
        MockURLProtocol.stubConsumers()
        
        viewModel.identifyConsumer(completion: expectSuccess {
            XCTAssertEqual($0.viewConsumerIdentification.absoluteString, TestConstants.viewConsumerSessionLink)
        })
        
        waitForExpectations(timeout: timeout, handler: nil)
        MockURLProtocol.assertNoUnusedStubs()
    }
    
    func testItShouldRejectInvalidResponseToConsumersRequest() {
        viewModel.consumerData = TestConstants.consumerData
        
        MockURLProtocol.stubBackendUrl()
        MockURLProtocol.stubError(url: TestConstants.absoluteConsumersUrl)
        viewModel.identifyConsumer(completion: expectFailure())
        waitForExpectations(timeout: timeout, handler: nil)
        MockURLProtocol.assertNoUnusedStubs()
    }
    
    func testItShouldMakePostRequestToPaymentOrdersUrl() {
        viewModel.paymentOrder = TestConstants.paymentOrder
        viewModel.consumerProfileRef = TestConstants.consumerProfileRef
        
        MockURLProtocol.stubBackendUrl()
        expectRequest(to: TestConstants.absolutePaymentordersUrl, expectedRequest: .postJson({
            let paymentorder = $0["paymentorder"]
            let paymentorderObj = try XCTUnwrap(paymentorder as? [String : Any])
            let payer = paymentorderObj["payer"]
            let payerObj = try XCTUnwrap(payer as? [String : Any])
            let profile = payerObj["consumerProfileRef"]
            let profileString = try XCTUnwrap(profile as? String)
            XCTAssertEqual(profileString, TestConstants.consumerProfileRef)
        }))
        
        viewModel.createPaymentOrder { _ in }
        
        waitForExpectations(timeout: timeout, handler: nil)
        MockURLProtocol.assertNoUnusedStubs()
    }
    
    func testItShouldAcceptValidResponseToPaymentOrdersRequest() {
        viewModel.paymentOrder = TestConstants.paymentOrder
        
        MockURLProtocol.stubBackendUrl()
        MockURLProtocol.stubPaymentorders()
        
        viewModel.createPaymentOrder(completion: expectSuccess {
            XCTAssertEqual($0.viewPaymentorder.absoluteString, TestConstants.viewPaymentorderLink)
        })
        
        waitForExpectations(timeout: timeout, handler: nil)
        MockURLProtocol.assertNoUnusedStubs()
    }
    
    func testItShouldRejectInvalidResponseToPaymentOrdersRequest() {
        viewModel.paymentOrder = TestConstants.paymentOrder

        MockURLProtocol.stubBackendUrl()
        MockURLProtocol.stubError(url: TestConstants.absolutePaymentordersUrl)
        viewModel.createPaymentOrder(completion: expectFailure())
        waitForExpectations(timeout: timeout, handler: nil)
        MockURLProtocol.assertNoUnusedStubs()
    }
}
