# Swedbank Pay SDK for iOS

![Swedbank Pay SDK for iOS][opengraph-image]

![Tests][test-badge]
[![Cocoapods][pod-version-badge]][pod]
[![Cocoapods platforms][pod-platforms-badge]][pod]
[![CLA assistant][cla-badge]][cla]
[![License][license-badge]][license]
[![Contributor Covenant][coc-badge]][coc]

The Swedbank Pay iOS SDK facilitates the implementation of the
[Swedbank Pay API Platform][dev-portal] in an iOS application.

## Installation

The SDK has two components, `SwedbankPaySDK` and
`SwedbankPaySDKMerchantBackend`. The first one is the core SDK, and
the second one contains utilities for interfacing with a server implementing
the [Merchant Backend API][merchant-backend-example].

If you are not using the Merchant Backend API for backend communication,
you only need to use the `SwedbankPaySDK` component. Otherwise, you
should add both components to your project.

### Swift Package Manager

The SDK is available through the Swift Package Manager. This is the simplest
way of adding the SDK to an Xcode project.

Follow the instructions [here][xcode-swiftpm] to add a SwiftPM dependency.
Use
`https://github.com/SwedbankPay/swedbank-pay-sdk-ios.git`
as the repository URL. Select either only the `SwedbankPaySDK` library or both
libraries depending on your use-case.

### CocoaPods

The SDK is also available through [CocoaPods][cocoapods]. There are separate
pods for the two components, named  `SwedbankPaySDK` and
`SwedbankPaySDKMerchantBackend` respectively.

Add the relevant dependencies in your `Podfile`:

```ruby
pod 'SwedbankPaySDK', '~> 3.0'
```
```ruby
pod 'SwedbankPaySDKMerchantBackend', '~> 3.0'
```

## Usage

Please refer to the [Developer Portal][dev-portal-sdk] for usage instructions.

To explore a working app using the SDK, see the [Example Project][example-app].

## Walkthrough / integration into an existing app

To start making payments you need four things:

1. A SwedbankPaySDKConfiguration object that describes how to communicate with your backend. To get started quickly a default implementation is provided, called MerchantBackendConfiguration.
2. A paymentOrder that describes what to purchase, the cost, currency and similar information.
3. Give that paymentOrder to an instance of a SwedbankPaySDKController and present it in your view hierarchy.
4. Implement the SwedbankPaySDKDelegate callbacks and wait for payment to succeed or fail.

Instead of just talking about it we have provided you with an example app, showing you in detail how integration can be done. Use that as a reference when building your own solution:

[iOS Example app][example-app]

### 1. SwedbankPaySDKConfiguration details

Using the MerchantBackendConfiguration you only need to provide the URL for your backend and header values for api key and an access token. Have a look at the configuration variable in [PaymentViewModel.swift][PaymentViewModelConfig] in the example app for a reference.

The SDK will then communicate with your backend, expecting the same API as our example backends. You don't have to provide all of the API, making payments only require /paymentorders, but you will want to support /tokens and /patch soon as well. To get started you can look at our [backend example implementations][merchant_backend] which provides a complete set of functionality and describes in a very clear and easy manner how requests can be handled.

Using the [Merchant example backend][merchant_backend] you can setup (for example) a Node.js backend and have it serve a client in debug-mode while integrating the app. Remember to supply your api-key and other values in the appconfig.json file in order for requests to work properly.

### 2. PaymentOrder details

In PaymentViewModel.swift there is a [paymentOrder property][PaymentViewModelOrderVar] that describes how we create it. PaymentOrders have default values for properties that can, so that you only need to supply values for what the customer intends to purchase, or for to access advanced functionality.

### 3. Presenting the payment menu

The last step is to just create an instance of the SwedbankPaySDKController and present it to the user. In the example app we add it as a sub view controller, but it could be managed in any other way, see [PaymentViewController.swift][PaymentViewControllerDidLoad] for details.


### 4. SwedbankPaySDKDelegate

The delegate pattern is well known and widely used in the iOS community. Implement the delegate callbacks you are interested in to get notified of the state of the purchase. Typically you need to at least know when payments succeed, is canceled or fail, but there are a few more callbacks to your disposal. See [the SwedbankPaySDKDelegate protocol][SwedbankPaySDKDelegate], or [the example app implementation][SwedbankPaySDKDelegateExampleApp] for more details.


### Integration conclusions

This is all you need to get started and accepting payments, the next step is to let your customers save their card details, or to create purchase tokens for subscriptions or tokens for charges at a later stage. Depending on your specific use case.

Continue reading the [PaymentsOnly tokens walkthrough][integrateTokens] or [Enterprise tokens walkthrough][enterpriseTokens] for a continued discussion on payment tokens. These features are also well documented in swedbank pay's developer portal under "optional features".

For more in-depth details of how to operate the SDK and to setup the necessary callbacks, [please refer to the SwedbankPay SDK documentation][dev-portal-sdk].


## Contributing

Bug reports and pull requests are welcome on [GitHub][github]. This project is
intended to be a safe, welcoming space for collaboration, and contributors are
expected to adhere to the [code of conduct][coc] and sign the
[contributor's license agreement][cla].

## License

The code within this repository is available as open source under the terms of
the [Apache 2.0 License][license] and the [contributor's license
agreement][cla].

[merchant-backend-example]: https://github.com/SwedbankPay/swedbank-pay-sdk-mobile-example-merchant
[xcode-swiftpm]: https://developer.apple.com/documentation/swift_packages/adding_package_dependencies_to_your_app
[cocoapods]: https://cocoapods.org/
[dev-portal]:           https://developer.swedbankpay.com/
[dev-portal-sdk]:       https://developer.swedbankpay.com/modules-sdks/mobile-sdk/
[cla-badge]:            https://cla-assistant.io/readme/badge/SwedbankPay/swedbank-pay-sdk-android
[cla]:                  https://cla-assistant.io/SwedbankPay/swedbank-pay-sdk-android
[coc-badge]:            https://img.shields.io/badge/Contributor%20Covenant-v2.0%20adopted-ff69b4.svg
[coc]:                  ./CODE_OF_CONDUCT.md
[dependabot-badge]:     https://api.dependabot.com/badges/status?host=github&repo=SwedbankPay/swedbank-pay-sdk-android
[dependabot]:           https://dependabot.com
[example-app]:          https://github.com/SwedbankPay/swedbank-pay-sdk-ios-example-app
[github]:               https://github.com/SwedbankPay/swedbank-pay-sdk-ios
[license-badge]:        https://img.shields.io/github/license/SwedbankPay/swedbank-pay-sdk-android
[license]:              https://opensource.org/licenses/Apache-2.0
[opengraph-image]:      https://repository-images.githubusercontent.com/209730241/aa264700-6d3d-11eb-99e1-0b40a9bb19be
[pod-version-badge]:    https://img.shields.io/cocoapods/v/SwedbankPaySDK
[pod-platforms-badge]:  https://img.shields.io/cocoapods/p/SwedbankPaySDK
[pod]:                  https://cocoapods.org/pods/SwedbankPaySDK
[test-badge]:           https://github.com/SwedbankPay/swedbank-pay-sdk-ios/workflows/Test/badge.svg

[merchant_backend]: https://github.com/SwedbankPay/swedbank-pay-sdk-mobile-example-merchant
[PaymentViewModelConfig]: https://github.com/SwedbankPay/swedbank-pay-sdk-ios-example-app/blob/main/Example-app/ViewModels/PaymentViewModel.swift#:~:text=var%20configuration:
[PaymentViewModelOrderVar]: https://github.com/SwedbankPay/swedbank-pay-sdk-ios-example-app/blob/main/Example-app/ViewModels/PaymentViewModel.swift#:~:text=var%20paymentOrder:
[PaymentViewControllerDidLoad]: https://github.com/SwedbankPay/swedbank-pay-sdk-ios-example-app/blob/main/Example-app/ViewControllers/PaymentViewController.swift#:~:text=func%20viewDidAppear
[SwedbankPaySDKDelegate]: https://github.com/SwedbankPay/swedbank-pay-sdk-ios/blob/main/SwedbankPaySDK/Classes/SwedbankPaySDKController.swift#:~:text=protocol%20SwedbankPaySDKDelegate
[SwedbankPaySDKDelegateExampleApp]: https://github.com/SwedbankPay/swedbank-pay-sdk-ios-example-app/blob/main/Example-app/ViewControllers/PaymentViewController.swift#:~:text=extension%20PaymentViewController:%20SwedbankPaySDKDelegate
[integrateTokens]: ./integrateTokens.md
[enterpriseTokens]: ./integrateTokensEnterprise.md
