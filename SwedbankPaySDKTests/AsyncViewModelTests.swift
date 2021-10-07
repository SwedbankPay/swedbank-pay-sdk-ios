import Foundation
import XCTest
@testable import SwedbankPaySDK

class AsyncViewModelTests : XCTestCase {
    private let timeout = 5 as TimeInterval
    
    private var viewModel: SwedbankPaySDKViewModel!
    
    private var configuration: SwedbankPaySDKConfiguration!
    
    override func setUpWithError() throws {
        viewModel = SwedbankPaySDKViewModel(
            consumer: TestConstants.consumerData,
            paymentOrder: MockMerchantBackend.paymentOrder(for: self),
            userData: nil
        )
        configuration = try TestConfiguration.getAsyncConfigOrSkipTest().sdkConfiguration(for: self)
    }
    
    func testItShouldMoveToIdentifyingConsumerWhenStartedWithUseCheckinTrue() {
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
    }
    
    func testItShouldMoveToPayingWhenStartedWithUseCheckinFalse() {
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
    }
}
