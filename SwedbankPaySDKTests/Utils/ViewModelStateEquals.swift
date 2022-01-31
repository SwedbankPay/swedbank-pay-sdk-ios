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
            case (.identifyingConsumer(let lhs), .identifyingConsumer(let rhs)):
                XCTAssertEqual(lhs.viewConsumerIdentification, rhs.viewConsumerIdentification)
                XCTAssertEqual(lhs.webViewBaseURL, rhs.webViewBaseURL)
            case (.creatingPaymentOrder(let lhs, isV3: let isV3Left), .creatingPaymentOrder(let rhs, isV3: let isV3Right)):
                XCTAssertEqual(lhs, rhs)
                XCTAssertEqual(isV3Left, isV3Right)
            case (.paying(let lhs, _), .paying(let rhs, _)):
                try lhs.assertEqualTo(other: rhs, userInfoType: userInfoType)
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
