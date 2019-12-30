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
    func willEnqueue() {
        state = .pending
    }
    
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

    // MARK: - Observers
    private(set) var observers = [OperationObserver]()

    func addObserver(observer: OperationObserver) {
        assert(state < .executing, "Cannot modify observers after execution has begun.")

        observers.append(observer)
    }

    override open func addDependency(_ operation: Foundation.Operation) {
        assert(state < .executing, "Dependencies cannot be modified after execution has begun.")

        super.addDependency(operation)
    }

    // MARK: Execution and Cancellation

    override final public func start() {
        // NSOperation.start() contains important logic that shouldn't be bypassed.
        super.start()

        // If the operation has been cancelled, we still need to enter the "Finished" state.
        if isCancelled {
            finish()
        }
    }

    override final public func main() {
        assert(state == .ready, "This operation must be performed on an operation queue.")

        if _internalErrors.isEmpty && !isCancelled {
            state = .executing

            for observer in observers {
                observer.operationDidStart(operation: self)
            }

            execute()
        }
        else {
            finish()
        }
    }

    /**
     `execute()` is the entry point of execution for all `Operation` subclasses.
     If you subclass `Operation` and wish to customize its execution, you would
     do so by overriding the `execute()` method.

     At some point, your `Operation` subclass must call one of the "finish"
     methods defined below; this is how you indicate that your operation has
     finished its execution, and that operations dependent on yours can re-evaluate
     their readiness state.
     */
    func execute() {
        print("\(type(of: self)) must override `execute()`.")

        finish()
    }

    // MARK: Finishing

    /**
        Most operations may finish with a single error, if they have one at all.
        This is a convenience method to simplify calling the actual `finish()`
        method. This is also useful if you wish to finish with an error provided
        by the system frameworks. As an example, see `DownloadEarthquakesOperation`
        for how an error from an `NSURLSession` is passed along via the
        `finishWithError()` method.
    */
    final func finishWithError(error: Error?) {
        if let error = error {
            finish(errors: [error])
        }
        else {
            finish()
        }
    }

    /**
        A private property to ensure we only notify the observers once that the
        operation has finished.
    */
    private var hasFinishedAlready = false
    final func finish(errors: [Error] = []) {
        if !hasFinishedAlready {
            hasFinishedAlready = true
            state = .finishing

            let combinedErrors = _internalErrors + errors
            finished(errors: combinedErrors)

            for observer in observers {
                observer.operationDidFinish(operation: self, errors: combinedErrors)
            }

            state = .finished
        }
    }

    /**
        Subclasses may override `finished(_:)` if they wish to react to the operation
        finishing with errors. For example, the `LoadModelOperation` implements
        this method to potentially inform the user about an error when trying to
        bring up the Core Data stack.
    */
    func finished(errors: [Error]) {
        // No op.
    }

    override final public func waitUntilFinished() {
        /*
            Waiting on operations is almost NEVER the right thing to do. It is
            usually superior to use proper locking constructs, such as `dispatch_semaphore_t`
            or `dispatch_group_notify`, or even `NSLocking` objects. Many developers
            use waiting when they should instead be chaining discrete operations
            together using dependencies.

            To reinforce this idea, invoking `waitUntilFinished()` will crash your
            app, as incentive for you to find a more appropriate way to express
            the behavior you're wishing to create.
        */
        fatalError("Waiting on operations is an anti-pattern. Remove this ONLY if you're absolutely sure there is No Other Way™.")
    }
}
