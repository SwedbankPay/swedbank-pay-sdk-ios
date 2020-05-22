import Foundation
import XCTest
import Alamofire
@testable import SwedbankPaySDK

class ViewModelIdentifiedConsumerTests : XCTestCase {
    private let timeout = 3 as TimeInterval
    
    private var viewModel: SwedbankPaySDKViewModel!
    
    override func setUp() {
        let sessionConf = URLSessionConfiguration.default
        sessionConf.protocolClasses = [MockURLProtocol.self]
        
        viewModel = SwedbankPaySDKViewModel()
        viewModel.sessionManager = Alamofire.SessionManager(configuration: sessionConf)
        viewModel.setConfiguration(TestConstants.configuration)
    }
    
    override class func tearDown() {
        MockURLProtocol.reset()
    }
    
    private func stubBackendUrl() {
        MockURLProtocol.stubJson(url: TestConstants.backendUrl, json: TestConstants.rootBody)
    }
    
    func testItShouldMakeGetRequestToBackendUrl() {
        expectRequest(to: TestConstants.backendUrl, expectedRequest: .get)
        viewModel.identifyConsumer(TestConstants.backendUrl)
        waitForExpectations(timeout: timeout, handler: nil)
        MockURLProtocol.assertNoUnusedStubs()
    }
    
    func testItShouldRejectInvalidResponseToBackendUrl() {
        MockURLProtocol.stubJson(url: TestConstants.backendUrl, json: [:])
        let success = expectation(description: "identifyConsumer succeeded")
        success.isInverted = true
        let failure = expectation(description: "identifyConsumer failed")
        viewModel.identifyConsumer(TestConstants.backendUrl, successCallback: { _ in
            success.fulfill()
        }, errorCallback: { _ in
            failure.fulfill()
        })
        waitForExpectations(timeout: timeout, handler: nil)
        MockURLProtocol.assertNoUnusedStubs()
    }
    
    func testItShouldMakePostRequestToConsumersUrl() {
        viewModel.setConsumerData(TestConstants.consumerData)
        
        stubBackendUrl()
        
        expectRequest(to: TestConstants.absoluteConsumersUrl, expectedRequest: .postJson({
            let countryCodes = $0["shippingAddressRestrictedToCountryCodes"]
            let countryCodesArray = try XCTUnwrap(countryCodes as? [Any])
            let countryCode = countryCodesArray.first
            let countryCodeString = try XCTUnwrap(countryCode as? String)
            XCTAssertEqual(countryCodeString, TestConstants.consumerCountryCode)
        }))
        viewModel.identifyConsumer(TestConstants.backendUrl)
        waitForExpectations(timeout: timeout, handler: nil)
        MockURLProtocol.assertNoUnusedStubs()
    }
    
    func testItShouldAcceptValidResponseToConsumersRequest() {
        viewModel.setConsumerData(TestConstants.consumerData)
        
        stubBackendUrl()
        MockURLProtocol.stubJson(url: TestConstants.absoluteConsumersUrl, json: TestConstants.consumersBody)
        
        let success = expectation(description: "identifyConsumer succeeded")
        let failure = expectation(description: "identifyConsumer failed")
        failure.isInverted = true
        viewModel.identifyConsumer(TestConstants.backendUrl, successCallback: { operations in
            let viewOp = operations.operations.first { $0.rel == Operation.TypeString.viewConsumerIdentification.rawValue }
            XCTAssertNotNil(viewOp)
            XCTAssertEqual(viewOp?.href, TestConstants.viewConsumerSessionLink)
            success.fulfill()
        }, errorCallback: { problem in
            failure.expectationDescription = "identifyConsumer failed: \(problem)"
            failure.fulfill()
        })
        
        waitForExpectations(timeout: timeout, handler: nil)
        MockURLProtocol.assertNoUnusedStubs()
    }
    
    func testItShouldRejectInvalidResponseToConsumersRequest() {
        viewModel.setConsumerData(TestConstants.consumerData)
        
        stubBackendUrl()
        MockURLProtocol.stubError(url: TestConstants.absoluteConsumersUrl)
        
        let success = expectation(description: "identifyConsumer succeeded")
        success.isInverted = true
        let failure = expectation(description: "identifyConsumer failed")
        viewModel.identifyConsumer(TestConstants.backendUrl, successCallback: { _ in
            success.fulfill()
        }, errorCallback: { _ in
            failure.fulfill()
        })
        waitForExpectations(timeout: timeout, handler: nil)
        MockURLProtocol.assertNoUnusedStubs()
    }
    
    func testItShouldMakePostRequestToPaymentOrdersUrl() {
        viewModel.setPaymentOrder(TestConstants.paymentOrder)
        viewModel.setConsumerProfileRef(TestConstants.consumerProfileRef)
        
        stubBackendUrl()
        expectRequest(to: TestConstants.absolutePaymentordersUrl, expectedRequest: .postJson({
            let paymentorder = $0["paymentorder"]
            let paymentorderObj = try XCTUnwrap(paymentorder as? [String : Any])
            let payer = paymentorderObj["payer"]
            let payerObj = try XCTUnwrap(payer as? [String : Any])
            let profile = payerObj["consumerProfileRef"]
            let profileString = try XCTUnwrap(profile as? String)
            XCTAssertEqual(profileString, TestConstants.consumerProfileRef)
        }))
        
        viewModel.createPaymentOrder(TestConstants.backendUrl)
        
        waitForExpectations(timeout: timeout, handler: nil)
        MockURLProtocol.assertNoUnusedStubs()
    }
    
    func testItShouldAcceptValidResponseToPaymentOrdersRequest() {
        viewModel.setPaymentOrder(TestConstants.paymentOrder)
        
        stubBackendUrl()
        MockURLProtocol.stubJson(url: TestConstants.absolutePaymentordersUrl, json: TestConstants.paymentordersBody)
        
        let success = expectation(description: "createPaymentOrder succeeded")
        let failure = expectation(description: "createPaymentOrder failed")
        failure.isInverted = true
        viewModel.createPaymentOrder(TestConstants.backendUrl, successCallback: { operations in
            let viewOp = operations.operations.first { $0.rel == Operation.TypeString.viewPaymentOrder.rawValue }
            XCTAssertNotNil(viewOp)
            XCTAssertEqual(viewOp?.href, TestConstants.viewPaymentorderLink)
            success.fulfill()
        }, errorCallback: { problem in
            failure.expectationDescription = "createPaymentOrder failed: \(problem)"
            failure.fulfill()
        })
        
        waitForExpectations(timeout: timeout, handler: nil)
        MockURLProtocol.assertNoUnusedStubs()
    }
    
    func testItShouldRejectInvalidResponseToPaymentOrdersRequest() {
        viewModel.setPaymentOrder(TestConstants.paymentOrder)

        stubBackendUrl()
        MockURLProtocol.stubError(url: TestConstants.absolutePaymentordersUrl)
        let success = expectation(description: "createPaymentOrder succeeded")
        success.isInverted = true
        let failure = expectation(description: "createPaymentOrder failed")
        viewModel.createPaymentOrder(TestConstants.backendUrl, successCallback: { _ in
            success.fulfill()
        }, errorCallback: { _ in
            failure.fulfill()
        })
        waitForExpectations(timeout: timeout, handler: nil)
        MockURLProtocol.assertNoUnusedStubs()
    }
}
