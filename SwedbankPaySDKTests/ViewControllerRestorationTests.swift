import XCTest
import SwedbankPaySDK

private let restorationIdentifier = "ViewControllerRestorationTests.viewController"

class ViewControllerRestorationTests: SwedbankPaySDKControllerTestCase {
    private let timeout = 5 as TimeInterval
    
    override func setUp() {
        super.setUp()
        SwedbankPaySDKController.defaultConfiguration = MockMerchantBackend.configuration(for: self)
        viewController = SwedbankPaySDKController()
        viewController.restorationIdentifier = restorationIdentifier
    }
    override func tearDown() {
        SwedbankPaySDKController.defaultConfiguration = nil
        super.tearDown()
    }
    
    func testItShouldRestoreWithoutCrashing() throws {
        startPayment(withCheckin: false)
        
        try exerciseRestoration()
    }
    
    func testItShouldShowViewConsumerIdentificationPage() throws {
        MockURLProtocol.stubBackendUrl(for: self)
        MockURLProtocol.stubConsumers(for: self)
        
        startPayment(withCheckin: true)
        waitForWebViewLoaded()
        
        expectViewConsumerIdentificationPageInWebView()
        waitForExpectations(timeout: timeout, handler: nil)
        
        try exerciseRestoration()
        waitForWebViewLoaded()
        
        expectViewConsumerIdentificationPageInWebView()
        waitForExpectations(timeout: timeout, handler: nil)
        
        MockURLProtocol.assertNoUnusedStubs()
    }
    
    func testItShouldShowViewPaymentorderPage() throws {
        MockURLProtocol.stubBackendUrl(for: self)
        MockURLProtocol.stubPaymentorders(for: self)
        
        startPayment(withCheckin: false)
        waitForWebViewLoaded()
        
        expectViewPaymentorderPageInWebView()
        waitForExpectations(timeout: timeout, handler: nil)
        
        try exerciseRestoration()
        waitForWebViewLoaded()
        
        expectViewPaymentorderPageInWebView()
        waitForExpectations(timeout: timeout, handler: nil)
        
        MockURLProtocol.assertNoUnusedStubs()
    }
    
    private func startPayment(withCheckin: Bool) {
        viewController.startPayment(
            withCheckin: withCheckin,
            consumer: withCheckin ? TestConstants.consumerData : nil,
            paymentOrder: MockMerchantBackend.paymentOrder(for: self),
            userData: nil
        )
    }
    
    private func exerciseRestoration() throws {
        let encoder = NSKeyedArchiver(requiringSecureCoding: false)
        viewController.encodeRestorableState(with: encoder)
        encoder.finishEncoding()
        
        let decoder = try NSKeyedUnarchiver(forReadingFrom: encoder.encodedData)
        decoder.requiresSecureCoding = false
        let restoredViewController = try XCTUnwrap(SwedbankPaySDKController.viewController(
            withRestorationIdentifierPath: [restorationIdentifier],
            coder: decoder
        ))
        
        let restoredSdkController = try XCTUnwrap(restoredViewController as? SwedbankPaySDKController)
        restoredViewController.decodeRestorableState(with: decoder)
        restoredSdkController.applicationFinishedRestoringState()
        
        replaceViewController(viewController: restoredSdkController)
    }
}
