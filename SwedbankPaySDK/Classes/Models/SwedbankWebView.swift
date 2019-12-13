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

private let paymentMenuDelay = "500"

enum SwedbankWebView {}

extension SwedbankWebView {
    static let scriptMessageHandlerName = "swedbankpay"
}

extension SwedbankWebView {
    struct HTMLTemplate<T: RawRepresentable> where T.RawValue == String {
        private let components: [TemplateComponent]
        
        func buildPage(scriptUrl: String, delay: Bool = false) -> String {
            let strings: [String] = components.map {
                switch $0 {
                case .literal(let literal):
                    return literal
                case .delay:
                    return delay.description
                case .scriptUrl:
                    return scriptUrl
                }
            }
            return strings.joined()
        }
        
        func createScriptMessageHandler(eventHandler: @escaping (T, Any?) -> Void) -> WKScriptMessageHandler {
            return CallbackScriptMessageHandler(eventHandler: eventHandler)
        }
    }
}

extension SwedbankWebView {
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
                        payex.hostedView.consumer({
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
                        }).open();
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

extension SwedbankWebView {
    enum PaymentEvent: String {
        case onScriptLoaded
        case onScriptError
        case onPaymentMenuInstrumentSelected
        case onPaymentCompleted
        case onPaymentFailed
        case onPaymentCreated
        case onPaymentToS
        case onError
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
                        payex.hostedView.paymentMenu({
                            container: "checkout",
                            onPaymentMenuInstrumentSelected: function(event) {
                                \(PaymentEvent.onPaymentMenuInstrumentSelected, "event");
                            },
                            onPaymentCompleted: function(event) {
                                \(PaymentEvent.onPaymentCompleted, "event");
                            },
                            onPaymentFailed: function(event) {
                                \(PaymentEvent.onPaymentFailed, "event")
                            },
                            onPaymentCreated: function(event) {
                                \(PaymentEvent.onPaymentCreated, "event");
                            },
                            onPaymentToS: function(event) {
                                \(PaymentEvent.onPaymentToS, "event");
                            },
                            onError: function(error) {
                                \(PaymentEvent.onError, "event");
                            }
                        }).open();
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
}

private extension SwedbankWebView {
    enum TemplateComponent {
        case literal(String)
        case delay
        case scriptUrl
    }
}

extension SwedbankWebView.HTMLTemplate : ExpressibleByStringInterpolation {
    init(stringInterpolation: StringInterpolation) {
        components = stringInterpolation.components
    }
    init(stringLiteral value: String) {
        components = [.literal(value)]
    }
    
    struct StringInterpolation : StringInterpolationProtocol {
        fileprivate var components: [SwedbankWebView.TemplateComponent] = []
        
        init(literalCapacity: Int, interpolationCount: Int) {
            components.reserveCapacity(2 * interpolationCount + 1)
        }
        
        mutating func appendLiteral(_ literal: String) {
            components.append(.literal(literal))
        }
        
        mutating func appendInterpolation(_ event: T, _ argument: String) {
            appendLiteral(SwedbankWebView.emitCallback(event: event.rawValue, argument: argument))
        }
        
        fileprivate mutating func appendInterpolation(_ component: SwedbankWebView.TemplateComponent) {
            components.append(component)
        }
    }
}

private extension SwedbankWebView {
    private static let messageNameKey = "msg"
    private static let messageArgumentKey = "arg"
    
    private static func buildMessageBody(event: String, argument: String) -> String {
        return "{\(messageNameKey):'\(event)',\(messageArgumentKey):\(argument)}"
    }
    private static func parse<T: RawRepresentable>(messageBody: Any) -> (event: T, argument: Any?)? where T.RawValue == String {
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
