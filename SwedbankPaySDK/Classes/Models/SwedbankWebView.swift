//
// Copyright 2019 Swedbank AB
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

class SwedbankWebView {
    enum ConsumerEvent: String {
        case onConsumerIdentified
        case onShippingDetailsAvailable
        case onError
    }

    enum PaymentEvent: String {
        case onPaymentMenuInstrumentSelected
        case onPaymentCompleted
        case onPaymentFailed
        case onPaymentCreated
        case onPaymentToS
        case onError
    }

    enum ActionType {
        case consumerIdentification // "checkin"
        case paymentOrder           // "checkout"
    }

    class func createCheckinHTML(_ url: String) -> String {
        return """
            <!DOCTYPE html>
            <html>
            <head>
                <title>Swedbank Pay Checkin is Awesome!</title>
                <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
            </head>
            <body>
            <div id="checkin" />
            <script data-payex-hostedview="checkin" src="\(url)"></script>
            <script language="javascript">
                payex.hostedView.consumer({
                    container: "checkin",
                    onConsumerIdentified: function(consumerIdentifiedEvent) {
                        webkit.messageHandlers.onConsumerIdentified.postMessage(consumerIdentifiedEvent.consumerProfileRef);
                    },
                    onShippingDetailsAvailable: function(shippingDetailsAvailable){
                        webkit.messageHandlers.onShippingDetailsAvailable.postMessage(shippingDetailsAvailable);
                    },
                    onError: function(error) {
                        webkit.messageHandlers.onIdentifyError.postMessage(error);
                    }
                }).open();
            </script>
            </body>
            </html>
        """
    }

    class func createCheckoutHTML(_ url: String) -> String {
        return """
            <!DOCTYPE html>
            <html>
            <head>
                <title>Swedbank Pay Checkout is Awesome!</title>
                <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
            </head>
            <body>
            <div id="checkout" />
            <script src="\(url)"></script>
            <script language="javascript">
                payex.hostedView.paymentMenu({
                    container: "checkout",
                    onPaymentMenuInstrumentSelected: function(event) {
                        webkit.messageHandlers.onPaymentMenuInstrumentSelected.postMessage(event);
                    },
                    onPaymentCompleted: function(event) {
                        webkit.messageHandlers.onPaymentCompleted.postMessage(event);
                    },
                    onPaymentFailed: function(event) {
                        webkit.messageHandlers.onPaymentFailed.postMessage(event);
                    },
                    onPaymentCreated: function(event) {
                        webkit.messageHandlers.onPaymentCreated.postMessage(event);
                    },
                    onPaymentToS: function(event) {
                        webkit.messageHandlers.onPaymentToS.postMessage(event);
                    },
                    onError: function(error) {
                        webkit.messageHandlers.onPaymentError.postMessage(event);
                    }
                }).open();
            </script>
            </body>
            </html>
        """
    }
}

