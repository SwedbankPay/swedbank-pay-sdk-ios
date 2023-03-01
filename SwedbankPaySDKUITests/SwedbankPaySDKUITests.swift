import XCTest
@testable import SwedbankPaySDKMerchantBackend

//github is slow, timeout may never be less than 10.
private let shortTimeout = 10.0
private let defaultTimeout = 30.0
private let initialTimeout = 60.0
private let tapCardOptionTimeout = 10.0
private let scaTimeout = 120.0
private let scaTimeoutShort = 40.0
private let resultTimeout = 180.0
private let errorResultTimeout = 10.0

private let stateSavingDelay = 5.0

private let retryableActionMaxAttempts = 5
private let ssn = "199710202392"

private let noScaCardNumber = "4581099940323133"
private let scaCardNumber = "4547781087013329"
private let scaMasterCardNumber = "5226612199533406"    //5453010000084616
private let scaCardNumber3DS2 = "4000008000000153"
private let otherScaCardNumber = "4761739001010416"
private let ccaV2CardNumbers = [scaMasterCardNumber, "4761739001010416"]

//used to be 3DS but not anymore: "4111111111111111",
private let scaCards = ["4547781087013329", "5453010000084616", "4761739001010416",
                        "4581097032723517", "4000008000000153",
                        scaMasterCardNumber]

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

extension XCUIElement {
    //Sometimes buttons can't be tapped due to being reported as non-hittable
    func forceTapElement() {
        if self.isHittable {
            self.tap()
        }
        else {
            print("Force hit")
            let coordinate: XCUICoordinate = self.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            coordinate.tap()
        }
    }
}

/// Note that XCUIElements is never equal to anything, not themselves even
@discardableResult
private func waitForOne(_ elements: [XCUIElement], _ timeout: Double = defaultTimeout,
                        errorMessage: String) throws -> XCUIElement {
    let start = Date()
    while start.timeIntervalSinceNow > -timeout {
        for element in elements where element.waitForExistence(timeout: 0.2) {
            return element
        }
    }
    throw errorMessage
}

/// Wait until all elements are gone
private func waitUntilGone(_ elements: [XCUIElement], _ timeout: Double = defaultTimeout,
                           errorMessage: String) throws {
    let start = Date()
    
    for element in elements {
        while element.exists && start.timeIntervalSinceNow > -timeout {
            usleep(200)
        }
        if element.exists {
            throw errorMessage
        }
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
        //.init(format: "label CONTAINS[cd] 'proceed'"))
        let predicate = NSPredicate(format: "label = %@", argumentArray: [label])
        return webView.staticTexts.element(matching: predicate)
    }
    private func webTextField(label: String? = nil, contains: String? = nil, identifier: String? = nil) -> XCUIElement {
        
        let predicate: NSPredicate
        if let label {
            predicate = NSPredicate(format: "label = %@", argumentArray: [label])
        } else if let contains {
            predicate = NSPredicate(format: "label CONTAINS[cd] %@", argumentArray: [contains])
        } else if let identifier {
            predicate = NSPredicate(format: "identifier = %@", argumentArray: [identifier])
        } else {
            fatalError("Missing argument")
        }
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
    private var ssnInput: XCUIElement {
        let predicate = NSPredicate(format: "label CONTAINS[cd] 'Personal identi'")
        return webView.textFields.element(matching: predicate)
    }
    private var saveCredentialsButton: XCUIElement {
        let predicate = NSPredicate(format: "label CONTAINS[cd] 'Save my credentials'")
        return webView.buttons.element(matching: predicate)
    }
    private var addAnotherCardLink: XCUIElement {
        webView.links.contains(label: "add another card")
    }
    
    private var anyPrefilledCard: XCUIElement {
        let predicate = NSPredicate(format: "label CONTAINS[cd] '•••• '") //3329
        return webView.buttons.element(matching: predicate).firstMatch
    }
    
    private func prefilledCard(_ card: String) -> XCUIElement {
        let start = card.index(card.endIndex, offsetBy: -4)
        let pattern = "•••• " + String(card[start..<card.endIndex])
        return webView.buttons.contains(label: pattern)
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
    
    private func expiryInput() throws -> XCUIElement {
        
        return try waitForOne([webText(label: "MM/YY"), webTextField(label: "expiryInput"),
                               webTextField(identifier: "expiryInput"),
                           webTextField(contains: "Expiry date MM/YY")],
                              errorMessage: "Could not find expiry input (MM/YY")
    }
    
    private func cvvInput() throws -> XCUIElement {
        let label = "CVV"
        return try waitForOne([webTextField(label: "cvcInput"), webTextField(label: "cccvc"), webText(label: label), webTextField(label: label)], errorMessage: "CVV input not found!")
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
    
    private func input(to webElement: XCUIElement, text: String, waitForOk: Bool = false) {
        _ = webElement.waitForExistence(timeout: 5)
        webElement.tap()
        webView.typeText(text)
        if keyboardOkButton.exists || (waitForOk && keyboardOkButton.waitForExistence(timeout: 2)) {
            print("Found keyboardOkButton, force tap")
            keyboardOkButton.forceTapElement()
        } else {
            if waitForOk {
                //This happens from time to time, then there should be a Done key instead
                print("Did not find Ok button")
                if !keyboardDoneButton.exists {
                    keyboardOkButton.tap()
                    return
                }
            }
            if !keyboardDoneButton.exists {
                print("No 'done' keyboard button")
            }
            print("Found keyboardDoneButton, force tap")
            keyboardDoneButton.forceTapElement()
        }
    }
    
    //The new 3DS page
    private var otpTextField: XCUIElement {
        webView.textFields.firstMatch
    }
    //cannot find this!
    private var whitelistThisMerchant: XCUIElement {
        webView.checkBoxes.firstMatch
    }
    
    private var keyboardOkButton: XCUIElement {
        app.buttons.element(matching: .init(format: "label CONTAINS[cd] 'Ok'"))
    }
    private var unknownErrorMessage: XCUIElement {
        webView.staticTexts.element(matching: .init(format: "label CONTAINS[cd] 'something went wrong'"))
    }
    private var successMessage: XCUIElement {
        webView.staticTexts.element(matching: .init(format: "label CONTAINS[cd] 'Done!'"))
    }
    
    @discardableResult
    private func retryUntilTrue(closure: () throws -> Bool) rethrows -> Bool {
        for _ in 0..<retryableActionMaxAttempts where try closure() {
            return true
        }
        return false
    }
    private func retryUntilSuccess(closure: () throws -> Void ) throws {
        for _ in 0..<retryableActionMaxAttempts-1 {
            do {
                try closure()
                return
            } catch {
                //no action
            }
        }
        try closure()
    }
    
    private func waitUntilShown() throws {
        
        try messageList.waitForMessage(timeout: resultTimeout * 2, message: .didShow)
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
        print("Waiting \(timeout)s for payment complete")
        try messageList.waitForMessage(timeout: timeout, message: .complete)
    }
    
    private func waitFor(_ message: TestMessage, timeout: Double = initialTimeout) throws {
        print("Waiting \(timeout)s for message: \(message)")
        
        try messageList.waitForMessage(timeout: timeout, message: message)
    }
    
    private func waitForResultAndAssertComplete() throws {
        
        try waitForResponseOrFailure(resultTimeout)
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
        let result = try retryUntilTrue {
            if case .error(_) = message {
                return false
            }
            if !element.exists {
                throw errorMessage
            }
            element.tap()
            message = messageList.waitForFirst(timeout: shortTimeout)
            return message == .complete
        }
        if !result {
            if case .error(_) = message {
                throw errorMessage
            } else {
                if messageList.waitForFirst(timeout: defaultTimeout) != .complete {
                    throw errorMessage
                }
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
    
    private func beginPayment(cardNumber: String, cvv: String,
                              swipeBeforeCard: Bool = false, assertComplete: Bool = true) throws {
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
        try performPayment(cardNumber: cardNumber, cvv: cvv)
    }
    
    private func performPayment(cardNumber: String, cvv: String) throws {
        
        try assertExists(creditCardOption, "Credit card option not found")
        creditCardOption.tap()
        
        try waitAndAssertExists(panInput, "PAN input not found")
        input(to: panInput, text: cardNumber)
        
        let expiryInput = try expiryInput()
        input(to: expiryInput, text: expiryDate)
        
        let cvvInput = try cvvInput()
        input(to: cvvInput, text: cvv)
        
        for _ in 0...6 {
            //wait for one of the buttons
            if confirmButton.exists || payButton.waitForExistence(timeout: 5) {
                break
            }
        }
        
        //Sorry for this ugly code, my hands are tied due to linting.
        let button = try waitForOne(
            [confirmButton, payButton],
            errorMessage: "Could not find confirm nor pay button within beginPayment")
        try waitAndAssertExists(button, "Pay/continue button not found")
        button.tap()
    }
    
    /// Check that a payment without SCA works
    func testItShouldSucceedAtPaymentWithoutSca() throws {
        
        app.launch()
        
        try beginPayment(cardNumber: noScaCardNumber, cvv: noScaCvv)
        try waitForResultAndAssertComplete()
    }
    
    /// Check that a payment with SCA v2 works
    func testItShouldSucceedAtPaymentWithSca() throws {
        
        try rerunXTimesWithConfigs(scaCards.count) { index in
            
            try scaPaymentRun(cardNumber: scaCards[index])
        }
    }
    
    /// Check that a regular payment without checkin works in V3
    /// Temporarily disabled since sca-cards doesn't work anymore
    func testV3ScaPayment() throws {
        
        app.launchArguments.append(contentsOf: ["-testV3", "-testModalController"])
        try rerunXTimesWithConfigs(scaCards.count) { index in
            try scaPaymentRun(cardNumber: scaCards[index])
        }
    }
    
    func scaPaymentRun(cardNumber: String) throws {
        try waitUntilShown()
        
        // try this again with otherScaCardNumber if failing? No, if service is down it doesn't matter what we do.
        try beginPayment(cardNumber: cardNumber, cvv: scaCvv)
        
        try scaApproveCard()
        //else "Continue button not found"
    }
    
    ///Will throw if purchase is not successfull
    private func scaApproveCard() throws {
        
        try waitUntilGone([confirmButton, payButton], errorMessage: "Approve page fails to load")
        
        let otpPage = webView.staticTexts.contains(label: "Challenge Form")
        let otpCode = webView.staticTexts.contains(label: "OTP Code")
        _ = try? waitForOne([otpPage, otpCode, continueButton, successMessage, unknownErrorMessage],
                            defaultTimeout, errorMessage: "No known 3ds challange page detected")

        if continueButton.exists {
            print("sca aproving with continue button")
            try retryUntilSuccess {
                continueButton.tap()
                try waitForResponseOrFailure()
            }
        } else if successMessage.exists {
            print("This card was pre-approved")
        } else if unknownErrorMessage.exists {
            throw "This card did not work, you must remove it before trying again"
        } else {
            print("sca aproving with otp text field")
            //whitelistThisMerchant.tap() it also does not matter!
            input(to: otpTextField, text: "1234", waitForOk: true)
            try waitForResponseOrFailure()
        }
    }
    
    //Sorry for this ugly code, my hands are tied due to linting.
    func waitForResponseOrFailure(
        _ timeout: Double = defaultTimeout,
        _ errorMessage: String = "Card failed upstream, try with another card.") throws {
            
        let start = Date()
        while start.timeIntervalSinceNow > -timeout {
            if successMessage.waitForExistence(timeout: 1) {
                return
            }
            if unknownErrorMessage.waitForExistence(timeout: 1) {
                throw errorMessage
            }
        }
        throw errorMessage
    }
    
    /// Check that instrument-mode works in V3 and we can update payments with a new instrument
    func testV3Instruments() throws {
        
        
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
        
    }
    
    /// Test monthly invoice payment, we have to run this manually for now since I can't automate bankID yet
    func manualTestV3MonthlyInvoiceInstrument() throws {
        
        let config = "stage"
        app.launchArguments.append("-configName \(config)")
        //app.launchArguments.append("-testV3")
        app.launch()
        
        try waitUntilShown()
        
        //check that monthlyExists
        let monthlyInvoice = webText(label: "Monthly invoice")
        XCTAssertTrue(monthlyInvoice.waitForExistence(timeout: resultTimeout), "No monthly invoice option!")
        monthlyInvoice.tap()
        
        //we can't automate bankID testing yet.
        let waiter = expectation(description: "wait for manual testing")
        waitForExpectations(timeout: 3600 * 2)
        waiter.fulfill()
    }
    
    func testAbortPayment() throws {
        
        app.launchArguments.append("-testV3")
        app.launchArguments.append("-testAbortPayment")
        try rerunXTimes(2) { _ in
            try waitUntilShown()
            
            //abort payment will fail if you try to abort it too soon (before the payment exists), when tapping card it is made sure the payment exists.
            try waitAndAssertExists(timeout: initialTimeout, cardOption, "Card option not found")
            cardOption.tap()
            try waitAndAssertExists(panInput, "PAN input not found")
            
            //tap MenuButton, this calls viewController.abortPayment()
            testMenuButton.tap()
            
            //just wait until instrument select-change
            try waitFor(.canceled, timeout: resultTimeout)
        }
    }
    
    func repeatGenerateUnscheduledToken(_ cardToUse: String) throws {
        print("testing with card: \(cardToUse)")
        
        try waitUntilShown()
        try beginPayment(cardNumber: cardToUse, cvv: scaCvv)
        //tap continue button or do the otp dance.
        try scaApproveCard()
    }
    
    func testGenerateUnscheduledToken() throws {
        app.launchArguments.append("-testV3")
        app.launchArguments.append("-testVerifyUnscheduledToken")
        try rerunXTimesWithConfigs(scaCards.count) { index in
            
            try repeatGenerateUnscheduledToken(scaCards[index])
        }
        
        //clear current messages
        _ = messageList.getMessages()
        testMenuButton.tap()
        
        let result = messageList.waitForFirst(timeout: resultTimeout)
        if case .error(errorMessage: let message) = result {
            print("got error message that should be a paymentOrder")
            XCTFail(message)
        } else if case .complete = result {
            print("GenerateUnscheduledToken was a success!")
        }
        else {
            XCTFail("Unknown message after token-tap: \(String(describing: result))")
        }
    }
    
    // verify that the predefined box appears!
    func testOneClickEnterprisePayerReference() throws {
        
        app.launchArguments.append("-configName enterprise")
        app.launchArguments.append("-testV3")
        app.launchArguments.append("-testEnterprisePayerReference")
        let originalArguments = app.launchArguments
        
        try rerunXTimes(scaCards.count, ignoreLaunch: true) { index in
            app.launchArguments.append("-regeneratePayerRef")
            try runOneClickEnterprisePayerReference(originalArguments, scaCards[index])
        }
    }
    
    func runOneClickEnterprisePayerReference(_ originalArguments: [String], _ scaCard: String) throws {
        
        app.launch()
        
        try waitUntilShown()
        try waitAndAssertExists(timeout: initialTimeout, webView,
                                "no weview for OneClickEnterprisePayerReference")
        
        /// Could be a bug but Swedbank sometimes require additional ssn-
        /// input to store cards, sometimes the existing refs are enough.
        try waitForOne([ssnInput, cardOption], errorMessage:
                        "Neither ssnInput nor card options were found")
        if ssnInput.exists {
            
            //it shows up and then has a little animation (which can't be tapped), add a delay to protect from that.
            sleep(1)
            print("Input ssn number")
            input(to: ssnInput, text: ssn, waitForOk: false)
            print("Wait for save button")
            
            try waitAndAssertExists(saveCredentialsButton, "No save button")
            saveCredentialsButton.tap()
        }
        
        try waitAndAssertExists(timeout: initialTimeout, cardOption, "Card option not found")
        cardOption.firstMatch.tap()
        
        try waitForOne([anyPrefilledCard, prefilledCard(scaCard),
            creditCardOption, addAnotherCardLink],
            errorMessage: "Could not find starting point for oneClick payer ref")
        
        //detect if the right card exist
        if anyPrefilledCard.exists {
            //select this and continue!
            try purchaseWithPrefilledCard()
            //we don't need to do more - it remembers everything!
            return
        }
        //otherwise there is either a link to add a new card - or if no cards just card input.
        else if creditCardOption.exists {
            //no cards
            
        } else {
            //if not: add a new card
            //try waitAndAssertExists(timeout: initialTimeout, addAnotherCardLink, "addAnotherCard not found")
            addAnotherCardLink.firstMatch.tap()
        }
        try performPayment(cardNumber: scaCard, cvv: scaCvv)
        try scaApproveCard()
        app.terminate()
        app.launchArguments = originalArguments
        app.launch()
        
        try waitAndAssertExists(ssnInput, "No ssn input")
        input(to: ssnInput, text: ssn, waitForOk: true)
        
        try waitAndAssertExists(saveCredentialsButton, "No save button")
        saveCredentialsButton.tap()
        
        try waitAndAssertExists(timeout: initialTimeout, cardOption, "Card option not found")
        cardOption.firstMatch.tap()
        
        try waitAndAssertExists(timeout: scaTimeout, anyPrefilledCard, "No prefilled cards")
        try purchaseWithPrefilledCard()
    }
    
    func purchaseWithPrefilledCard() throws {
        print("purchaseWithPrefilledCard")
        anyPrefilledCard.firstMatch.tap()
        
        try waitAndAssertExists(timeout: resultTimeout, confirmButton, "payButton not found")
        try delayUnlessEnabled(confirmButton)
        
        print("Tap confirm until gone")
        //sometimes we need to tap confirmButton twice, but always wait until it disapears
        retryUntilTrue {
            if !confirmButton.exists {
                return true
            }
            confirmButton.tap()
            _ = continueButton.waitForExistence(timeout: shortTimeout)
            return false
        }
        if confirmButton.exists {
            throw "Could tap confirm button for prefilled card"
        }
        try scaApproveCard()
        //try confirmAndWaitForCompletePayment(confirmButton, "Could not pay with oneClick")
    }
    
    // Make sure we also support ssn directly
    func testOneClickEnterpriseNationalIdentifier() throws {
        
        app.launchArguments.append("-configName enterprise")
        app.launchArguments.append("-testV3")
        app.launchArguments.append("-testOneClickPayments")
        
        let originalArguments = app.launchArguments
        
        //Sometimes it fails due to payerRef is not unique. 
        try rerunXTimes(scaCards.count, ignoreLaunch: true) { index in
            var args = originalArguments
            args.append("-regeneratePayerRef")
            app.launchArguments = args
            app.launch()
            try waitAndAssertExists(timeout: initialTimeout, webView, "Web view not found")
            
            try waitAndAssertExists(timeout: initialTimeout, cardOption, "Card option not found")
            retryUntilTrue {
                cardOption.tap()
                print("Check if panInput exist, or wait for prefilled card")
                if panInput.exists {
                    return true
                }
                return anyPrefilledCard.waitForExistence(timeout: shortTimeout)
            }
            if anyPrefilledCard.exists == false {
                print("Prefilled card did not exist, create one")
                try performPayment(cardNumber: scaCards[index], cvv: scaCvv)
                try scaApproveCard()
                
                //Throw error to restart - if we come back here there is something wrong with that card
                print("Restart test by throwing error, this should only happen once")
                throw "Saved a new card, but it did not get remembered"
            } else {
                try assertExists(anyPrefilledCard, "No prefilled cards")
                try purchaseWithPrefilledCard()
            }
        }
    }
    
    ///Rerun the test a few times to make testing more robust. E.g. trying different cards.
    private func rerunXTimes(_ count: Int, ignoreLaunch: Bool = false, _ closure: (Int) throws -> Void) rethrows {
        for index in 0..<count {
            do {
                if !ignoreLaunch {
                    app.launch()
                }
                app.activate()
                try closure(index)
                return
            } catch {
                app.terminate()
                if index == count - 1 {
                    throw error
                }
            }
        }
    }
    
    /**
     Rerun the same test with different configurations. Set endIfSuccess = false to run the same test with all confifurations.
     Usage:
     try rerunXTimesWithConfigs(scaCards.count) { index in
        try performTest(cardNumber: scaCards[index])
     }
    **/
    private func rerunXTimesWithConfigs(_ count: Int, configurations: [String] = paymentTestConfigurations,
        endIfSuccess: Bool = true, _ closure: (Int) throws -> Void) rethrows {
        let originalArguments = app.launchArguments
        var args = originalArguments
        for config in configurations {
            args = originalArguments
            print("Running test with config: \(config)")
            args.append("-configName \(config)")
            app.launchArguments = args
            
            do {
                try rerunXTimes(count, closure)
                if endIfSuccess {
                    return
                }
            } catch {
                if config == configurations.last {
                    throw error
                }
            }
        }
    }
    
    func testOneClickPaymentsOnly() throws {
        
        app.launchArguments.append("-testV3")
        app.launchArguments.append("-testOneClickPayments")
        
        try rerunXTimes(scaCards.count) { index in
            
            try scaPaymentRun(cardNumber: scaCards[index])
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
    
    /*
     the test goes like this:
     load a random URL in the app-browser, but cancel it
     set processHost to external which starts the isStuck timer,
     tap retry
     now the payment menu should be reloaded, and all requests following this are redirected to the browser.
     */
    func testDelayOpenAlert() throws {
        app.launchArguments.append(contentsOf: ["-testV3", "-testExternalURL", "-testModalController"])
        app.launch()
        
        let retryButton = app.alerts["Stuck?"].scrollViews.otherElements.buttons["Retry"]
        XCTAssertTrue(retryButton.waitForExistence(timeout: defaultTimeout), "No alert for retry button")
        retryButton.tap()
        
        //Now everything reloads and all new payments are redirected to the browser.
        
        sleep(2)
        try waitUntilShown()
        try assertExists(cardOption, "Credit card option not found")
        cardOption.tap()
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

extension XCUIElementQuery {
    func contains(label: String) -> XCUIElement {
        let predicate = NSPredicate(format: "label CONTAINS[cd] %@", argumentArray: [label])
        return self.element(matching: predicate)
    }
}
