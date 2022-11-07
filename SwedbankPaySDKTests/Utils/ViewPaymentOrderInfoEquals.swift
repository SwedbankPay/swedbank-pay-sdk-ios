import XCTest
import SwedbankPaySDK

extension Optional where Wrapped == SwedbankPaySDK.ViewPaymentOrderInfo {
    func assertEqualTo<UserInfo: Equatable>(
        other: SwedbankPaySDK.ViewPaymentOrderInfo?, userInfoType: UserInfo.Type
    ) throws {
        if let self = self {
            let other = try XCTUnwrap(other)
            try self.assertEqualTo(other: other, userInfoType: userInfoType)
        } else {
            XCTAssertNil(other)
        }
    }
}

extension SwedbankPaySDK.ViewPaymentOrderInfo {
    func assertEqualTo<UserInfo: Equatable>(
        other: SwedbankPaySDK.ViewPaymentOrderInfo, userInfoType: UserInfo.Type
    ) throws {
        baseAssertEqualTo(other: other)
        let userInfo = try XCTUnwrap(self.userInfo as? UserInfo, "self.userInfo is not an instance of \(userInfoType)")
        let otherUserInfo = try XCTUnwrap(other.userInfo as? UserInfo, "other.userInfo is not an instance of \(userInfoType)")
        XCTAssertEqual(userInfo, otherUserInfo)
    }
    
    private func baseAssertEqualTo(other: SwedbankPaySDK.ViewPaymentOrderInfo) {
        XCTAssertEqual(webViewBaseURL, other.webViewBaseURL)
        XCTAssertEqual(completeUrl, other.completeUrl)
        XCTAssertEqual(cancelUrl, other.cancelUrl)
        XCTAssertEqual(paymentUrl, other.paymentUrl)
        XCTAssertEqual(termsOfServiceUrl, other.termsOfServiceUrl)
        XCTAssertEqual(instrument, other.instrument)
        XCTAssertEqual(availableInstruments, other.availableInstruments)
    }
}
