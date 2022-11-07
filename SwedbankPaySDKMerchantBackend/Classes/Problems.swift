//
// Copyright 2020 Swedbank AB
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

import Foundation
import SwedbankPaySDK
import Alamofire

enum Problems {
    static func parseProblem(
        response: AFDataResponse<Data>
    ) -> SwedbankPaySDK.Problem {
        do {
            return try parseProblemOrFail(response: response)
        } catch {
            return makeUnexpectedContentProblem(response: response)
        }
    }
    
    static func makeUnexpectedContentProblem(
        response: AFDataResponse<Data>
    ) -> SwedbankPaySDK.Problem {
        // we should always have response here, but we need some value
        let status = response.response?.statusCode ?? -1
        let isClient = (400...499).contains(status)
        if isClient {
            return .client(.unexpectedContent(
                status: status,
                contentType: response.response?.mimeType,
                body: response.data
            ))
        } else {
            return .server(.unexpectedContent(
                status: status,
                contentType: response.response?.mimeType,
                body: response.data
            ))
        }
    }
}

private typealias JsonObject = [String: Any]

private extension JsonObject {
    var type: String { self["type"] as? String ?? "about:blank" }
    var title: String? { self["title"] as? String }
    var status: Int? { self["status"] as? Int }
    var detail: String? { self["detail"] as? String }
    var instance: String? { self["instance"] as? String }
}

private func parseProblemOrFail(
    response: AFDataResponse<Data>
) throws -> SwedbankPaySDK.Problem {
    let data = try requireSome(response.data)
    let jsonValue = try JSONSerialization.jsonObject(with: data)
    let json = try requireSome(jsonValue as? JsonObject)
    let status = try json.status ?? requireSome(response.response).statusCode
    let problemSpace = try getProblemSpace(status: status)
    return problemSpace.parseProblem(status: status, json: json)
}

private func getProblemSpace(status: Int) throws -> ProblemSpace {
    switch status {
    case 400...499: return clientProblems
    case 500...599: return serverProblems
    default: throw PreconditionError.instance
    }
}

private struct ProblemSpace {
    private let parseProblemOfType: (String, Int, JsonObject) -> SwedbankPaySDK.Problem
    
    init<T>(
        problemType: @escaping (T) -> SwedbankPaySDK.Problem,
        unknownProblemType: @escaping (String, String?, Int, String?, String?, [String: Any]) -> T,
        parseKnownProblem: @escaping (String, Int, JsonObject) -> T?
    ) {
        parseProblemOfType = { type, status, json in
            let payload = parseKnownProblem(type, status, json)
                ?? ProblemSpace.makeUnknownProblem(type, status, json, unknownProblemType)
            return problemType(payload)
        }
    }
    
    func parseProblem(status: Int, json: JsonObject) -> SwedbankPaySDK.Problem {
        let type = json.type
        return parseProblemOfType(type, status, json)
    }
    
    private static func makeUnknownProblem<T>(
        _ type: String,
        _ status: Int,
        _ json: JsonObject,
        _ unknownProblemType: (String, String?, Int, String?, String?, [String: Any]) -> T
    ) -> T {
        return unknownProblemType(
            type, json.title, status, json.detail, json.instance, json
        )
    }
}

private let clientProblems = ProblemSpace(
    problemType: SwedbankPaySDK.Problem.client,
    unknownProblemType: SwedbankPaySDK.ClientProblem.unknown
) { type, status, json in
    switch type {
    case "https://api.payex.com/psp/errordetail/mobilesdk/unauthorized":
        return .mobileSDK(.unauthorized(message: json.detail, raw: json))
    case "https://api.payex.com/psp/errordetail/mobilesdk/badrequest":
        return .mobileSDK(.invalidRequest(message: json.detail, raw: json))
    case "https://api.payex.com/psp/errordetail/inputerror":
        return parseSwedbankPayProblem(SwedbankPaySDK.ClientProblem.swedbankPay, .inputError, status, json)
    case "https://api.payex.com/psp/errordetail/forbidden":
        return parseSwedbankPayProblem(SwedbankPaySDK.ClientProblem.swedbankPay, .forbidden, status, json)
    case "https://api.payex.com/psp/errordetail/notfound":
        return parseSwedbankPayProblem(SwedbankPaySDK.ClientProblem.swedbankPay, .notFound, status, json)
    default:
        return nil
    }
}

private let serverProblems = ProblemSpace(
    problemType: SwedbankPaySDK.Problem.server,
    unknownProblemType: SwedbankPaySDK.ServerProblem.unknown
) { type, status, json in
    switch type {
    case "https://api.payex.com/psp/errordetail/mobilesdk/gatewaytimeout":
        return .mobileSDK(.backendConnectionTimeout(message: json.detail, raw: json))
    case "https://api.payex.com/psp/errordetail/mobilesdk/badgateway":
        return .mobileSDK(parseBadGatewayProblem(status, json))
    case "https://api.payex.com/psp/errordetail/systemerror":
        return parseSwedbankPayProblem(SwedbankPaySDK.ServerProblem.swedbankPay, .systemError, status, json)
    case "https://api.payex.com/psp/errordetail/configurationerror":
        return parseSwedbankPayProblem(SwedbankPaySDK.ServerProblem.swedbankPay, .configurationError, status, json)
    default:
        return nil
    }
}

private func parseBadGatewayProblem(
    _ status: Int,
    _ json: JsonObject
) -> SwedbankPaySDK.ServerProblem.MobileSDKProblem {
    // a https://api.payex.com/psp/errordetail/mobilesdk/badgateway
    // problem will have a "gatewayStatus" field if and only if it originated from a bogus
    // Swedbank response.
    if let gatewayStatus = json["gatewayStatus"] as? Int {
        let body = json["body"] as? String
        return .invalidBackendResponse(status: status, gatewayStatus: gatewayStatus, body: body, raw: json)
    } else {
        return .backendConnectionFailure(message: json.detail, raw: json)
    }
    
}

private func parseSwedbankPayProblem<T, S>(
    _ type: (S, String?, Int, String?, String?, String?, [SwedbankPaySDK.SwedbankPaySubProblem]?, [String: Any]) -> T,
    _ subtype: S,
    _ status: Int,
    _ json: JsonObject
) -> T {
    let problems = (json["problems"] as? [Any])?.compactMap { subproblem in
        (subproblem as? JsonObject).map {
            SwedbankPaySDK.SwedbankPaySubProblem(
                name: $0["name"] as? String,
                description: $0["description"] as? String
            )
        }
    }
    return type(
        subtype, json.title, status, json.detail, json.instance, json["action"] as? String, problems, json
    )
}
