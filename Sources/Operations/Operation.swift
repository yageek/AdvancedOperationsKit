//
//  Operation.swift
//  AdvancedOperationsKit-iOS
//
//  Created by Yannick Heinrich on 22.12.19.
//  Copyright © 2019 Yannick Heinrich. All rights reserved.
//

import Foundation

/// The error proposed by the framework
public enum OperationError: Error {
    case conditionsFailed
}

/// An `Operation` subclass based on the orignal
/// advanced nsoperations WWDC talk
@objcMembers
open class Operation: Foundation.Operation, OperationProtocol {

    private static var KVOCtx = 0

    // MARK: - KVO
    /// :nodoc:
    public class func keyPathsForValuesAffectingIsReady() -> Set<String> {
        return ["state"]
    }

    /// :nodoc:
    open class func keyPathsForValuesAffectingIsExecuting() -> Set<String> {
        return ["state"]
    }

    /// :nodoc:
    open class func keyPathsForValuesAffectingIsFinished() -> Set<String> {
        return ["state"]
    }

    // MARK: - State
    /// The state of the operation
    @objc
    enum State: Int, Equatable, Comparable, CustomStringConvertible {
        /// The initial state
        case initialized
        /// Operation is ready to evaluate conditions
        case pending
        case evaluatingConditions
        case ready
        case executing
        case finishing
        case finished

        /// Allowed state's transitions
        func canTransitionToState(state: State) -> Bool {
            switch (self, state) {
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

        static func<(lhs: State, rhs: State) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }

        var description: String {
            switch self {
            case .initialized:
                return "initialized"
            case .pending:
                return "pending"
            case .evaluatingConditions:
                return "evaluatingConditions"
            case .ready:
                return "ready"
            case .executing:
                return "executing"
            case .finishing:
                return "finishing"
            case .finished:
                return "finished"
            }
        }
    }

    public override init() {
        super.init()
        self.addObserver(self, forKeyPath: "isReady", options: [], context: &Operation.KVOCtx)
    }

    deinit {
        self.removeObserver(self, forKeyPath: "isReady", context: &Operation.KVOCtx)
    }

    @objc dynamic private var _state: State = .initialized

    // Lock for the state
    private let stateLock = NSLock()

    @objc dynamic private var state: State {
        get {
            let value: State
            stateLock.lock()
            defer { stateLock.unlock() }
            value = _state
            return value
        }

        set {
            willChangeValue(for: \Operation.state)

            stateLock.lock()

            guard _state != .finished else { stateLock.unlock(); return }

            assert(_state.canTransitionToState(state: newValue), "Invalid transition state for \(self): \(_state) -> \(newValue)")

            _state = newValue
            stateLock.unlock()
            didChangeValue(for: \Operation.state)

        }
    }

    // MARK: - Override property
    open override var isReady: Bool {

        guard super.isReady else { return false }

        guard !isCancelled else { return true }

        switch self.state {
        case .initialized, .evaluatingConditions, .pending:
            return false
        case .ready, .executing, .finished, .finishing:
            return true
        }
    }

    open override var isExecuting: Bool {
        return state == .executing
    }

    open override var isFinished: Bool {
        return state == .finished
    }

    func willEnqueue() {
         state = .pending
     }

    // MARK: - Observer
    private(set) var observers = [OperationObserver]()

    /// Add an observer to the operation
    /// - Parameter observer: The observer to add
    public func addObserver( _ observer: OperationObserver) {
        assert(state < .executing, "Cannot modify observers after execution has begun.")
        observers.append(observer)
    }

    // MARK: - Conditions
    private(set) var conditions: [OperationCondition] = []

    private func evaluateConditions() {
        assert(self.state == .pending && !self.isCancelled, "bad call of evaluate conditions")

        state = .evaluatingConditions

        OperationConditionEvaluator.evaluate(conditions: self.conditions, operation: self) { (errors) in
            self._internalErrors = errors
            self.state = .ready
        }
    }

    /// Add a condition
    /// - Parameter condition: The condition to add
    public func addCondition(_ condition: OperationCondition) {
        assert(state < .evaluatingConditions, "Cannot modify conditions after execution has begun.")
        conditions.append(condition)
    }

    open override func addDependency(_ op: Foundation.Operation) {
        assert(state < .executing, "Dependencies cannot be modified after execution has begun.")
        super.addDependency(op)
    }

    // MARK: - Errors
    private var _internalErrors: [Error] = []

    func cancelWithError(error: NSError? = nil) {
        if let error = error {
            _internalErrors.append(error)
        }

        cancel()
    }

    // MARK: - start, main
     public override final func start() {
        super.start()

        if self.isCancelled {
            self.finish()
        }
    }

    open override func main() {
        assert(state == .ready, "Should be ready to start the work")

        if _internalErrors.isEmpty && !self.isCancelled {
            state = .executing

            for observer in observers {
                observer.operationDidStart(self)
            }
            self.execute()
        } else {
            self.finish()
        }
    }

    /// Implements the work inside this method
    open func execute() { self.finish() }

    public final func produceOperation(operation: Foundation.Operation) {
        for observer in observers {
            observer.operation(self, didProduceOperation: operation)
        }
    }

    // MARK: - Finish
    private var hasFinishedAlready: Bool = false

    /// Finish with several errors
    /// - Parameter errors: The errors
    public final func finish(withErrors errors: [Error] = []) {
        if !hasFinishedAlready {
            hasFinishedAlready = true
            state = .finishing

            let combinedErrors = _internalErrors + errors
            finished(withErrors: combinedErrors)

            for observer in observers {
                observer.operationDidFinish(self, errors: combinedErrors)
            }

            state = .finished
        }
    }

    /// Finish the operation with an error
    /// - Parameter error: The error if any occured
    public final func finish(withError error: Error?) {
        if let error = error {
           finish(withErrors: [error])
        } else {
            finish()
        }
    }

    /// Overrides this class to have a custom behaviour during the
    /// the finsih of the procedure
    /// - Parameter error: The errors if any occured
    open func finished(withErrors error: [Error]) {  }

    open override func waitUntilFinished() {
        fatalError("Bad usage of API")
    }
    // swiftlint:disable block_based_kvo
    open override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {

        guard context == &Operation.KVOCtx else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }

        guard super.isReady, self.state == .pending, !self.isCancelled else { return }
        self.evaluateConditions()
    }
    // swiftlint:enable block_based_kvo
}

public protocol OperationProtocol {
    func addObserver( _ observer: OperationObserver)
    func addDependency(_ op: Foundation.Operation)
}
