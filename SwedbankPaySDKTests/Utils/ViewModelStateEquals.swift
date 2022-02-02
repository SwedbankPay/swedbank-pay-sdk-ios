import XCTest
@testable import SwedbankPaySDK

extension SwedbankPaySDKViewModel.State {
    func assertEquals<UserInfo, Err>(
        other: SwedbankPaySDKViewModel.State,
        userInfoType: UserInfo.Type,
        errorType: Err.Type
    ) throws where UserInfo: Equatable, Err: Error, Err: Equatable{
        switch (self, other) {
            case (.idle, .idle): break
            case (.initializingConsumerSession, .initializingConsumerSession): break
            case (.identifyingConsumer(let lhs, let optionsLeft), .identifyingConsumer(let rhs, let optionsRight)):
                XCTAssertEqual(optionsLeft, optionsRight)
                switch (lhs, rhs) {
                    case (.v2(let left), .v2(let right)):
                        XCTAssertEqual(left.viewConsumerIdentification, right.viewConsumerIdentification)
                        XCTAssertEqual(left.webViewBaseURL, right.webViewBaseURL)
                    case (.v3(let left), .v3(let right)):
                        XCTAssertEqual(left.viewConsumerIdentification, right.viewConsumerIdentification)
                        XCTAssertEqual(left.webViewBaseURL, right.webViewBaseURL)
                    default:
                        XCTFail("Mixing V2 and V3")
                }
            case (.creatingPaymentOrder(let lhs, options: let optionsLeft), .creatingPaymentOrder(let rhs, options: let optionsRight)):
                XCTAssertEqual(lhs, rhs)
                XCTAssertEqual(optionsLeft, optionsRight)
            case (.paying(let lhs, options: let optionsLeft, _), .paying(let rhs, options: let optionsRight, _)):
                try lhs.assertEqualTo(other: rhs, userInfoType: userInfoType)
                XCTAssertEqual(optionsLeft, optionsRight)
            case (.complete(let lhs), .complete(let rhs)):
                try lhs.assertEqualTo(other: rhs, userInfoType: userInfoType)
            case (.canceled(let lhs), .canceled(let rhs)):
                try lhs.assertEqualTo(other: rhs, userInfoType: userInfoType)
            case (.failed(let lhs, let lhsError), .failed(let rhs, let rhsError)):
                try lhs.assertEqualTo(other: rhs, userInfoType: userInfoType)
                let lhsError = try XCTUnwrap(lhsError as? Err, "\(String(describing: lhsError)) is not \(errorType)")
                let rhsError = try XCTUnwrap(rhsError as? Err, "\(String(describing: rhsError)) is not \(errorType)")
                XCTAssertEqual(lhsError, rhsError)
            default:
                XCTFail("states differ: \(self); \(other)")
        }
    }
}
