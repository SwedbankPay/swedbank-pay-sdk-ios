# Integrate payment tokens using the Swedbank Pay SDK for iOS

![Swedbank Pay SDK for iOS][opengraph-image]

# Enterprise

This document only concerns merchants using the Enterprise integration, PaymentsOnly handles this differently. [Read more on tokens for PaymentsOnly][PaymentsOnly-tokens]

## Prerequisites 

Before diving into advanced features you should have a working app and backend, that can handle purchases in debug-mode. This is described in detail in the [readme file][readme], and you can also look at the [iOS Example app][example-app] as a reference.

## Remembering the payer

Returning customers are the best customers, and it is really easy to improve the experience by auto-filling the payment details. You can supply email and phone number to let the customer store the payment information and have SwedbankPay auto-fill it the next time. Just supply a unique reference along with these values when starting a new payment:

``` Swift
var paymentOrder = ... //create the paymentOrder as usual by calculating price, etc
payment.payer = .init(
	consumerProfileRef: nil, 
	email: "leia.ahlstrom@payex.com", 
	msisdn: "+46739000001", 
	payerReference: unique-identifier
)

```

Now the customer has the option to store card numbers or select one of the previously stored cards. More info in [the documentation][enterprise-payer-ref].


## Payment tokens for later use

A common practice is to store a credit-card for later use, e.g. for subscriptions, and charge every month. To make this safe & secure you let SwedbankPay store the payment information and only keep a reference, a payment token. This token can later be used to make purchases, and there are two types of tokens that can be created. One for subscriptions, and one for later unscheduled purchases. They are created the same way, by setting generateUnscheduledToken = true or generateRecurrenceToken = true, in the paymentOrder and then either making a purchase or verifying a purchase (set the operation property to PaymentOrderOperation.verify). 

``` Swift

var paymentOrder = ... //create the paymentOrder as usual by calculating price, etc
paymentOrder.generateRecurrenceToken = true
viewController.startPayment(paymentOrder: paymentOrder)

```

When expanding the paid property of this verified or purchased payment, there is an array with tokens one can save for later use. Here is an abbreviated example of what is received:


``` JSON
{
	"paymentOrder": {
		...
		"paid": {
			...
			"tokens": [
			    {
			        "type": "recurrence",
			        "token": "a7d7d780-98ba-4466-befe-e5428f716c30",
			        "name": "458109******3517",
			        "expiryDate": "12/2030"
			    },
			    {
			        "type": "unscheduled",
			        "token": "0c43b168-dcd5-45d1-b9c4-1fb8e273c799",
			        "name": "458109******3517",
			        "expiryDate": "12/2030"
			    }
			]
		}
	}
}
```

Then, to make an unscheduled purchase you simply add the unscheduledToken, or the recurrenceToken to the paymentOrder request. Obviously these purchases and the expanding of tokens is only needed to be done on the backend.

More info on [unscheduled purchases][unscheduled].

More info on [recurring purchases][recur].


[readme]: ./README.md
[opengraph-image]:      https://repository-images.githubusercontent.com/209730241/aa264700-6d3d-11eb-99e1-0b40a9bb19be
[example-app]: https://github.com/SwedbankPay/swedbank-pay-sdk-ios-example-app
[one-click-payments]: https://developer.swedbankpay.com/checkout-v3/payments-only/features/optional/one-click-payments
[expanding_properties]: https://developer.swedbankpay.com/introduction#expansion
[one-click-image]: https://developer.swedbankpay.com/assets/img/checkout/one-click.png "Prefilled payment option"
[unscheduled]: https://developer.swedbankpay.com/checkout-v3/payments-only/features/optional/unscheduled
[recur]: https://developer.swedbankpay.com/checkout-v3/payments-only/features/optional/recur
[PaymentsOnly-tokens]: ./integrateTokens.md
[enterprise-payer-ref]: https://developer.swedbankpay.com/checkout-v3/enterprise/features/optional/enterprise-payer-reference