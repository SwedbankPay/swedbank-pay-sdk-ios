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

public extension SwedbankPaySDK {
    /// Problem details returned with `sessionProblemOccurred`
    struct ProblemDetails: Codable, Hashable {
        public let type: String
        public let title: String?
        public let status: Int32?
        public let detail: String?

        let operation: OperationOutputModel?
    }
}
