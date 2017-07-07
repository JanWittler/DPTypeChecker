//
//  AbSyn+Extensions.swift
//  DPTypeChecker
//
//  Created by Jan Wittler on 08.06.17.
//  Copyright © 2017 Jan Wittler. All rights reserved.
//

import Foundation

//MARK: custom accessors

extension Type {
    var replicationCount: Double {
        switch self {
        case let .tType(_, rCount):
            return rCount
        case let .tTypeConvenienceInt(_ ,rCount):
            return Double(rCount)
        case .tTypeExponential(_):
            return Double.infinity
        }
    }
    
    var coreType: CoreType {
        let coreType: CoreType
        switch self {
        case let .tType(cType, _):
            coreType = cType
        case let .tTypeConvenienceInt(cType, _):
            coreType = cType
        case let .tTypeExponential(cType):
            coreType = cType
        }
        if case let .cTTypedef(id) = coreType {
            do {
                return try environment.lookupType(id).coreType
            }
            catch {}
        }
        return coreType
    }
}

extension IdMaybeTyped {
    var id: Id {
        switch self {
        case let .idNotTyped(id):
            return id
        case let.idTyped(id, _):
            return id
        }
    }
    
    var type: Type? {
        switch self {
        case .idNotTyped(_):
            return nil
        case let .idTyped(_, type):
            return type
        }
    }
}

extension Arg {
    var id: Id {
        switch self {
        case let .aDecl(id, _):
            return id
        }
    }
    
    var type: Type {
        switch self {
        case let .aDecl(_, type):
            return type
        }
    }
}

extension Case {
    func unwrappedType(from type: Type, environment: Environment) throws -> Type {
        //no need to handle .cTTypedef explicit, since it is handled in `Type.coreType` getter
        guard case let .cTSum(lType, rType) = type.coreType else {
            throw TypeCheckerError.caseApplicationFailed(case: self, actual: type)
        }
        
        switch self {
        case .inl:
            return lType
        case .inr:
            return rType
        }
    }
}

//MARK: subtyping

extension Type {
    func isSubtype(of other: Type) -> Bool {
        //if the own count is larger than the compared count, we can alwas return `false`, no matter of the internal types
        guard replicationCount <= other.replicationCount else {
            return false
        }
        switch (self.coreType, other.coreType) {
        case (let .cTBase(bType1), let .cTBase(bType2)):
            return bType1 == bType2
        case (let .cTMulPair(pair1), let .cTMulPair(pair2)):
            return pair1.0.isSubtype(of:pair2.0) && pair1.1.isSubtype(of:pair2.1)
        case (let .cTSum(sum1), let .cTSum(sum2)):
            return sum1.0.isSubtype(of: sum2.0) && sum2.0.isSubtype(of: sum2.0)
        case (let .cTFunction(a1, r1), let .cTFunction(a2, r2)):
            //arguments have inversed subtype requirements
            return r1.isSubtype(of: r2) && a1.count == a2.count && zip(a1, a2).reduce(true) { $0 && $1.1.isSubtype(of: $1.0) }
        default:
            //no need to handle .cTTypedef explicit, since it is handled in `Type.coreType` getter
            return false
        }
    }
}

//MARK: OPP type

extension Type {
    var isOPPType: Bool {
        return replicationCount == Double.infinity && coreType.isOPPType
    }
}

extension CoreType {
    var isOPPType: Bool {
        switch self {
        case .cTBase(_):
            return true
        case let .cTMulPair(type1, type2):
            return type1.isOPPType && type2.isOPPType
        case let .cTSum(lType, rType):
            return lType.isOPPType && rType.isOPPType
        case let .cTFunction(argTypes, returnType):
            return argTypes.reduce(false) { $0 && $1.isOPPType} && returnType.isOPPType
        case let .cTTypedef(id):
            do {
                let type = try environment.lookupType(id)
                return type.isOPPType
            }
            catch {
                //computed getters cannot throw, thus we must return a default value
                return false
            }
        }
    }
}

//MARK: equatable extensions

extension Type: Equatable {
    public static func ==(lhs: Type, rhs: Type) -> Bool {
        return lhs.replicationCount == rhs.replicationCount && lhs.coreType == rhs.coreType
    }
}

extension CoreType: Equatable {
    public static func ==(lhs: CoreType, rhs: CoreType) -> Bool {
        switch (lhs, rhs) {
        case (let .cTBase(bType1), let .cTBase(bType2)) where bType1 == bType2:
            return true
        case (let .cTMulPair(pair1), let .cTMulPair(pair2)) where pair1 == pair2:
            return true
        case (let .cTSum(sum1), let .cTSum(sum2)) where sum1 == sum2:
            return true
        case (let .cTFunction(a1, r1), let cTFunction(a2, r2)):
            return r1 == r2 && a1.count == a2.count && zip(a1, a2).reduce(true) { $0 && $1.0 == $1.1 }
        default:
            //no need to handle .cTTypedef explicit, since it is handled in `Type.coreType` getter
            return false
        }
    }
}

//MARK: Type printing

extension Type: CustomStringConvertible {
    public var description: String {
        return "Type(\(internalDescription))"
    }
    
    fileprivate var internalDescription: String {
        let countString = replicationCount.remainder(dividingBy: 1) == 0 ? String(format: "%.0f", replicationCount) : "\(replicationCount)"
        return "\(coreType)!\(countString)"
    }
}

extension CoreType: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .cTBase(bType):
            return bType.description
        case let .cTMulPair(t1, t2):
            return "(\(t1.internalDescription) ⊗ \(t2.internalDescription))"
        case let .cTSum(lType, rType):
            return "(\(lType.internalDescription) + \(rType.internalDescription))"
        case let .cTFunction(argTypes, returnType):
            let args = argTypes.map { $0.internalDescription }.joined(separator: ", ")
            return "((\(args)) -> \(returnType.internalDescription))"
        case let .cTTypedef(id):
            do {
                let type = try environment.lookupType(id)
                return type.coreType.description
            }
            catch {
                //computed getters cannot throw, thus we must return a default value
                return "\(id.value)"
            }
        }
    }
}

extension BaseType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .int:
            return "Int"
        case .float:
            return "Float"
        case .unit:
            return "Unit"
        }
    }
}
