//
//  SwedbankPaySDKUITests.swift
//  SwedbankPaySDKUITests
//
//  Created by Pertti Kroger on 23.4.2021.
//  Copyright © 2021 Swedbank. All rights reserved.
//

import XCTest

private let initialTimeout = 60.0
private let defaultTimeout = 30.0
private let scaTimeout = 120.0
private let resultTimeout = 120.0

private let cardOptionTapMaxAttempts = 3
private let cardOptionTapAttemptTimeout = 10.0

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
        waitAndAssertExists(webView, "Web view not found")
    }
    
    private func paymentTest(
        cardNumber: String,
        cvv: String,
        paymentHandler: () -> Void
    ) throws {
        waitAndAssertExists(timeout: initialTimeout, webView, "Web view not found")
        
        waitAndAssertExists(cardOption, "Card option not found")
        
        XCTAssert(
            tapCardOptionAndWaitForCreditCardOption(),
            "Credit card option not found"
        )
        
        creditCardOption.tap()
        
        waitAndAssertExists(panInput, "PAN input not found")
        input(to: panInput, text: cardNumber)
        
        waitAndAssertExists(expiryInput, "Expiry date input not found")
        input(to: expiryInput, text: expiryDate)
        
        // Because of some mystical reason, in some cases
        // XCUIElement.tap() fails to tap at the correct screen point
        // if the element is too high on the screen (?!).
        // To see this is action, run the test on an iPhone 12 Pro
        // simulator and uncomment this line.
        //
        // For those going down the rabbit hole: it would appear that
        // the screen coordinates are not reported correctly.
        // Try calling
        // element.coordinate(withNormalizedOffset: .zero).screenPoint
        // and you will see wildly different results depending on the
        // web view scroll position.
        //
        // This line makes the web view scroll to a position where
        // tap() appears to work.
        webView.swipeDown()
        
        waitAndAssertExists(cvvInput, "CVV input not found")
        input(to: cvvInput, text: cvv)
        
        waitAndAssertExists(payButton, "Pay button not found")
        payButton.tap()
        
        paymentHandler()
        
        print("Waiting \(resultTimeout)s for payment to complete")
        let result = try messageList.poll(timeout: resultTimeout)
        XCTAssertEqual(result, .complete, "Payment was not successful: \(result)")
    }
    
    private func tapCardOptionAndWaitForCreditCardOption() -> Bool {
        for _ in 0..<cardOptionTapMaxAttempts {
            cardOption.tap()
            if creditCardOption.waitForExistence(
                timeout: cardOptionTapAttemptTimeout
            ) {
                return true
            }
        }
        return false
    }
    
    /// Check that a payment without SCA works
    func testItShouldSucceedAtPaymentWithoutSca() throws {
        try paymentTest(cardNumber: noScaCardNumber, cvv: noScaCvv) {}
    }
    
    /// Check that a payment with SCA works
    func testItShouldSucceedAtPaymentWithSca() throws {
        try paymentTest(cardNumber: scaCardNumber, cvv: scaCvv) {
            waitAndAssertExists(
                timeout: scaTimeout,
                continueButton, "Continue button not found"
            )
            // See comment at swipeDown() call in paymentTest.
            // These are needed for the same reason.
            webView.pinch(withScale: 2, velocity: 1)
            webView.swipeRight()
            webView.swipeDown()
            continueButton.tap()
        }
    }
}
