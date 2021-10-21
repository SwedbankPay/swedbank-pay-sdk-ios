import Foundation
import XCTest
@testable import SwedbankPaySDK

class ViewModelTests : XCTestCase {
    private let timeout = 5 as TimeInterval
    
    private var viewModel: SwedbankPaySDKViewModel!
    
    private var configuration: SwedbankPaySDKConfiguration {
        MockMerchantBackend.configuration(for: self)
    }
    
    override func setUp() {
        viewModel = SwedbankPaySDKViewModel(
            consumer: TestConstants.consumerData,
            paymentOrder: MockMerchantBackend.paymentOrder(for: self),
            userData: nil
        )
    }
    
    override func tearDown() {
        MockURLProtocol.reset()
    }
    
    private func expectFailure() {
        expectState(viewModel: viewModel) {
            if case .failed = $0 {
                return true
            } else {
                return false
            }
        }
    }
    
    func testItShouldMakeGetRequestToBackendUrl() {
        expectRequest(to: MockMerchantBackend.backendUrl(for: self), expectedRequest: .get)
        viewModel.start(useCheckin: true, configuration: configuration)
        waitForExpectations(timeout: timeout, handler: nil)
        MockURLProtocol.assertNoUnusedStubs()
    }
    
    func testItShouldRejectInvalidResponseToBackendUrl() {
        MockURLProtocol.stubJson(url: MockMerchantBackend.backendUrl(for: self), json: [:])
        
        expectFailure()
        viewModel.start(useCheckin: true, configuration: configuration)
                
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
        viewModel.start(useCheckin: true, configuration: configuration)
        
        waitForExpectations(timeout: timeout, handler: nil)
        MockURLProtocol.assertNoUnusedStubs()
    }
    
    func testItShouldAcceptValidResponseToConsumersRequest() {
        MockURLProtocol.stubBackendUrl(for: self)
        MockURLProtocol.stubConsumers(for: self)
        
        expectState(viewModel: viewModel) {
            if case .identifyingConsumer(let info) = $0 {
                XCTAssertEqual(info.viewConsumerIdentification.absoluteString, TestConstants.viewConsumerSessionLink)
                return true
            } else {
                return false
            }
        }
        viewModel.start(useCheckin: true, configuration: configuration)
        
        waitForExpectations(timeout: timeout, handler: nil)
        MockURLProtocol.assertNoUnusedStubs()
    }
    
    func testItShouldRejectInvalidResponseToConsumersRequest() {
        MockURLProtocol.stubBackendUrl(for: self)
        MockURLProtocol.stubError(url: MockMerchantBackend.absoluteConsumersUrl(for: self))
        
        expectFailure()
        viewModel.start(useCheckin: true, configuration: configuration)

        waitForExpectations(timeout: timeout, handler: nil)
        MockURLProtocol.assertNoUnusedStubs()
    }
    
    func testItShouldMakePostRequestToPaymentOrdersUrl() {
        MockURLProtocol.stubBackendUrl(for: self)
        
        expectRequest(to: MockMerchantBackend.absolutePaymentordersUrl(for: self), expectedRequest: .postJson({
            let paymentorder = $0["paymentorder"]
            let paymentorderObj = try XCTUnwrap(paymentorder as? [String : Any])
            XCTAssertNotNil(paymentorderObj)
        }))
        viewModel.start(useCheckin: false, configuration: configuration)
                
        waitForExpectations(timeout: timeout, handler: nil)
        MockURLProtocol.assertNoUnusedStubs()
    }
    
    func testItShouldMakePostRequestToPaymentOrdersUrlAfterContinueWithConsumerProfileRef() {
        MockURLProtocol.stubBackendUrl(for: self)
        MockURLProtocol.stubConsumers(for: self)
        
        let isIdentifyingConsumer = expectState(viewModel: viewModel) {
            if case .identifyingConsumer = $0 {
                return true
            } else {
                return false
            }
        }
        viewModel.start(useCheckin: true, configuration: configuration)
        wait(for: [isIdentifyingConsumer], timeout: timeout)
        
        expectRequest(to: MockMerchantBackend.absolutePaymentordersUrl(for: self), expectedRequest: .postJson({
            let paymentorder = $0["paymentorder"]
            let paymentorderObj = try XCTUnwrap(paymentorder as? [String : Any])
            XCTAssertNotNil(paymentorderObj)
            let payer = paymentorderObj["payer"]
            let payerObj = try XCTUnwrap(payer as? [String : Any])
            let profile = payerObj["consumerProfileRef"]
            let profileString = try XCTUnwrap(profile as? String)
            XCTAssertEqual(profileString, TestConstants.consumerProfileRef)
        }))
        viewModel.continue(consumerProfileRef: TestConstants.consumerProfileRef)
        
        waitForExpectations(timeout: timeout, handler: nil)
        MockURLProtocol.assertNoUnusedStubs()
    }
    
    
    func testItShouldAcceptValidResponseToPaymentOrdersRequest() {
        MockURLProtocol.stubBackendUrl(for: self)
        MockURLProtocol.stubPaymentorders(for: self)
        
        expectState(viewModel: viewModel) {
            if case .paying(let info, _) = $0 {
                XCTAssertEqual(info.viewPaymentorder.absoluteString, TestConstants.viewPaymentorderLink)
                return true
            } else {
                return false
            }
        }
        viewModel.start(useCheckin: false, configuration: configuration)
        
        waitForExpectations(timeout: timeout, handler: nil)
        MockURLProtocol.assertNoUnusedStubs()
    }
    
    func testItShouldRejectInvalidResponseToPaymentOrdersRequest() {
        MockURLProtocol.stubBackendUrl(for: self)
        MockURLProtocol.stubError(url: MockMerchantBackend.absolutePaymentordersUrl(for: self))
        
        expectFailure()
        viewModel.start(useCheckin: false, configuration: configuration)
        
        waitForExpectations(timeout: timeout, handler: nil)
        MockURLProtocol.assertNoUnusedStubs()
    }
}
