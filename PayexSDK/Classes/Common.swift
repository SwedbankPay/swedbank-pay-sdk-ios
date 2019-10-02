import Foundation
import AlamofireObjectMapper
import ObjectMapper

typealias Closure<T> = (T) -> Void
typealias CallbackClosure = () -> Void

struct OperationsList: Mappable {
    var operations: [Operation] = []
    var state: State = .Undefined
    var url: String = ""
    var message: String = ""
    
    init?(map: Map) {
    }
    
    mutating func mapping(map: Map) {
        operations <- map["operations"]
        state <- (map["state"], EnumTransform<State>())
        url <- map["url"]
        message <- map["message"]
    }
}

struct Operation: Mappable {
    var contentType: String = ""
    var href: String?
    var method: OperationMethod = .GET
    var rel: String = ""
    
    init?(map: Map) {
    }
    
    mutating func mapping(map: Map) {
        contentType <- map["contentType"]
        href <- map["href"]
        method <- (map["method"], EnumTransform<OperationMethod>())
        rel <- map["rel"]
    }
}

enum OperationMethod: String {
    case GET
    case POST
    case PATCH
    case PUT
    case UPDATE
    case DELETE
}

enum State: String {
    case Undefined
    case Ready
    case Pending
    case Failed
    case Aborted
}

enum EndPointName: String {
    case consumers
    case paymentorders
    case paymentorder
}

enum ConsumerEvent: String {
    case onConsumerIdentified
    case onShippingDetailsAvailable
    case onError
}

enum PaymentEvent: String, Codable {
    case onPaymentMenuInstrumentSelected
    case onPaymentCompleted
    case onPaymentFailed
    case onPaymentCreated
    case onPaymentToS
    case onError
}

enum OperationTypeString: String {
    case viewConsumerIdentification = "view-consumer-identification"
    case viewPaymentOrder = "view-paymentorder"
}

enum WebViewType {
    case consumerIdentification // "checkin"
    case paymentOrder           // "checkout"
}

func createCheckinHTML(_ url: String) -> String {
    return """
<!DOCTYPE html>
<html>
<head>
    <title>PayEx Checkin is Awesome!</title>
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

func createCheckoutHTML(_ url: String) -> String {
    return """
<!DOCTYPE html>
<html>
<head>
    <title>PayEx Checkout is Awesome!</title>
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
