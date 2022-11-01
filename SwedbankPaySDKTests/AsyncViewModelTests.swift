import Foundation
import XCTest
@testable import SwedbankPaySDK

class AsyncViewModelTests : XCTestCase {
    private let timeout = 15 as TimeInterval
    
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
            if case .identifyingConsumer(let infoOptions, options: _) = $0 {
                if case .v2(let info) = infoOptions {
                    XCTAssertEqual(info.viewConsumerIdentification.absoluteString, TestConstants.viewConsumerSessionLink)
                } else {
                    XCTFail("Using V3 in a V2 context")
                }
                
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
            if case .paying(let info, _, _) = $0 {
                XCTAssertEqual(info.viewPaymentLink.absoluteString, TestConstants.viewPaymentorderLink)
                return true
            } else {
                return false
            }
        }
        viewModel.start(useCheckin: false, configuration: configuration)
        
        waitForExpectations(timeout: timeout, handler: nil)
    }
}
