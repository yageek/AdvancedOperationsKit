//
//  Operation.swift
//  AdvancedOperationsKit-iOS
//
//  Created by Yannick Heinrich on 22.12.19.
//  Copyright © 2019 Yannick Heinrich. All rights reserved.
//

import Foundation

@objcMembers
open class Operation: Foundation.Operation {

    // MARK: - State Management
    private enum State: Int, Comparable {

        static func < (lhs: Operation.State, rhs: Operation.State) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }

        case initialized
        case pending
        case evaluatingConditions
        case ready
        case executing
        case finishing
        case finished

        func canTransitionToState(target: State) -> Bool {
            switch (self, target) {
            case (.initialized, .pending):
                return true
            case (.pending, .evaluatingConditions):
                return true
            case (.evaluatingConditions, .ready):
                return true
            case (.ready, .executing):
                return true
            case (.executing, .finishing):
                return true
            case (.finishing, .finished):
                return true
            default:
                return false
            }
        }
    }

    // MARK: - iVar | State
    private var lock = NSLock()
    private var _state: State = .initialized
    private var state: State {
        set {
            willChangeValue(for: \.state)

            lock.lock()
            guard _state != .finished else {
                lock.unlock()
                return
            }
            precondition(_state.canTransitionToState(target: newValue), "Invalid transitioning state")
            _state = newValue
            lock.unlock()

            didChangeValue(for: \.state)
        }

        get {
            let value: State
            lock.lock()
            value = _state
            lock.unlock()
            return value
        }
    }
    // use the KVO mechanism to indicate that changes to "state" affect other properties as well
    class func keyPathsForValuesAffectingIsReady() -> Set<String> {
        return ["state"]
    }

    class func keyPathsForValuesAffectingIsExecuting() -> Set<String> {
        return ["state"]
    }

    class func keyPathsForValuesAffectingIsFinished() -> Set<String> {
        return ["state"]
    }
    // MARK: - iVar | Ready
    open override var isReady: Bool {
        switch state {
        case .initialized:
            return isCancelled
        case .pending:
            guard !isCancelled else {
                return true
            }

            if super.isReady {
                evaluateConditions()
            }

            return false
        case .ready:
            return super.isReady || self.isCancelled
        default:
            return false
        }
    }

    open override var isExecuting: Bool {
        return state == .executing
    }

    open override var isFinished: Bool {
        return state == .finished
    }

    // MARK: - iVar | Conditions
    private(set) var conditions = [OperationCondition]()

    func addCondition(condition: OperationCondition) {
        assert(state < .evaluatingConditions, "Cannot modify conditions after execution has begun.")
        conditions.append(condition)
    }

    private func evaluateConditions() {
        precondition(state == .pending && !isCancelled, "Invalid time for evaluation conditions")
        state = .evaluatingConditions

        OperationConditionEvaluator.evaluate(conditions: conditions, operation: self) { failures in
            self._internalErrors.append(contentsOf: failures)
            self.state = .ready
        }
    }

    // MARK: - Errors
    private var _internalErrors: [Error] = []
}
