import XCTest

private let defaultTimeout = 30.0
private let initialTimeout = 60.0
private let tapCardOptionTimeout = 10.0
private let scaTimeout = 120.0
private let resultTimeout = 180.0

private let stateSavingDelay = 5.0

private let retryableActionMaxAttempts = 5

private let noScaCardNumber = "4925000000000004"
private let scaCardNumber = "4761739001010416"
private let expiryDate = "1230"
private let noScaCvv = "111"
private let scaCvv = "268"

private func waitAndAssertExists(
    timeout: Double = defaultTimeout,
    _ element: XCUIElement,
    _ message: String
) {
    return XCTAssert(element.waitForExistence(timeout: timeout), message)
}

class SwedbankPaySDKUITests: XCTestCase {
    private var messageServer: TestMessageServer?
    private var messageList: TestMessageList!
    
    private var app: XCUIApplication!
    
    private var webView: XCUIElement {
        app.webViews.firstMatch
    }
    private func webText(label: String) -> XCUIElement {
        let predicate = NSPredicate(format: "label = %@", argumentArray: [label])
        return webView.staticTexts.element(matching: predicate)
    }
    private func assertZeroOrOne(elements: [XCUIElement]) -> XCUIElement? {
        XCTAssert(elements.count <= 1)
        return elements.first
    }
    private var cardOption: XCUIElement {
        webText(label: "Card")
    }
    private var creditCardOption: XCUIElement {
        webText(label: "Credit")
    }
    private var panInput: XCUIElement {
        webText(label: "Card number")
    }
    private var expiryInput: XCUIElement {
        webText(label: "MM/YY")
    }
    private var cvvInput: XCUIElement {
        webText(label: "CVV")
    }
    private var payButton: XCUIElement {
        webView.buttons.element(matching: .init(format: "label BEGINSWITH 'Pay '"))
    }
    private var continueButton: XCUIElement {
        webView.buttons.element(matching: .init(format: "label = 'Continue'"))
    }
    
    private var keyboardDoneButton: XCUIElement {
        app.buttons.element(matching: .init(format: "label = 'Done'"))
    }
    
    private func input(to webElement: XCUIElement, text: String) {
        webElement.tap()
        webView.typeText(text)
        keyboardDoneButton.tap()
    }
    
    private func retryUntilTrue(f: () -> Bool) -> Bool {
        for i in 0..<retryableActionMaxAttempts {
            print("attempt \(i)")
            if f() {
                return true
            }
        }
        return false
    }
    
    override func setUpWithError() throws {
        app = XCUIApplication()
        
        messageServer = try TestMessageServer()
        let messageList = TestMessageList()
        self.messageList = messageList
        messageServer!.start(onMessage: messageList.append(message:))
        
        app.launchArguments = ["\(messageServer!.port)"]
        app.launch()
    }
    
    override func tearDown() {
        app.terminate()
        messageServer?.stop()
    }
    
    /// Sanity check: Check that a web view is displayed
    func testItShouldDisplayWebView() {
        waitAndAssertExists(timeout: initialTimeout, webView, "Web view not found")
    }
    
    private func beginPayment(
        cardNumber: String,
        cvv: String
    ) throws {
        waitAndAssertExists(timeout: initialTimeout, webView, "Web view not found")
        
        waitAndAssertExists(timeout: initialTimeout, cardOption, "Card option not found")
        
        XCTAssert(retryUntilTrue {
            cardOption.tap()
            return creditCardOption.waitForExistence(timeout: tapCardOptionTimeout)
        }, "Credit card option not found")
        creditCardOption.tap()
        
        waitAndAssertExists(panInput, "PAN input not found")
        input(to: panInput, text: cardNumber)
        
        waitAndAssertExists(expiryInput, "Expiry date input not found")
        input(to: expiryInput, text: expiryDate)
        
        waitAndAssertExists(cvvInput, "CVV input not found")
        input(to: cvvInput, text: cvv)
        
        waitAndAssertExists(payButton, "Pay button not found")
        payButton.tap()
    }
    
    private func waitForPaymentComplete() throws {
        print("Waiting \(resultTimeout)s for payment to complete")
        let result = try messageList.poll(timeout: resultTimeout)
        XCTAssertEqual(result, .complete, "Payment was not successful: \(result)")
    }
        
    /// Check that a payment without SCA works
    func testItShouldSucceedAtPaymentWithoutSca() throws {
        try beginPayment(cardNumber: noScaCardNumber, cvv: noScaCvv)
        try waitForPaymentComplete()
    }
    
    /// Check that a payment with SCA works
    func testItShouldSucceedAtPaymentWithSca() throws {
        try beginPayment(cardNumber: scaCardNumber, cvv: scaCvv)
        waitAndAssertExists(
            timeout: scaTimeout,
            continueButton, "Continue button not found"
        )
        XCTAssert(retryUntilTrue {
            continueButton.tap()
            return (try? waitForPaymentComplete()) != nil
        }, "completion timeout")
    }
    
    private func restartAndRestoreState() {
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: stateSavingDelay)
        app.terminate()
        app.launchArguments.append("-restore")
        app.launch()
    }
    
    func testItShouldShowWebViewAfterRestoration() {
        waitAndAssertExists(timeout: initialTimeout, webView, "Web view not found")
        
        restartAndRestoreState()
        
        waitAndAssertExists(timeout: initialTimeout, webView, "Web view not found")
    }
    
    func testItShouldShowPaymentMenuAfterRestoration() {
        waitAndAssertExists(timeout: initialTimeout, webView, "Web view not found")
        waitAndAssertExists(timeout: initialTimeout, cardOption, "Card option not found")
        
        restartAndRestoreState()
        
        waitAndAssertExists(timeout: initialTimeout, webView, "Web view not found")
        waitAndAssertExists(timeout: initialTimeout, cardOption, "Card option not found")
    }
    
    func testItShouldSucceedAtPaymentAfterRestoration() throws {
        waitAndAssertExists(timeout: initialTimeout, webView, "Web view not found")
        waitAndAssertExists(timeout: initialTimeout, cardOption, "Card option not found")
        
        restartAndRestoreState()
        
        try beginPayment(cardNumber: noScaCardNumber, cvv: noScaCvv)
        try waitForPaymentComplete()
    }
    
    func testItShouldReportSuccessAfterRestoration() throws {
        try beginPayment(cardNumber: noScaCardNumber, cvv: noScaCvv)
        try waitForPaymentComplete()
        
        restartAndRestoreState()
        
        try waitForPaymentComplete()
    }
}
