//
//  BlockObserver.swift
//  AdvancedOperationsKit-iOS
//
//  Created by Yannick Heinrich on 30.12.19.
//  Copyright © 2019 Yannick Heinrich. All rights reserved.
//

import Foundation
/**
    The `BlockObserver` is a way to attach arbitrary blocks to significant events
    in an `Operation`'s lifecycle.
*/
struct BlockObserver: OperationObserver {
    // MARK: Properties

    private let startHandler: ((Operation) -> Void)?
    private let produceHandler: ((Operation, Foundation.Operation) -> Void)?
    private let finishHandler: ((Operation, [Error]) -> Void)?

    init(startHandler: ((Operation) -> Void)? = nil, produceHandler: ((Operation, Foundation.Operation) -> Void)? = nil, finishHandler: ((Operation, [Error]) -> Void)? = nil) {
        self.startHandler = startHandler
        self.produceHandler = produceHandler
        self.finishHandler = finishHandler
    }

    // MARK: OperationObserver

    func operationDidStart(operation: Operation) {
        startHandler?(operation)
    }

    func operation(operation: Operation, didProduceOperation newOperation: Foundation.Operation) {
        produceHandler?(operation, newOperation)
    }

    func operationDidFinish(operation: Operation, errors: [Error]) {
        finishHandler?(operation, errors)
    }
}
