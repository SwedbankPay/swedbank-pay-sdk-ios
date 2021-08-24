// swift-tools-version:5.3
//
// Copyright 2021 Swedbank AB
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

import PackageDescription

let package = Package(
    name: "SwedbankPaySDK",
    platforms: [.iOS(.v10)],
    products: [
        .library(name: "SwedbankPaySDK", targets: ["SwedbankPaySDK"]),
        .library(name: "SwedbankPaySDKMerchantBackend", targets: ["SwedbankPaySDKMerchantBackend"])
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", .upToNextMajor(from: "5.4.0"))
    ],
    targets: [
        .target(
            name: "SwedbankPaySDK",
            path: "SwedbankPaySDK/Classes",
            resources: [.copy("SwedbankPaySDK/Resources/*")]
        ),
        
        .target(
            name: "SwedbankPaySDKMerchantBackend",
            dependencies: [
                .target(name: "SwedbankPaySDK"),
                .product(name: "Alamofire", package: "Alamofire")
            ],
            path: "SwedbankPaySDKMerchantBackend/Classes"
        )
    ]
)
