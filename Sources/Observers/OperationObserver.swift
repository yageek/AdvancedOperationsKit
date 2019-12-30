//
//  OperationObserver.swift
//  AdvancedOperationsKit-iOS
//
//  Created by Yannick Heinrich on 30.12.19.
//  Copyright © 2019 Yannick Heinrich. All rights reserved.
//

import Foundation

protocol OperationObserver {

    /// Invoked immediately prior to the `Operation`'s `execute()` method.
    func operationDidStart(operation: AdvancedOperationsKit.Operation)

    /// Invoked when `Operation.produceOperation(_:)` is executed.
    func operation(operation: Operation, didProduceOperation newOperation: Foundation.Operation)

    /**
        Invoked as an `Operation` finishes, along with any errors produced during
        execution (or readiness evaluation).
    */
    func operationDidFinish(operation: Operation, errors: [Error])

}
