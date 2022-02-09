import XCTest
@testable import SwedbankPaySDKMerchantBackend

private let defaultTimeout = 30.0
private let initialTimeout = 60.0
private let tapCardOptionTimeout = 10.0
private let scaTimeout = 120.0
private let resultTimeout = 180.0
private let errorResultTimeout = 10.0

private let stateSavingDelay = 5.0

private let retryableActionMaxAttempts = 5

private let noScaCardNumber = "4581097032723517"
private let scaCardNumber = "5226612199533406"
private let expiryDate = "1230"
private let noScaCvv = "111"
private let scaCvv = "268"

private struct NonExistentElementError: Error {
    var element: XCUIElement
}

private func assertExists(_ element: XCUIElement, _ message: String) throws {
    let exists = element.exists
    XCTAssert(exists, message)
    if !exists {
        throw NonExistentElementError(element: element)
    }
}

private func waitAndAssertExists(
    timeout: Double = defaultTimeout,
    _ element: XCUIElement,
    _ message: String
) throws {
    _ = element.waitForExistence(timeout: timeout)
    try assertExists(element, message)
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
    // V3 identification
    private var emailInput: XCUIElement {
        webText(label: "Email")
    }
    private var phoneInput: XCUIElement {
        webText(label: "Mobile number")
    }
    private var nextButton: XCUIElement {
        webView.buttons.element(matching: .init(format: "label BEGINSWITH 'Next'"))
    }
    private var firstNameInput: XCUIElement {
        webText(label: "First name")
    }
    private var lastNameInput: XCUIElement {
        webText(label: "Last name")
    }
    private var addressInput: XCUIElement {
        webText(label: "Address")
    }
    private var zipCodeInput: XCUIElement {
        webText(label: "Zip code")
    }
    private var cityInput: XCUIElement {
        webText(label: "City")
    }
    
    // purchase
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
    
    private func retryUntilTrue(f: () -> Bool) {
        for i in 0..<retryableActionMaxAttempts {
            print("attempt \(i)")
            if f() {
                return
            }
        }
    }
    
    override func setUpWithError() throws {
        app = XCUIApplication()
        
        messageServer = try TestMessageServer()
        let messageList = TestMessageList()
        self.messageList = messageList
        messageServer!.start(onMessage: messageList.append(message:))
        
        app.launchArguments = ["\(messageServer!.port)"]
    }
    
    override func tearDown() {
        app.terminate()
        messageServer?.stop()
    }
    
    private func waitForResult(timeout: Double = resultTimeout) -> TestMessage? {
        print("Waiting \(timeout)s for payment result")
        return messageList.waitForFirst(timeout: timeout)
    }
    
    private func waitForResultAndAssertComplete() {
        let result = waitForResult()
        XCTAssertEqual(result, .complete)
    }
    
    private func waitForResultAndAssertNil() {
        let result = waitForResult(timeout: errorResultTimeout)
        XCTAssertNil(result)
    }
    
    /// Sanity check: Check that a web view is displayed
    func testItShouldDisplayWebView() throws {
        app.launch()
        defer {
            waitForResultAndAssertNil()
        }
        
        try waitAndAssertExists(timeout: initialTimeout, webView, "Web view not found")
    }
    
    /// Sanity check for V3: Check that a web view is displayed
    func testItShouldDisplayWebViewV3() throws {
        app.launchArguments.append("-testV3")
        app.launch()
        defer {
            waitForResultAndAssertNil()
        }
        
        try waitAndAssertExists(timeout: initialTimeout, webView, "Web view not found")
    }
    
    /// Sanity check: Check that error messages are sent through the message channel
    func testItShouldSendErrorMessage() {
        app.launchArguments.append("-testerror")
        app.launch()
        let result = messageList.waitForFirst(timeout: resultTimeout)
        XCTAssertEqual(result, .error(errorMessage: "testerror"), "Unexpected result for error message test: \(String(describing: result))")
    }
    
    private func beginPayerIdentificationV3() throws {
        try waitAndAssertExists(timeout: initialTimeout, webView, "Web view not found")
        
        try waitAndAssertExists(phoneInput, "Phone option not found")
        try waitAndAssertExists(emailInput, "Email option not found")
        
        input(to: emailInput, text: "email@example.com")
        input(to: phoneInput, text: "+46733123456")
        
        try waitAndAssertExists(nextButton, "Next button not found")
        nextButton.tap()
        
        try waitAndAssertExists(firstNameInput, "Name input not found")
        input(to: firstNameInput, text: "Example")
        input(to: lastNameInput, text: "ExamplesSon")
        input(to: addressInput, text: "Example street")
        input(to: zipCodeInput, text: "0001")
        input(to: cityInput, text: "Example city")
        
        nextButton.tap()
    }
    
    private func beginPayment(
        cardNumber: String,
        cvv: String
    ) throws {
        try waitAndAssertExists(timeout: initialTimeout, webView, "Web view not found")
        
        try waitAndAssertExists(timeout: initialTimeout, cardOption, "Card option not found")
        
        retryUntilTrue {
            cardOption.tap()
            return creditCardOption.waitForExistence(timeout: tapCardOptionTimeout)
        }
        try assertExists(creditCardOption, "Credit card option not found")
        creditCardOption.tap()
        
        try waitAndAssertExists(panInput, "PAN input not found")
        input(to: panInput, text: cardNumber)
        
        try waitAndAssertExists(expiryInput, "Expiry date input not found")
        input(to: expiryInput, text: expiryDate)
        
        try waitAndAssertExists(cvvInput, "CVV input not found")
        input(to: cvvInput, text: cvv)
        
        try waitAndAssertExists(payButton, "Pay button not found")
        payButton.tap()
    }
    
    
    
    /// Check that a V3 payment with the new checkin gets the info
    func testV3SucceedsAtPaymentWithCheckin() throws {
        app.launchArguments.append("-testV3")
        app.launchArguments.append("-testCheckin")
        app.launch()
        defer {
            waitForResultAndAssertComplete()
        }
        
        try beginPayerIdentificationV3()
        
        // wait for payerIdentification
        
        //try beginPayment(cardNumber: noScaCardNumber, cvv: noScaCvv)
    }
        
    /// Check that a payment without SCA works
    func testItShouldSucceedAtPaymentWithoutSca() throws {
        app.launch()
        defer {
            waitForResultAndAssertComplete()
        }
        
        try beginPayment(cardNumber: noScaCardNumber, cvv: noScaCvv)
    }
    
    func testItShouldSucceedAtPaymentWithoutScaV3() throws {
        app.launchArguments.append("-testV3")
        app.launch()
        
        defer {
            waitForResultAndAssertComplete()
        }
        
        try beginPayment(cardNumber: noScaCardNumber, cvv: noScaCvv)
    }
    
    /// Check that a payment with SCA works
    func testItShouldSucceedAtPaymentWithSca() throws {
        app.launch()
        defer {
            waitForResultAndAssertComplete()
        }
        
        try beginPayment(cardNumber: scaCardNumber, cvv: scaCvv)
        try waitAndAssertExists(
            timeout: scaTimeout,
            continueButton, "Continue button not found"
        )
        retryUntilTrue {
            continueButton.tap()
            return messageList.waitForFirst(timeout: resultTimeout) != nil
        }
    }
    
    func testItShouldSucceedAtPaymentWithScaV3() throws {
        app.launchArguments.append("-testV3")
        app.launch()
        
        defer {
            waitForResultAndAssertComplete()
        }
        
        try beginPayment(cardNumber: scaCardNumber, cvv: scaCvv)
        try waitAndAssertExists(
            timeout: scaTimeout,
            continueButton, "Continue button not found"
        )
        retryUntilTrue {
            continueButton.tap()
            return messageList.waitForFirst(timeout: resultTimeout) != nil
        }
    }
    
    private func restartAndRestoreState(_ v3: Bool = false) {
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: stateSavingDelay)
        app.terminate()
        app.launchArguments.append("-restore")
        app.launch()
    }
    
    func testItShouldShowWebViewAfterRestoration() throws {
        app.launch()
        defer {
            waitForResultAndAssertNil()
        }
        
        try waitAndAssertExists(timeout: initialTimeout, webView, "Web view not found")
        
        restartAndRestoreState()
        
        try waitAndAssertExists(timeout: initialTimeout, webView, "Web view not found")
    }
    
    func testItShouldShowWebViewAfterRestorationV3() throws {
        app.launchArguments.append("-testV3")
        app.launch()
        
        defer {
            waitForResultAndAssertNil()
        }
        
        try waitAndAssertExists(timeout: initialTimeout, webView, "Web view not found")
        
        restartAndRestoreState(true)
        
        try waitAndAssertExists(timeout: initialTimeout, webView, "Web view not found")
    }
    
    func testItShouldShowPaymentMenuAfterRestoration() throws {
        app.launch()
        defer {
            waitForResultAndAssertNil()
        }
        
        try waitAndAssertExists(timeout: initialTimeout, webView, "Web view not found")
        try waitAndAssertExists(timeout: initialTimeout, cardOption, "Card option not found")
        
        restartAndRestoreState()
        
        try waitAndAssertExists(timeout: initialTimeout, webView, "Web view not found")
        try waitAndAssertExists(timeout: initialTimeout, cardOption, "Card option not found")
    }
    
    func testItShouldShowPaymentMenuAfterRestorationV3() throws {
        app.launchArguments.append("-testV3")
        app.launch()
        
        defer {
            waitForResultAndAssertNil()
        }
        
        try waitAndAssertExists(timeout: initialTimeout, webView, "Web view not found")
        try waitAndAssertExists(timeout: initialTimeout, cardOption, "Card option not found")
        
        restartAndRestoreState(true)
        
        try waitAndAssertExists(timeout: initialTimeout, webView, "Web view not found")
        try waitAndAssertExists(timeout: initialTimeout, cardOption, "Card option not found")
    }
    
    func testItShouldSucceedAtPaymentAfterRestoration() throws {
        app.launch()
        defer {
            waitForResultAndAssertComplete()
        }
        
        try waitAndAssertExists(timeout: initialTimeout, webView, "Web view not found")
        try waitAndAssertExists(timeout: initialTimeout, cardOption, "Card option not found")
        
        restartAndRestoreState()
        
        try beginPayment(cardNumber: noScaCardNumber, cvv: noScaCvv)
    }
    
    func testItShouldSucceedAtPaymentAfterRestorationV3() throws {
        app.launchArguments.append("-testV3")
        app.launch()
        defer {
            waitForResultAndAssertComplete()
        }
        
        try waitAndAssertExists(timeout: initialTimeout, webView, "Web view not found")
        try waitAndAssertExists(timeout: initialTimeout, cardOption, "Card option not found")
        
        restartAndRestoreState(true)
        
        try beginPayment(cardNumber: noScaCardNumber, cvv: noScaCvv)
    }
    
    func testItShouldReportSuccessAfterRestoration() throws {
        app.launch()
        defer {
            waitForResultAndAssertComplete()
        }
        
        try beginPayment(cardNumber: noScaCardNumber, cvv: noScaCvv)
        waitForResultAndAssertComplete()
        
        restartAndRestoreState()
    }
    
    func testItShouldReportSuccessAfterRestorationV3() throws {
        app.launchArguments.append("-testV3")
        app.launch()
        defer {
            waitForResultAndAssertComplete()
        }
        
        try beginPayment(cardNumber: noScaCardNumber, cvv: noScaCvv)
        waitForResultAndAssertComplete()
        
        restartAndRestoreState(true)
    }
}
