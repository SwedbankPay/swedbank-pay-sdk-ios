# Swedbank Pay SDK for iOS

![Swedbank Pay SDK for iOS][opengraph-image]

Swedbank Pay iOS SDK enables simple embedding of [Swedbank Pay Checkout](https://developer.swedbankpay.com/checkout/) to an iOS application. You may also be interested in [Android version](https://github.com/SwedbankPay/swedbank-pay-sdk-android) of the SDK and [backend documentation for the merchant API](https://github.com/SwedbankPay/swedbank-pay-sdk-mobile-example-merchant).

## Table of contents

1. [Example app](#example-app)
2. [Requirements](#requirements)
3. [Installation](#installation)
4. [Usage](#usage)
   - [Configuring the SDK](#configuring-the-sdk)
     - [Backend url](#backend-url)
     - [Headers](#headers)
     - [Domain whitelisting](#domain-whitelisting)
     - [Certificate pinning](#certificate-pinning)
   - [Making A Payment](#making-a-payment)
   - [The Payment process](#the-payment-process)
   - [Problems](#problems)
5. [Test data](#test-data)
6. [License](#license)

<a name="example-app"></a>
## Example app

There is an [example app](https://github.com/SwedbankPay/swedbank-pay-sdk-ios-example-app) written in Swift.

<a name="requirements"></a>
## Requirements

- The SDK requires iOS 9.0+.
- [Cocoapods](https://guides.cocoapods.org/using/getting-started.html)
- To use the SDK you must have a "merchant backend" server running. Please refer to the [merchant backend example documentation](https://github.com/SwedbankPay/swedbank-pay-sdk-mobile-example-merchant) on how to set one up.

<a name="installation"></a>
## Installation

1. Add `pod 'SwedbankPaySDK'` into your `Podfile`
2. Run `pod install`
3. Restart Xcode if it was open

<a name="usage"></a>
## Usage

To use Swedbank Pay iOS SDK you `import SwedbankPaySDK` and instantiate the `SwedbankPaySDKController` the way you see fit. For instance in the example app it is instantiated inside an UIView named webViewContainer:
```swift
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

<a name="configuring-the-sdk"></a>
### Configuring The SDK

First, you must create a `SwedbankPaySDK.Configuration` object specific to your merchant backend.
```swift
let configuration = SwedbankPaySDK.Configuration.init(...
```

<a name="backend-url"></a>
#### Backend url

Add the merchant backend url into the Configuration. Only the entry point url is specified in the client configuration, and other needed endpoints are found by following links returned by the backend.

<a name="headers"></a>
#### Headers

Add request headers specific to your merchant backend into the Configuration:
```swift
private let headers: Dictionary<String, String> = [
    "x-your-apikey-name": "foo-bar-apikey",
    "x-your-access-token-name": "bar-baz-access-token"
]
```

<a name="domain-whitelisting"></a>
#### Domain whitelisting

For security purposes, the SDK restricts the domains of the links. This is known as the domain whitelist; any link that points to a non-whitelisted domain will not be followed, causing the relevant operation to fail.

By default, the domain of the backend url is whitelisted, along with its subdomains. E.g:
 - `backendUrl` is `https://pay.example.com/api/start`
 - links to `pay.example.com` are followed
 - links to `sub.pay.example.com` are followed
 - links to `other.example.com` are not followed
 - links to `evil.com` are not followed
 
If your merchant backend supplies links to other domains, you must manually whitelist them in your Configuration. Note that manual whitelisting disables the default whitelist of backend url domain plus its subdomains, requiring them to be added manually. You can choose whether or not to include subdomains for manually whitelisted domains.
```swift
SwedbankPaySDK.WhitelistedDomain.init(domain: "pay.example.com/api/start", includeSubdomains: false),
SwedbankPaySDK.WhitelistedDomain.init(domain: "some-other.example.com", includeSubdomains: true)
```

<a name="certificate-pinning"></a>
#### Certificate pinning

Optionally you can add certificate pins for relevant domains in the Configuration. This can increase security, but it does have drawbacks.

Certificate pinning is done by comparing public keys. You may specify the certificate hostname pattern and the SDK will search all available certificates (files ending in ".cer", ".CER", ".crt", ".CRT", ".der", ".DER") in the app bundle and tries to match them:
```swift
SwedbankPaySDK.PinPublicKeys.init(pattern: "pay.example.com")
```
Or, you may specify which certificates to search for:
```swift
SwedbankPaySDK.PinPublicKeys.init(pattern: "pay.example.com", certificateFileNames: "pay.example.com.der", "other.example.com.der", "certificate.der"),
```
The certificate files can be located anywhere in the app bundle.

<a name="making-a-payment"></a>
### Making A Payment

To make a payment, you show the `SwedbankPaySDKController`. This `UIViewController` initializer requires `merchantData` besides valid `SwedbankPaySDK.Configuration`. The SDK API does not specify the type of this argument, but it must conform to `Encodable` protocol:
```swift
T: Encodable
```
By default, the payment will be anonymous. You may, optionally, support identified payment. For this, you need to know the consumer's home country. Currently supported countries are Sweden ("SE"), and Norway ("NO"). If you have additional information on the consumer's identity available, you may supply them to the SDK; this prefills the identification form, allowing for better user experience. To use identified payment, first create an `SwedbankPaySDK.Consumer` object:
```swift
let consumerData = SwedbankPaySDK.Consumer.init(...
```
Then supply it with the SwedbankPaySDKController initializer.

<a name="the-payment-process"></a>
### The Payment Process

SwedbankPaySDKController handles the UI for the payment process. It will call `paymentComplete` delegate method if the payment was successful, and `paymentFailed` with a `SwedbankPaySDK.Problem` if the payment failed:
```swift
extension PaymentViewController: SwedbankPaySDKDelegate {
    func paymentComplete() {
        // Your payment completion code here
    }

    func paymentFailed(_ problem: SwedbankPaySDK.Problem) {
        // Your problem handling code here
    }
}
```

<a name="problems"></a>
### Problems

Swedbank Pay, and the example merchant backend both use [Problem Details for HTTP APIs](https://tools.ietf.org/html/rfc7807) application/problem+json for error reporting. Your custom merchant backend is encouraged to do so as well.

In `paymentFailed` delegate method you can handle different Problems that arise during the payment process.

All problems are either `Client` or `Server` problems. A Client problem is one where there was something wrong with the request the client app sent to the service. A Client problem always implies an HTTP response status in the Client Error range, 400-499.

A Server problem is one where the service understood the request, but could not fulfill it. If the backend responds in an unexpected manner, the situation will be interpreted as a Server error, unless the response status is in 400-499 range, in which case it is still considered a Client error.

This separation to Client and Server errors provides a crude but often effective way of distinguishing between temporary service unavailability and permanent configuration errors. Client and Server errors are further divided to specific types.

<a name="test-data"></a>
## Test Data

During implementation you can use the [test data](https://developer.payex.com/xwiki/wiki/developer/view/Main/ecommerce/resources/test-data/) related to the different payment methods.

<a name="license"></a>
## License

Swedbank Pay iOS SDK is released under the [Apache 2.0 license](LICENSE).

[opengraph-image]: https://repository-images.githubusercontent.com/209730241/1bf8d880-53e9-11ea-846c-c2e2512334b6
