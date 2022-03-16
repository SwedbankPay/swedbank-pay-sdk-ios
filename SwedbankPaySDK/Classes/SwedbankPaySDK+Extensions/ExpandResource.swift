//
//  ExpandResource.swift
//  SwedbankPaySDK
//
//  Created by Olof Thorén on 2022-03-15.
//  Copyright © 2022 Swedbank. All rights reserved.
//

import Foundation

extension SwedbankPaySDK {
public enum ExpandResource: String, Encodable {
    
    case orderItems
    case urls
    case payeeInfo
    case payer
    case history
    case failed
    case aborted
    case paid
    case cancelled
    case financialTransactions
    case failedAttempts
    case metadata
}
}
