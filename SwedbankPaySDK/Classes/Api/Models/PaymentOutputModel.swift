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

struct PaymentOutputModel: Codable, Hashable {
    let paymentSession: PaymentSessionModel
    let operations: [OperationOutputModel]?
    let problem: SwedbankPaySDK.ProblemDetails?
}

extension PaymentOutputModel {
    var prioritisedOperations: [OperationOutputModel] {
        if let problemOperation = problem?.operation,
           problemOperation.rel?.isUnknown == false {
            return [problemOperation]
        }

        var operations = operations ?? []
        operations.append(contentsOf: paymentSession.allMethodOperations)

        operations = operations.filter({ $0.rel?.isUnknown == false })

        if operations.contains(where: { $0.next == true }) {
            operations = operations.filter({ $0.next == true })
        }

        return operations
    }

    func firstTask(with rel: IntegrationTaskRel) -> IntegrationTask? {
        guard let operations = operations else {
            return nil
        }

        for operation in operations {
            if let task = operation.tasks?.first(where: { $0.rel == rel }) {
                return task
            }
        }

        return nil
    }
}
