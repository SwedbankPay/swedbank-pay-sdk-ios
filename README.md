# Swedbank Pay iOS SDK

Swedbank Pay iOS SDK enables simple embedding of [PayEx Checkout](https://developer.payex.com/xwiki/wiki/developer/view/Main/ecommerce/payex-checkout) to an iOS application. You may also be interested in [Android version](https://github.com/SwedbankPay/swedbank-pay-sdk-android) of the SDK and [backend documentation for the merchant API](https://github.com/SwedbankPay/swedbank-pay-sdk-mobile-example-merchant).

### Example app

There is an [example app](https://github.com/SwedbankPay/swedbank-pay-sdk-ios-example-app) written in Swift.

### Requirements

- The SDK requires iOS 9.0+.
- [Cocoapods](https://guides.cocoapods.org/using/getting-started.html)

### Installation

1. Add `pod 'SwedbankPaySDK'` into your `Podfile`
2. Run `pod install`
3. Restart Xcode if it was open

### Usage

To use Swedbank Pay iOS SDK you `import SwedbankPaySDK` in your `UIViewController` and instantiate the `SwedbankPaySDKController` the way you see fit. For instance in the example app it is instantiated inside an UIView:
```
let swedbankPaySDKController = SwedbankPaySDKController.init(
    configuration: configuration,
    merchantData: merchantData,
    consumerData: consumerData
)
swedbankPaySDKController.delegate = self
addChild(swedbankPaySDKController)
webViewContainer.addSubview(swedbankPaySDKController.view)
swedbankPaySDKController.view.translatesAutoresizingMaskIntoConstraints = false

NSLayoutConstraint.activate([
    swedbankPaySDKController.view.topAnchor.constraint(equalTo: webViewContainer.topAnchor),
    swedbankPaySDKController.view.leftAnchor.constraint(equalTo: webViewContainer.leftAnchor),
    swedbankPaySDKController.view.rightAnchor.constraint(equalTo: webViewContainer.rightAnchor),
    swedbankPaySDKController.view.bottomAnchor.constraint(equalTo: webViewContainer.bottomAnchor),
])
swedbankPaySDKController.didMove(toParent: self)
```

There are 3 things the SDK expects.

1. Configuration:
```
let configuration = SwedbankPaySDK.Configuration.init(...
```
2. MerchantData:
```
let mechantData = [Anything your backend expects, but it must conform to Encodable protocol]
```
3. Optionally, consumerData (if consumerData is `nil`, consumer is anonymous):
```
let consumerData = SwedbankPaySDK.Consumer.init(...
```

###### Delegation

To handle the responses from the SDK, the viewController needs to conform to `SwedbankPaySDKDelegate`, like in the example app:
```
extension PaymentViewController: SwedbankPaySDKDelegate {
    func paymentComplete() {
        // Your payment completion code here
    }

    func paymentFailed(_ problem: SwedbankPaySDK.Problem) {
        // Your error handling code here
    }
}
```

### License

Swedbank Pay iOS SDK is released under the [Apache 2.0 license](LICENSE).
