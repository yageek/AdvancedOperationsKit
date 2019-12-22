//
//  OperationCondition.swift
//  AdvancedOperationsKit-iOS
//
//  Created by Yannick Heinrich on 22.12.19.
//  Copyright © 2019 Yannick Heinrich. All rights reserved.
//

import Foundation

typealias OperationConditionResult = Result<(), Error>

protocol OperationCondition {

    static var name: String { get }

    static var isMutuallyExclusive: Bool { get }

    func dependencyForOperation(operation: Operation) -> Foundation.Operation?

       /// Evaluate the condition, to see if it has been satisfied or not.
    func evaluateForOperation(_ operation: Operation, completion: @escaping (OperationConditionResult) -> Void)
}

extension OperationConditionResult {
    var error: Error? {
        do {
            let _ = try get()
            return nil
        } catch let error {
            return error
        }
    }
}

struct OperationConditionEvaluator {
    static func evaluate(conditions: [OperationCondition], operation: Operation, completion: @escaping ([Error]) -> Void) {
        // Check conditions.
        let conditionGroup = DispatchGroup()

        var results = [OperationConditionResult?](repeating: nil, count: conditions.count)

        // Ask each condition to evaluate and store its result in the "results" array.
        for (index, condition) in conditions.enumerated() {
            conditionGroup.enter()
            condition.evaluateForOperation(operation) { result in
                results[index] = result
                conditionGroup.leave()
            }
        }

        conditionGroup.notify(queue: DispatchQueue.global(qos: .default)) {

            // Aggregate the errors that occurred, in order.
            var failures = results.compactMap { $0?.error }

            /*
                If any of the conditions caused this operation to be cancelled,
                check for that.
            */
            if operation.isCancelled {
                failures.append(OperationError.conditionFailed)
            }

            completion(failures)
        }
    }
}
