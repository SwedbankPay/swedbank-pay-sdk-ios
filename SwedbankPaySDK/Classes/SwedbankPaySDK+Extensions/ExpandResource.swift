//
//  ExpandResource.swift
//  SwedbankPaySDK
//
//  Created by Olof Thorén on 2022-03-15.
//  Copyright © 2022 Swedbank. All rights reserved.
//

import Foundation

public extension SwedbankPaySDK {
    struct ExpandResource: RawRepresentable, Encodable {
        public typealias RawValue = String
        public var rawValue: String
        
        public init(rawValue: RawValue) {
            self.rawValue = rawValue
        }
        
        public static let orderItems = ExpandResource(rawValue: "orderItems")
        public static let urls = ExpandResource(rawValue: "urls")
        public static let payeeInfo = ExpandResource(rawValue: "payeeInfo")
        public static let payer = ExpandResource(rawValue: "payer")
        public static let history = ExpandResource(rawValue: "history")
        public static let failed = ExpandResource(rawValue: "failed")
        public static let aborted = ExpandResource(rawValue: "aborted")
        public static let paid = ExpandResource(rawValue: "paid")
        public static let cancelled = ExpandResource(rawValue: "cancelled")
        public static let financialTransactions = ExpandResource(rawValue: "financialTransactions")
        public static let failedAttempts = ExpandResource(rawValue: "failedAttempts")
        public static let metadata = ExpandResource(rawValue: "metadata")
    }
}
