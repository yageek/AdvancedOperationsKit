//
//  ExclusivityController.swift
//  AdvancedOperationsKit-iOS
//
//  Created by Yannick Heinrich on 30.12.19.
//  Copyright © 2019 Yannick Heinrich. All rights reserved.
//

import Foundation

/**
    `ExclusivityController` is a singleton to keep track of all the in-flight
    `Operation` instances that have declared themselves as requiring mutual exclusivity.
    We use a singleton because mutual exclusivity must be enforced across the entire
    app, regardless of the `OperationQueue` on which an `Operation` was executed.
*/
class ExclusivityController {
    static let sharedExclusivityController = ExclusivityController()

    private let serialQueue = DispatchQueue(label: "Operations.ExclusivityController")
    private var operations: [String: [Operation]] = [:]

    private init() {
        /*
            A private initializer effectively prevents any other part of the app
            from accidentally creating an instance.
        */
    }

    /// Registers an operation as being mutually exclusive
    func addOperation(operation: Operation, categories: [String]) {
        /*
            This needs to be a synchronous operation.
            If this were async, then we might not get around to adding dependencies
            until after the operation had already begun, which would be incorrect.
        */
        serialQueue.async {
            for category in categories {
                self.noqueue_addOperation(operation: operation, category: category)
            }
        }
    }

    /// Unregisters an operation from being mutually exclusive.
    func removeOperation(operation: Operation, categories: [String]) {
        serialQueue.async {
            for category in categories {
                self.noqueue_removeOperation(operation: operation, category: category)
            }
        }
    }


    // MARK: Operation Management

    private func noqueue_addOperation(operation: Operation, category: String) {
        var operationsWithThisCategory = operations[category] ?? []

        if let last = operationsWithThisCategory.last {
            operation.addDependency(last)
        }

        operationsWithThisCategory.append(operation)

        operations[category] = operationsWithThisCategory
    }

    private func noqueue_removeOperation(operation: Operation, category: String) {
        let matchingOperations = operations[category]

        if var operationsWithThisCategory = matchingOperations,
            let index = operationsWithThisCategory.firstIndex(of: operation) {

            operationsWithThisCategory.remove(at: index)
            operations[category] = operationsWithThisCategory
        }
    }

}
