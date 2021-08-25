# Swedbank Pay SDK for iOS

![Swedbank Pay SDK for iOS][opengraph-image]

![Tests][test-badge]
[![Cocoapods][pod-version-badge]][pod]
[![Cocoapods platforms][pod-platforms-badge]][pod]
[![CLA assistant][cla-badge]][cla]
[![License][license-badge]][license]
[![Dependabot Status][dependabot-badge]][dependabot]
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
pod 'SwedbankPaySDK', '~> 2.1'
```
```ruby
pod 'SwedbankPaySDKMerchantBackend', '~> 2.1'
```

## Usage

Please refer to the [Developer Portal][dev-portal-sdk] for usage instructions.

To explore a working app using the SDK, see the [Example Project][example-app].

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
