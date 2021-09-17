import Foundation
import XCTest
@testable import SwedbankPaySDK

class AsyncViewModelTests : XCTestCase {
    private let timeout = 5 as TimeInterval
    
    private var viewModel: SwedbankPaySDKViewModel!
    
    override func setUpWithError() throws {
        let configuration = try TestConfiguration.getAsyncConfigOrSkipTest().sdkConfiguration
        viewModel = SwedbankPaySDKViewModel(
            configuration: configuration,
            consumerData: TestConstants.consumerData,
            paymentOrder: TestConstants.paymentOrder,
            userData: nil
        )
    }
    
    private func expectSuccess<T>(
        whereValueSatisfies assertions: @escaping (T) -> Void = { _ in }
    ) -> (Result<T, Error>) -> Void {
        let invoked = expectation(description: "Callback invoked")
        return {
            invoked.fulfill()
            $0.assertSuccess(whereValueSatisfies: assertions)
        }
    }
    
    func testIdentifyConsumerShouldSucceed() {
        viewModel.identifyConsumer(completion: expectSuccess {
            XCTAssertEqual($0.viewConsumerIdentification.absoluteString, TestConstants.viewConsumerSessionLink)
        })
        
        waitForExpectations(timeout: timeout, handler: nil)
    }
    
    func testCreatePaymentOrderShouldSucceed() {
        viewModel.createPaymentOrder(completion: expectSuccess {
            XCTAssertEqual($0.viewPaymentorder.absoluteString, TestConstants.viewPaymentorderLink)
        })
        
        waitForExpectations(timeout: timeout, handler: nil)
    }
}
