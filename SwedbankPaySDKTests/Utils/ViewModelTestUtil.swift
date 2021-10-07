import XCTest
@testable import SwedbankPaySDK

extension XCTestCase {
    @discardableResult
    func expectState(
        viewModel: SwedbankPaySDKViewModel,
        predicate: @escaping (SwedbankPaySDKViewModel.State) -> Bool
    ) -> XCTestExpectation {
        let expectation = self.expectation(description: "Desired state reached")
        if predicate(viewModel.state) {
            expectation.fulfill()
        } else {
            viewModel.onStateChanged = {
                if predicate(viewModel.state) {
                    expectation.fulfill()
                    viewModel.onStateChanged = nil
                }
            }
        }
        return expectation
    }
}
