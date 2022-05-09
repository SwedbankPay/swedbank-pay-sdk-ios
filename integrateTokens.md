# Integrate payment tokens using the Swedbank Pay SDK for iOS

![Swedbank Pay SDK for iOS][opengraph-image]

## Prerequisites 

Before diving into advanced features you should have a working app and backend, that can handle purchases in debug-mode. This is described in detail in the [readme file][readme], and you can also look at the [iOS Example app][example-app] as a reference.

## Remembering the payer

Returning customers are the best customers, and it is really easy to improve the experience by auto-filling the payment details. All you have to do is to supply a unique identifier in the payerReference property of the payer, and set generatePaymentToken to true. Supply these in the paymentOrder when starting a new payment. 

``` JSON
{
  "paymentorder": {
    "generatePaymentToken": true,
    "payer": {
    	"payerReference": unique-identifier
    }
    ...
  }
}
```

Just this tiny addition will make the SDK do most of the heavy lifting for you, and the customer can have the card details stored in a safe manner without sensitive information ever even touching your servers. More details in the [one-click payments documentation][one-click-payments].

After successful purchase (or verification), you can retrieve the token and reuse it in the future. Then payments will automatically start with the previous payment method, and all the information filled in. Just a button to press to accept the payment.

Retrieve the token by expanding the "paid" property of a previous successful payment, preferably you do this only on the backend, and then supply this token for the next purchase. To see this in action, the merchant backend has an endpoint called "/expand" that takes a "resource" (in this case the paymentId), and an array of properties to expand. You get a payment order back, and in the expanded paid property there is a "tokens" array (if the customer agreed to let you store the information). 

Read more on [expanding properties here][expanding_properties].

Create the next payment order with the token like this:

``` JSON
{
  "paymentorder": {
    "paymentToken": token-string-value
    "payer": {
    	"payerReference": unique-identifier
    }
    ...
  }
}
```

Now the payment menu will just show a purchase button and the payment method.
![Prefilled payment option image][one-click-image]

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

