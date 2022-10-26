import XCTest
@testable import SwedbankPaySDKMerchantBackend

private let shortTimeout = 4.0
private let defaultTimeout = 30.0
private let initialTimeout = 60.0
private let tapCardOptionTimeout = 10.0
private let scaTimeout = 120.0
private let scaTimeoutShort = 40.0
private let resultTimeout = 180.0
private let errorResultTimeout = 10.0

private let stateSavingDelay = 5.0

private let retryableActionMaxAttempts = 5

private let noScaCardNumber = "4581097032723517"
private let scaCardNumber = "4547781087013329"
private let oldScaCardNumber = "5226612199533406"
private let scaCardNumber3DS2 = "4000008000000153"
private let otherScaCardNumber = "4761739001010416"

//the new scaCard that always work, but has the strange input: "5226612199533406"
//used to be 3DS but not anymore: "4111111111111111", "4761739001010416",
private let scaCards = ["4111111111111111", "5226612199533406", "4547781087013329"]

private struct NoSCAContinueButtonFound: Error {
    
    var description: String {
        "Could not find the continue button nor the textfield"
    }
}

private let expiryDate = "1233"
private let noScaCvv = "111"
private let scaCvv = "123" //268

//how many configurations can be tested
let paymentTestConfigurations = ["enterprise", "paymentsOnly"]

private struct NonExistentElementError: Error {
    var element: XCUIElement
}
private struct PaymentDidShowError: Error {
    var reason: String
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

// Some buttons can be clicked even if not enabled, but usually its good to wait until they are enabled, so here is a shortcut.
private func delayUnlessEnabled(
    timeout: Double = shortTimeout,
    _ element: XCUIElement
) throws {
    for _ in 0..<25 {
        if element.isEnabled {
            break
        }
        sleep(UInt32(timeout))
    }
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
    private func webTextField(label: String) -> XCUIElement {
        let predicate = NSPredicate(format: "label = %@", argumentArray: [label])
        return webView.textFields.element(matching: predicate)
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
    private var continueAsGuestButton: XCUIElement {
        webView.buttons.element(matching: .init(format: "label CONTAINS[cd] 'proceed'"))
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
    private var testMenuButton: XCUIElement {
        app.buttons.element(matching: .button, identifier: "testMenuButton")
    }
    
    
    // purchase
    private var cardOption: XCUIElement {
        webText(label: "Card")
    }
    private var creditCardOption: XCUIElement {
        webText(label: "Credit")
    }
    private var panInput: XCUIElement {
        let label = "Card number"
        let input = webText(label: label).exists ? webText(label: label) : webTextField(label: label)
        return input
    }
    private var expiryInput: XCUIElement {
        let label = "MM/YY"
        let input = webText(label: label).exists ? webText(label: label) : webTextField(label: "Expiry date MM/YY")
        return input
    }
    private var cvvInput: XCUIElement {
        let label = "CVV"
        let input = webText(label: label).exists ? webText(label: label) : webTextField(label: label)
        return input
    }
    private var payButton: XCUIElement {
        webView.buttons.element(matching: .init(format: "label BEGINSWITH 'Pay '"))
    }
    private var continueButton: XCUIElement {
        webView.buttons.element(matching: .init(format: "label = 'Continue'"))
    }
    private var confirmButton: XCUIElement {
        webView.buttons.element(matching: .init(format: "label = 'Confirm'"))
    }
    
    private var keyboardDoneButton: XCUIElement {
        app.buttons.element(matching: .init(format: "label = 'Done'"))
    }
    private var prefilledCard: XCUIElement {
        webView.staticTexts.element(matching: .init(format: "label CONTAINS[cd] '••••'"))
    }
    
    private func input(to webElement: XCUIElement, text: String) {
        webElement.tap()
        webView.typeText(text)
        if keyboardDoneButton.exists {
            keyboardDoneButton.tap()
        } else {
            keyboardOkButton.tap()
        }
    }
    
    //The new 3DS page
    private var otpTextField: XCUIElement {
        webView.textFields.firstMatch
    }
    
    private var keyboardOkButton: XCUIElement {
        app.buttons.element(matching: .init(format: "label CONTAINS[cd] 'Ok'"))
    }
    
    @discardableResult
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
    }
    
    override func tearDown() {
        app.terminate()
        messageServer?.stop()
    }
    
    private func waitForResult(timeout: Double = resultTimeout) -> TestMessage? {
        print("Waiting \(timeout)s for payment result")
        return messageList.waitForFirst(timeout: timeout)
    }
    
    private func waitForComplete(timeout: Double = initialTimeout) throws {
        print("Waiting \(timeout)s for payment result")
        try messageList.waitForMessage(timeout: timeout, message: .complete)
    }
    
    private func waitFor(_ message: TestMessage, timeout: Double = initialTimeout) throws {
        print("Waiting \(timeout)s for message: \(message)")
        
        try messageList.waitForMessage(timeout: timeout, message: message)
    }
    
    private func waitForResultAndAssertComplete() throws {
        
        try waitForComplete(timeout: resultTimeout)
    }
    
    private func waitForResultAndAssertNil() {
        let result = waitForResult(timeout: errorResultTimeout)
        XCTAssertNil(result)
    }
    
    private func confirmAndWaitForCompletePayment(
        _ element: XCUIElement,
        _ errorMessage: String = "Could not confirm purchase"
    ) throws {
        
        var message:TestMessage? = .didShow
        let result = retryUntilTrue {
            if case .error(_) = message {
                return false
            }
            element.tap()
            message = messageList.waitForFirst(timeout: shortTimeout)
            return message == .complete
        }
        if !result {
            if case .error(_) = message {
                XCTFail(errorMessage)
            } else {
                XCTAssertTrue(messageList.waitForFirst(timeout: defaultTimeout) == .complete, errorMessage)
            }
        }
    }
    
    /// Sanity check: Check that a web view is displayed
    func testItShouldDisplayWebView() throws {
        app.launch()
        try waitAndAssertExists(timeout: initialTimeout, webView, "Web view not found")
        try waitFor(.didShow, timeout: errorResultTimeout)
    }
    
    /// Sanity check for V3: Check that a web view is displayed
    func testItShouldDisplayWebViewV3() throws {
        app.launchArguments.append("-testV3")
        app.launch()
        try waitAndAssertExists(timeout: initialTimeout, webView, "Web view not found")
        try waitFor(.didShow, timeout: errorResultTimeout)
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
    
    // if using V3 for the starter implementation, the users must always provide email + phone
    private func beginPayerIdentificationV3Small() throws {
        try waitAndAssertExists(timeout: initialTimeout, webView, "Web view not found")
        
        try waitAndAssertExists(phoneInput, "Phone option not found")
        try waitAndAssertExists(emailInput, "Email option not found")
        
        input(to: emailInput, text: "email@example.com")
        input(to: phoneInput, text: "+46733123456")
        
        try waitAndAssertExists(nextButton, "Next button not found")
        nextButton.tap()
        
        //Tap continue "only name"
        try waitAndAssertExists(continueAsGuestButton, "Continue as guest button not found")
        
        continueAsGuestButton.tap()
    }
    
    private func beginPayment(
        cardNumber: String,
        cvv: String,
        swipeBeforeCard: Bool = false,
        assertComplete: Bool = true
    ) throws {
        try waitAndAssertExists(timeout: initialTimeout, webView, "Web view not found")
        
        try waitAndAssertExists(timeout: initialTimeout, cardOption, "Card option not found")
        
        retryUntilTrue {
            
            if swipeBeforeCard {
                //swipe up if card isn't found (in V3 it's below the fold)
                //can be made dynamic with: if cardOption.waitForExistence(timeout: 2) == false || creditCardOption.waitForExistence(timeout: 2) == false {
                //but it is tapping the carPay button instead... 
                app.swipeUp()
            }
            
            cardOption.tap()
            let found = creditCardOption.waitForExistence(timeout: tapCardOptionTimeout)
            if !found {
                //this is usually enough
                app.swipeUp()
            }
            return found
        }
        try assertExists(creditCardOption, "Credit card option not found")
        creditCardOption.tap()
        
        try waitAndAssertExists(panInput, "PAN input not found")
        input(to: panInput, text: cardNumber)
        
        try waitAndAssertExists(expiryInput, "Expiry date input not found")
        input(to: expiryInput, text: expiryDate)
        
        try waitAndAssertExists(cvvInput, "CVV input not found")
        input(to: cvvInput, text: cvv)
        
        for _ in 0...6 {
            //wait for one of the buttons
            if confirmButton.exists || payButton.waitForExistence(timeout: 5) {
                break
            }
        }
        let button = confirmButton.exists ? confirmButton : payButton
        try waitAndAssertExists(button, "Pay/continue button not found")
        button.tap()
    }
    
    func waitUntilShown() throws {
        
        try messageList.waitForMessage(timeout: resultTimeout * 2, message: .didShow)
    }
    
    /// Check that a payment without SCA works
    func testItShouldSucceedAtPaymentWithoutSca() throws {
        
        app.launch()
        
        try beginPayment(cardNumber: noScaCardNumber, cvv: noScaCvv)
        try waitForResultAndAssertComplete()
    }
    
    /// Check that a payment with SCA works
    func testItShouldSucceedAtPaymentWithSca() throws {
        app.launch()
        try beginPayment(cardNumber: scaCardNumber, cvv: scaCvv)
        
        try waitAndAssertExists(
            timeout: scaTimeout,
            continueButton, "Continue button not found"
        )
        retryUntilTrue {
            continueButton.tap()
            return messageList.waitForFirst(timeout: resultTimeout) != nil
        }
        try waitForResultAndAssertComplete()
    }
    
    /// Check that a regular payment without checkin works in V3
    func testV3ScaPayment() throws {
        
        var args = [String]()
        for config in paymentTestConfigurations {
            args = ["-configName \(config)", "-testV3", "-testModalController"]
            for card in scaCards {
            
                app.launchArguments.append(contentsOf: args)
                app.launch()
                
                do {
                    try scaPaymentRun(cardNumber: card)
                    return
                } catch {
                    app.terminate()
                }
            }
        }
        
        //all failed so this will also fail...
        app.launchArguments.append(contentsOf: args)
        app.launch()
        
        try scaPaymentRun(cardNumber: scaCards.first!)
    }
    
    func scaPaymentRun(cardNumber: String) throws {
        try waitUntilShown()
        
        // try this again with otherScaCardNumber if failing? No, if service is down it doesn't matter what we do.
        try beginPayment(cardNumber: cardNumber, cvv: scaCvv)
        
        try scaAproveCard()
        //else "Continue button not found"
    }
    
    func scaAproveCard() throws {
        
        if continueButton.waitForExistence(timeout: shortTimeout) {
            retryUntilTrue {
                continueButton.tap()
                return messageList.waitForFirst(timeout: resultTimeout) != nil
            }
        } else if otpTextField.waitForExistence(timeout: shortTimeout) {
            input(to: otpTextField, text: "1234")
        } else {
            throw NoSCAContinueButtonFound()
        }
        
        try waitForResultAndAssertComplete()
    }
    
    /*
    // Not necessary at the moment.
    /// Check that a failing 3ds works as expected
    func testV3ScaFailing() throws {
        
        //let config = "paymentsOnly"
        let config = "enterprise"   //we don't know their api-keys, nonMerchant
        for card in scaCards {
            
            app.launchArguments.append("-configName \(config)")
            app.launchArguments.append("-testV3")
            app.launchArguments.append("-testNonMerchant")
            app.launch()
            
            try waitUntilShown()
            
            // try this again with otherScaCardNumber if failing? No, if service is down it doesn't matter what we do.
            print("testing with \(card)")
            try beginPayment(cardNumber: card, cvv: scaCvv)
            
            
            let expect = expectation(description: "stuck forever")
            waitForExpectations(timeout: 9283747)
            expect.fulfill()
            
            if continueButton.waitForExistence(timeout: defaultTimeout) {
                retryUntilTrue {
                    continueButton.tap()
                    return messageList.waitForFirst(timeout: resultTimeout) != nil
                }
                //waitForResultAndAssertComplete()
                
                
                app.terminate()
                break
            }
        }
    }
     */
    
    /// Check that instrument-mode works in V3 and we can update payments with a new instrument
    func testV3Instruments() throws {
        
        //for config in paymentTestConfigurations {
            let config = "paymentsOnly" //currently our test-enterprise does not have the permission to restrict instruments
            app.launchArguments.append("-configName \(config)")
            app.launchArguments.append("-testV3")
            app.launchArguments.append("-testInstrument")
            app.launch()
            
            try waitUntilShown()
            
            //switch instrument, this calls viewController.updatePaymentOrder(updateInfo: instrument!)
            testMenuButton.tap()
            
            //just wait until instrument select-change
            try waitFor(.instrumentSelected, timeout: resultTimeout)
            
            //start over with next merchant
            app.terminate()
        //}
    }
    
    func testAbortPayment() throws {
        for config in paymentTestConfigurations {
            app.launchArguments.append("-configName \(config)")
            app.launchArguments.append("-testV3")
            app.launchArguments.append("-testAbortPayment")
            app.launch()
            
            try waitUntilShown()
            
            //switch instrument, this calls viewController.abortPayment()
            testMenuButton.tap()
            
            //just wait until instrument select-change
            try waitFor(.canceled, timeout: resultTimeout)
            
            //start over with next merchant
            app.terminate()
        }
    }
    
    // allow the compiler to use hard coded values
    var cardToUse = scaCardNumber
    
    func repeatGenerateUncheduledToken() throws {
        app.launchArguments.append("-testV3")
        app.launchArguments.append("-testVerifyUnscheduledToken")
        app.launch()
        
        try waitUntilShown()
        try beginPayment(cardNumber: cardToUse, cvv: scaCvv)
        try waitAndAssertExists(
            timeout: scaTimeoutShort,
            continueButton, "Continue button not found"
        )
        retryUntilTrue {
            continueButton.tap()
            return messageList.waitForFirst(timeout: resultTimeout) != nil
        }
    }
    
    func testGenerateUncheduledToken() throws {
        
        for config in paymentTestConfigurations {
            app.launchArguments.append("-configName \(config)")
            var success = false
            for _ in 0...3 {
                do {
                    try repeatGenerateUncheduledToken()
                    success = true
                    break
                } catch {
                    print("May be service error, let's try again")
                    app.terminate()
                    //switch card number on the next attempt
                    cardToUse = cardToUse == otherScaCardNumber ? scaCardNumber : otherScaCardNumber
                }
            }
            if !success {
                try repeatGenerateUncheduledToken()
            }
            
            //just wait until payment is verified
            try waitFor(.complete, timeout: resultTimeout)
            
            testMenuButton.tap()
            
            let result = messageList.waitForFirst(timeout: resultTimeout)
            if case .error(errorMessage: let message) = result {
                print("got error message that should be a paymentOrder")
                XCTFail(message)
            } else if case .complete = result {
                print("we did it!")
            }
            else {
                XCTFail("Unknown message after token-tap")
            }
            app.terminate()
        }
    }
    /*
    // verify that the predefined box appears!
    func testOneClickEnterprisePayerReference() throws {
        app.launchArguments.append("-configName enterprise")
        
        app.launchArguments.append("-testV3")
        app.launchArguments.append("-testEnterprisePayerReference")
        app.launch()
        
        try waitUntilShown()
        
        try waitAndAssertExists(timeout: initialTimeout, cardOption, "Card option not found")
        cardOption.tap()
        
        try waitAndAssertExists(timeout: initialTimeout, prefilledCard, "No prefilled cards")
        prefilledCard.firstMatch.tap()
        
        try waitAndAssertExists(timeout: resultTimeout, confirmButton, "payButton not found")
        try delayUnlessEnabled(confirmButton)
        try confirmAndWaitForCompletePayment(confirmButton, "Could not pay with oneClick")
    }
    
    // Make sure we also support ssn directly
    func testOneClickEnterpriseNationalIdentifier() throws {
        
        app.launchArguments.append("-configName enterprise")
        
        app.launchArguments.append("-testV3")
        app.launchArguments.append("-testOneClickPayments")
        app.launch()
        try waitAndAssertExists(timeout: initialTimeout, webView, "Web view not found")
        
        try waitAndAssertExists(timeout: initialTimeout, cardOption, "Card option not found")
        cardOption.tap()
        
        try waitAndAssertExists(timeout: initialTimeout, prefilledCard, "No prefilled cards")
        prefilledCard.firstMatch.tap()
        
        try waitAndAssertExists(timeout: resultTimeout, confirmButton, "payButton not found")
        try confirmAndWaitForCompletePayment(confirmButton, "Could not pay with national identifier")
    }
    */
    
    /*
    func testVipps() throws {
        app.launchArguments.append("-testV3")
        
        app.launch()
        
        try waitUntilShown()
     try waitFor(.canceled, timeout: resultTimeout * 9098098)
        print("Here!")
    }
    */
    
    func testOneClickPaymentsOnly() throws {
        
        app.launchArguments.append("-testV3")
        app.launchArguments.append("-testOneClickPayments")
        app.launch()
        
        try waitUntilShown()
        try beginPayment(cardNumber: scaCardNumber, cvv: scaCvv)
        try waitAndAssertExists(
            timeout: scaTimeoutShort,
            continueButton, "Continue button not found"
        )
        retryUntilTrue {
            continueButton.tap()
            return messageList.waitForFirst(timeout: resultTimeout) != nil
        }
        
        //just wait until payment is verified
        try waitFor(.complete, timeout: resultTimeout)
        
        var complete = false
        // NOTE: SwedbankPay is working on fixing this timing-issue, so this should not happen in the future.
        for _ in 0..<50 {
            //complete-message comes before transmission is done, so we need to wait some undisclosed amount.
            sleep(1)
            
            testMenuButton.tap()
            
            //wait until we have a token and have started a new purchase flow
            do {
                try waitUntilShown()
                complete = true
                break
            } catch {
                print("got error which means its either not done processing or failing: \n\(error)")
                sleep(4)
            }
        }
        if !complete {
            throw "Could not get token for oneClick"
        }
        
        //now it should only show us the purchase button and card-info snippet.
        try waitAndAssertExists(timeout: resultTimeout, payButton, "payButton not found")
        payButton.tap()
        try waitAndAssertExists(timeout: defaultTimeout, continueButton, "Can't find continue button")
        
        retryUntilTrue {
            continueButton.tap()
            return messageList.waitForFirst(timeout: resultTimeout) != nil
        }
    }
    
    private func restartAndRestoreState() {
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: stateSavingDelay)
        app.terminate()
        app.launchArguments.append("-restore")
        //No need to add launch arguments here since the restore-data needs to contain those.
        app.launch()
    }
    
    func testItShouldShowWebViewAfterRestoration() throws {
        app.launch()
        try waitAndAssertExists(timeout: initialTimeout, webView, "Web view not found")
        
        restartAndRestoreState()
        
        try waitAndAssertExists(timeout: initialTimeout, webView, "Web view not found")
        try waitFor(.didShow, timeout: errorResultTimeout)
    }
    
    func testItShouldShowWebViewAfterRestorationV3() throws {
        app.launchArguments.append("-testV3")
        app.launch()
        
        try waitAndAssertExists(timeout: initialTimeout, webView, "Web view not found")
        
        restartAndRestoreState()
        
        try waitAndAssertExists(timeout: initialTimeout, webView, "Web view not found")
        try waitFor(.didShow, timeout: errorResultTimeout)
    }
    
    func testItShouldShowPaymentMenuAfterRestoration() throws {
        app.launch()
        try waitAndAssertExists(timeout: initialTimeout, webView, "Web view not found")
        try waitAndAssertExists(timeout: initialTimeout, cardOption, "Card option not found")
        
        restartAndRestoreState()
        
        try waitAndAssertExists(timeout: initialTimeout, webView, "Web view not found")
        try waitAndAssertExists(timeout: initialTimeout, cardOption, "Card option not found")
        try waitFor(.didShow, timeout: errorResultTimeout)
    }
    
    func testItShouldShowPaymentMenuAfterRestorationV3() throws {
        app.launchArguments.append("-testV3")
        app.launch()
        
        try waitAndAssertExists(timeout: initialTimeout, webView, "Web view not found")
        //try waitAndAssertExists(phoneInput, "Phone option not found")
        
        restartAndRestoreState()
        
        try waitAndAssertExists(timeout: initialTimeout, webView, "Web view not found")
        //try waitAndAssertExists(phoneInput, "Phone option not found")
        
        try waitFor(.didShow, timeout: errorResultTimeout)
    }
    
    func testItShouldSucceedAtPaymentAfterRestoration() throws {
        app.launch()
        try waitAndAssertExists(timeout: initialTimeout, webView, "Web view not found")
        try waitAndAssertExists(timeout: initialTimeout, cardOption, "Card option not found")
        
        restartAndRestoreState()
        
        try beginPayment(cardNumber: noScaCardNumber, cvv: noScaCvv)
        try waitFor(.complete)
    }
    
    func testItShouldSucceedAtPaymentAfterRestorationV3() throws {
        app.launchArguments.append("-testV3")
        app.launch()
        try waitAndAssertExists(timeout: initialTimeout, webView, "Web view not found")
        //try waitAndAssertExists(phoneInput, "Phone option not found")
        
        restartAndRestoreState()
        
        try waitUntilShown()
        
        // enter payer address and wait for payerIdentification
        //try beginPayerIdentificationV3Small()
        
        try beginPayment(cardNumber: noScaCardNumber, cvv: noScaCvv)
        try waitFor(.complete)
    }
    
    func testItShouldReportSuccessAfterRestoration() throws {
        app.launch()
        try beginPayment(cardNumber: noScaCardNumber, cvv: noScaCvv)
        try waitForResultAndAssertComplete()
        
        restartAndRestoreState()
        try waitFor(.complete)
    }
    
    func testItShouldReportSuccessAfterRestorationV3() throws {
        app.launchArguments.append("-testV3")
        app.launch()
        try waitUntilShown()
        
        //try beginPayerIdentificationV3Small()
        
        try beginPayment(cardNumber: noScaCardNumber, cvv: noScaCvv)
        try waitForResultAndAssertComplete()
        
        restartAndRestoreState()
        try waitFor(.complete)
    }
    
    
    /* V3 has no checkin - so wait with this
    /// Check that a V3 payment with the new checkin gets the info
    func testV3PaymentWithCheckin() throws {
        app.launchArguments.append("-testV3")
        app.launchArguments.append("-testCheckin")
        app.launch()
        defer {
            //This usually takes a bit more time than the other tests.
            XCTAssertTrue(waitForComplete(timeout: 300), "Could not complete payment in time")
        }
        
        try waitUntilShown()
        
        // enter payer address and wait for payerIdentification
        try beginPayerIdentificationV3()
        
        // then wait again until checkout is reloaded
        try waitUntilShown()
        
        //now begin payment
        try beginPayment(cardNumber: noScaCardNumber, cvv: noScaCvv, swipeBeforeCard: true)
        
        //building test, just wait until all is done
        //let exp = expectation(description: "waiter")
        //waitForExpectations(timeout: 90000, handler: nil)
    }
    
    
    /// Check that a V3 payment with the new checkin gets the info - even when restoring
    func testV3PaymentWithCheckinAfterResoration() throws {
        app.launchArguments.append("-testV3")
        app.launchArguments.append("-testCheckin")
        app.launch()
        defer {
            //This usually takes a bit more time than the other tests.
            
            XCTAssertTrue(waitForComplete(timeout: 300), "Could not complete payment in time")
        }
        
        try waitUntilShown()
        
        // enter payer address and wait for payerIdentification
        try beginPayerIdentificationV3()
        
        // then wait again until checkout is reloaded
        try waitUntilShown()
        restartAndRestoreState()
        
        //now begin payment
        try beginPayment(cardNumber: noScaCardNumber, cvv: noScaCvv, swipeBeforeCard: true)
        
        //building test, just wait until all is done
        //let exp = expectation(description: "waiter")
        //waitForExpectations(timeout: 90000, handler: nil)
    }
        
     */
}
