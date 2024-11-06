//
// Copyright 2024 Swedbank AB
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

struct OperationOutputModel: Codable, Hashable {
    let rel: OperationRel?
    let href: String?
    let method: String?
    let next: Bool?
    let tasks: [IntegrationTask]?
    let expects: [ExpectationModel]?
}

extension OperationOutputModel {
    func firstTask(withRel rel: IntegrationTaskRel) -> IntegrationTask? {
        if let task = tasks?.first(where: { $0.rel == rel }) {
            return task
        }

        return nil
    }
}

extension Sequence where Iterator.Element == OperationOutputModel
{
    func firstOperation(withRel rel: OperationRel) -> OperationOutputModel? {
        return first(where: { $0.rel == rel })
    }
    
    func containsOperation(withRel rel: OperationRel) -> Bool {
        return firstOperation(withRel: rel) != nil
    }
}

enum OperationRel: Codable, Equatable, Hashable {
    case expandMethod
    case startPaymentAttempt
    case createAuthentication
    case completeAuthentication
    case getPayment
    case preparePayment
    case redirectPayer
    case acknowledgeFailedAttempt
    case abortPayment
    case eventLogging
    case viewPayment
    case attemptPayload
    case customizePayment
    case failPaymentAttempt

    case unknown(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let type = try container.decode(String.self)

        switch type {
        case Self.expandMethod.rawValue:                self = .expandMethod
        case Self.startPaymentAttempt.rawValue:         self = .startPaymentAttempt
        case Self.createAuthentication.rawValue:        self = .createAuthentication
        case Self.completeAuthentication.rawValue:      self = .completeAuthentication
        case Self.getPayment.rawValue:                  self = .getPayment
        case Self.preparePayment.rawValue:              self = .preparePayment
        case Self.redirectPayer.rawValue:               self = .redirectPayer
        case Self.acknowledgeFailedAttempt.rawValue:    self = .acknowledgeFailedAttempt
        case Self.abortPayment.rawValue:                self = .abortPayment
        case Self.eventLogging.rawValue:                self = .eventLogging
        case Self.viewPayment.rawValue:                 self = .viewPayment
        case Self.attemptPayload.rawValue:              self = .attemptPayload
        case Self.customizePayment.rawValue:            self = .customizePayment
        case Self.failPaymentAttempt.rawValue:          self = .failPaymentAttempt
        default:                                        self = .unknown(type)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    var rawValue: String {
        switch self {
        case .expandMethod:             "expand-method"
        case .startPaymentAttempt:      "start-payment-attempt"
        case .createAuthentication:     "create-authentication"
        case .completeAuthentication:   "complete-authentication"
        case .getPayment:               "get-payment"
        case .preparePayment:           "prepare-payment"
        case .redirectPayer:            "redirect-payer"
        case .acknowledgeFailedAttempt: "acknowledge-failed-attempt"
        case .abortPayment:             "abort-payment"
        case .eventLogging:             "event-logging"
        case .viewPayment:              "view-payment"
        case .attemptPayload:           "attempt-payload"
        case .customizePayment:         "customize-payment"
        case .failPaymentAttempt:       "fail-payment-attempt"
        case .unknown(let value):       value
        }
    }

    var isUnknown: Bool {
        if case .unknown = self { return true }

        return false
    }
}
