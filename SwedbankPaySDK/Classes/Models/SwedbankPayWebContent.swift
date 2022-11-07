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

import WebKit

internal let paymentMenuDelay = "500"

enum SwedbankPayWebContent {}

extension SwedbankPayWebContent {
    static let scriptMessageHandlerName = "swedbankpay"
}

extension SwedbankPayWebContent {
    struct HTMLTemplate<T: RawRepresentable> where T.RawValue == String {
        internal let components: [TemplateComponent]
        
        func buildPage(
            scriptUrl: String,
            style: [String: Any]?,
            delay: Bool = false
        ) -> String {
            let strings: [String] = components.map {
                switch $0 {
                case .literal(let literal):
                    return literal
                case .delay:
                    return delay.description
                case .scriptUrl:
                    return scriptUrl
                case .style:
                    return SwedbankPayWebContent.makeStyleJs(from: style)
                }
            }
            return strings.joined()
        }
        
        func createScriptMessageHandler(eventHandler: @escaping (T, Any?) -> Void) -> WKScriptMessageHandler {
            return CallbackScriptMessageHandler(eventHandler: eventHandler)
        }
    }
}

extension SwedbankPayWebContent {
    enum ConsumerEvent: String {
        case onScriptLoaded
        case onScriptError
        case onConsumerIdentified
        case onShippingDetailsAvailable
        case onError
    }
    
    static let checkInTemplate: HTMLTemplate<ConsumerEvent> = """
    <!DOCTYPE html>
    <html>
        <head>
            <title>Swedbank Pay Checkin is Awesome!</title>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
            <script language="javascript">
                window.onload = function () {
                    var url = '\(TemplateComponent.scriptUrl)';
                    var script = document.createElement('script');
                    script.setAttribute('src', url);
                    script.onload = function () {
                        \(ConsumerEvent.onScriptLoaded, "null");
                        var parameters = {
                            container: "checkin",
                            onConsumerIdentified: function(consumerIdentifiedEvent) {
                                \(ConsumerEvent.onConsumerIdentified, "consumerIdentifiedEvent.consumerProfileRef");
                            },
                            onShippingDetailsAvailable: function(shippingDetailsAvailable) {
                                \(ConsumerEvent.onShippingDetailsAvailable, "shippingDetailsAvailable");
                            },
                            onError: function(error) {
                                \(ConsumerEvent.onError, "error");
                            }
                        };
                        var style = \(TemplateComponent.style);
                        if (style) {
                            parameters.style = style;
                        }
                        payex.hostedView.consumer(parameters).open();
                    };
                    script.onerror = function(event) {
                        \(ConsumerEvent.onScriptError, "url");
                    };
                    var head = document.getElementsByTagName('head')[0];
                    head.appendChild(script);
                };
            </script>
        </head>
        <body>
            <div id="checkin" />
        </body>
    </html>
    """
}

extension SwedbankPayWebContent {
    enum PaymentEvent: String {
        case onScriptLoaded
        case onScriptError
        case onError
        case payerIdentified
        case generalEvent
        case onPaid
    }
    
    static let paymentTemplate: HTMLTemplate<PaymentEvent> = """
    <!DOCTYPE html>
    <html>
        <head>
            <title>Swedbank Pay Checkout is Awesome!</title>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
    
            <script language="javascript">
                function loadPaymentMenu() {
                    var url = '\(TemplateComponent.scriptUrl)';
                    var script = document.createElement('script');
                    script.setAttribute('src', url);
                    script.onload = function () {
                        \(PaymentEvent.onScriptLoaded, "null");
                        var parameters = {
                            container: "checkout",
                            onError: function(error) {
                                \(PaymentEvent.onError, "error");
                            }
                        };
                        var style = \(TemplateComponent.style);
                        if (style) {
                            parameters.style = style;
                        }
                        payex.hostedView.paymentMenu(parameters).open();
                    };
                    script.onerror = function(event) {
                        \(PaymentEvent.onScriptError, "url");
                    };
                    var head = document.getElementsByTagName('head')[0];
                    head.appendChild(script);
                }
    
                window.onload = function () {
                    if (\(TemplateComponent.delay)) {
                        window.setTimeout(loadPaymentMenu, \(TemplateComponent.literal(paymentMenuDelay)));
                    } else {
                        loadPaymentMenu();
                    }
                };
            </script>
        </head>
        <body>
            <div id="checkout" />
        </body>
    </html>
    """
    
    static let paymentTemplateV3: HTMLTemplate<PaymentEvent> = """
    <!DOCTYPE html>
    <html>
        <head>
            <title>Swedbank Pay Checkout is Awesome!</title>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
            <script type="text/javascript">
                
                window.onerror = function(message, source, lineno, colno, error) {
                    var url = '\(TemplateComponent.scriptUrl)';
                    \(PaymentEvent.onScriptError, "url");
                }
                
                function loadPaymentMenu() {
    
                    \(PaymentEvent.onScriptLoaded, "null");
                    var parameters = {
                        container: {
                            checkout: "checkout"
                        },
                        onPayerIdentified: function onPayerIdentified(payerIdentified) {
                            \(PaymentEvent.payerIdentified, "payerIdentified");
                        },
                        onEventNotification: function onEventNotification(eventNotification) {
                            if (eventNotification.sourceEvent == "OnPayerIdentified") {
                                \(PaymentEvent.payerIdentified, "eventNotification");
                            } else {
                                \(PaymentEvent.generalEvent, "eventNotification");
                            }
                        },
                        onError: function(error) {
                            \(PaymentEvent.onError, "error");
                        },
                        onPaid: function onPaid(eventNotification) {
                            \(PaymentEvent.onPaid, "eventNotification");
                        }
                    }
                    var style = \(TemplateComponent.style);
                    if (style) {
                        parameters.style = style;
                    }
                    window.payex.hostedView.checkout(parameters).open("checkout");
                };
    
                window.onload = function () {
                    if (\(TemplateComponent.delay)) {
                        window.setTimeout(loadPaymentMenu, \(TemplateComponent.literal(paymentMenuDelay)));
                    } else {
                        loadPaymentMenu();
                    }
                };

            </script>
        </head>
        <body>
            <div id="checkout" />
            <script src="\(TemplateComponent.scriptUrl)"></script>
        </body>
    </html>
    """
}

internal extension SwedbankPayWebContent {
    enum TemplateComponent {
        case literal(String)
        case delay
        case scriptUrl
        case style
    }
}

extension SwedbankPayWebContent.HTMLTemplate : ExpressibleByStringInterpolation {
    init(stringInterpolation: StringInterpolation) {
        components = stringInterpolation.components
    }
    init(stringLiteral value: String) {
        components = [.literal(value)]
    }
    
    struct StringInterpolation : StringInterpolationProtocol {
        fileprivate var components: [SwedbankPayWebContent.TemplateComponent] = []
        
        init(literalCapacity: Int, interpolationCount: Int) {
            components.reserveCapacity(2 * interpolationCount + 1)
        }
        
        mutating func appendLiteral(_ literal: String) {
            components.append(.literal(literal))
        }
        
        mutating func appendInterpolation(_ event: T, _ argument: String) {
            appendLiteral(SwedbankPayWebContent.emitCallback(event: event.rawValue, argument: argument))
        }
        
        fileprivate mutating func appendInterpolation(_ component: SwedbankPayWebContent.TemplateComponent) {
            components.append(component)
        }
    }
}

internal extension SwedbankPayWebContent {
    static let messageNameKey = "msg"
    static let messageArgumentKey = "arg"
    
    static func buildMessageBody(event: String, argument: String) -> String {
        return "{\(messageNameKey):'\(event)',\(messageArgumentKey):\(argument)}"
    }
    static func parse<T: RawRepresentable>(messageBody: Any) -> (event: T, argument: Any?)? where T.RawValue == String {
        let bodyDict = messageBody as? [String: Any]
        let name = bodyDict?[messageNameKey] as? String
        let event = name.flatMap(T.init(rawValue:))
        return event.map { ($0, bodyDict?[messageArgumentKey]) }
    }
    
    static func emitCallback(event: String, argument: String) -> String {
        let body = buildMessageBody(event: event, argument: argument)
        return "webkit.messageHandlers.\(scriptMessageHandlerName).postMessage(\(body))"
    }
    
    class CallbackScriptMessageHandler<T: RawRepresentable> : NSObject, WKScriptMessageHandler where T.RawValue == String {
        let eventHandler: (T, Any?) -> Void
        init(eventHandler: @escaping (T, Any?) -> Void) {
            self.eventHandler = eventHandler
            super.init()
        }
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == scriptMessageHandlerName, let body: (T, Any?) = parse(messageBody: message.body) {
                eventHandler(body.0, body.1)
            }
        }
    }
}

internal extension SwedbankPayWebContent {
    static func makeStyleJs(from style: [String: Any]?) -> String {
        let data = style.flatMap { try? JSONSerialization.data(withJSONObject: $0) }
        let string = data.flatMap { String(data: $0, encoding: .utf8) }
        return string ?? "null"
    }
}
