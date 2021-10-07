import Foundation
import XCTest
@testable import SwedbankPaySDK

class ViewModelTests : XCTestCase {
    private let timeout = 5 as TimeInterval
    
    private var viewModel: SwedbankPaySDKViewModel!
    
    override func setUp() {
        viewModel = SwedbankPaySDKViewModel(
            configuration: MockMerchantBackend.configuration(for: self),
            consumerData: TestConstants.consumerData,
            paymentOrder: MockMerchantBackend.paymentOrder(for: self),
            userData: nil
        )
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
        expectRequest(to: MockMerchantBackend.backendUrl(for: self), expectedRequest: .get)
        viewModel.identifyConsumer { _ in }
        waitForExpectations(timeout: timeout, handler: nil)
        MockURLProtocol.assertNoUnusedStubs()
    }
    
    func testItShouldRejectInvalidResponseToBackendUrl() {
        MockURLProtocol.stubJson(url: MockMerchantBackend.backendUrl(for: self), json: [:])
        
        viewModel.identifyConsumer(completion: expectFailure())
        
        waitForExpectations(timeout: timeout, handler: nil)
        MockURLProtocol.assertNoUnusedStubs()
    }
    
    func testItShouldMakePostRequestToConsumersUrl() {
        MockURLProtocol.stubBackendUrl(for: self)
        
        expectRequest(to: MockMerchantBackend.absoluteConsumersUrl(for: self), expectedRequest: .postJson({
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
        MockURLProtocol.stubBackendUrl(for: self)
        MockURLProtocol.stubConsumers(for: self)
        
        viewModel.identifyConsumer(completion: expectSuccess {
            XCTAssertEqual($0.viewConsumerIdentification.absoluteString, TestConstants.viewConsumerSessionLink)
        })
        
        waitForExpectations(timeout: timeout, handler: nil)
        MockURLProtocol.assertNoUnusedStubs()
    }
    
    func testItShouldRejectInvalidResponseToConsumersRequest() {
        MockURLProtocol.stubBackendUrl(for: self)
        MockURLProtocol.stubError(url: MockMerchantBackend.absoluteConsumersUrl(for: self))
        viewModel.identifyConsumer(completion: expectFailure())
        waitForExpectations(timeout: timeout, handler: nil)
        MockURLProtocol.assertNoUnusedStubs()
    }
    
    func testItShouldMakePostRequestToPaymentOrdersUrl() {
        viewModel.consumerProfileRef = TestConstants.consumerProfileRef
        
        MockURLProtocol.stubBackendUrl(for: self)
        expectRequest(to: MockMerchantBackend.absolutePaymentordersUrl(for: self), expectedRequest: .postJson({
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
        MockURLProtocol.stubBackendUrl(for: self)
        MockURLProtocol.stubPaymentorders(for: self)
        
        viewModel.createPaymentOrder(completion: expectSuccess {
            XCTAssertEqual($0.viewPaymentorder.absoluteString, TestConstants.viewPaymentorderLink)
        })
        
        waitForExpectations(timeout: timeout, handler: nil)
        MockURLProtocol.assertNoUnusedStubs()
    }
    
    func testItShouldRejectInvalidResponseToPaymentOrdersRequest() {
        MockURLProtocol.stubBackendUrl(for: self)
        MockURLProtocol.stubError(url: MockMerchantBackend.absolutePaymentordersUrl(for: self))
        viewModel.createPaymentOrder(completion: expectFailure())
        waitForExpectations(timeout: timeout, handler: nil)
        MockURLProtocol.assertNoUnusedStubs()
    }
}
