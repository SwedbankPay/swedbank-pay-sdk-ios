//
// Copyright 2021 Swedbank AB
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

public extension SwedbankPaySDK {
    /// To use a `Codable` type as the `userData` parameter for `SwedbankPaySDKController`,
    /// or as the `userInfo` property of `SwedbankPaySDK.ViewPaymentOrderInfo`,
    /// the type should be registered by calling this function. Failure to do so results
    /// in exceptions being throw during state saving and/or restoration.
    ///
    /// In addition, if you need lossless preservation of custom `Error` types as part of
    /// `SwedbankPaySDKController` state preservation, you can register those types here as well.
    /// Otherwise, `Error`s will be converted to `NSError` when saving and restoring the state.
    ///
    /// The type should not be a internal or local type. Use of such types may result in decoding failures.
    static func registerCodable<T: Codable>(_ type: T.Type) {
        registerCodable(type, encodedTypeName: defaultEncodedTypeName(for: type))
    }
    
    /// Variant of `registerCodable` that allows to manually set the encoded name for the `Codable` type.
    ///
    /// If you must use a internal or local type, then this function may help, as the default encoded name
    /// for such types is unpredictable. Otherwise, there is ususaly no need to use this function.
    ///
    /// Encoded type names beginning with `"com.swedbankpay."` are reserved for the SDK.
    static func registerCodable<T: Codable>(_ type: T.Type, encodedTypeName: String) {
        Coders.registerCoder(for: type, encodedTypeName: encodedTypeName)
    }
}

internal func defaultEncodedTypeName(for codableType: Codable.Type) -> String {
    return String(reflecting: codableType)
}

internal let internalEncodedTypeNamePrefix = "com.swedbankpay.mobilesdk."

extension KeyedEncodingContainer {
    mutating func encodeIfPresent(userData: Any?, codableTypeKey: Key, valueKey: Key) throws {
        switch userData {
        case nil:
            break
        case let nsCodingUserData as NSCoding:
            try encode(nsCodingUserData: nsCodingUserData, key: valueKey)
        case let codableUserData as Codable:
            try encode(codableUserData: codableUserData, typeKey: codableTypeKey, valueKey: valueKey)
        default:
            fatalError("userData must conform to Codable or NSCoding if you want to support state restoration")
        }
    }
    
    mutating func encodeIfPresent(error: Error?, codableTypeKey: Key, valueKey: Key) throws {
        if let codableError = error as? Codable, Coders.getCoder(for: codableError) != nil /*registeredEncoders[ObjectIdentifier(type(of: codableError))] != nil*/ {
            try encode(codableUserData: codableError, typeKey: codableTypeKey, valueKey: valueKey)
        } else if let error = error {
            try encode(nsCodingUserData: error as NSError, key: valueKey)
        }
    }
    
    internal mutating func encode(nsCodingUserData: NSCoding, key: Key) throws {
        let data: Data
        if #available(iOS 11.0, *) {
            data = try NSKeyedArchiver.archivedData(withRootObject: nsCodingUserData, requiringSecureCoding: false)
        } else {
            data = NSKeyedArchiver.archivedData(withRootObject: nsCodingUserData)
        }
        try encode(data, forKey: key)
    }
    
    internal mutating func encode(codableUserData: Codable, typeKey: Key, valueKey: Key) throws {
        guard let coder = Coders.getCoder(for: codableUserData) else {
            throw SwedbankPaySDKController.StateRestorationError.unregisteredCodable(defaultEncodedTypeName(for: type(of: codableUserData)))
        }
        try encode(coder.encodedTypeName, forKey: typeKey)
        try coder.encode(to: &self, key: valueKey, value: codableUserData)
    }
}
extension KeyedDecodingContainer {
    func decodeUserDataIfPresent(codableTypeKey: Key, valueKey: Key) throws -> Any? {
        if let encodedTypeName = try decodeIfPresent(String.self, forKey: codableTypeKey) {
            guard let coder = Coders.getCoder(for: encodedTypeName) else {
                throw SwedbankPaySDKController.StateRestorationError.unregisteredCodable(encodedTypeName)
            }
            return try coder.decode(from: self, key: valueKey)
        } else {
            let data = try decodeIfPresent(Data.self, forKey: valueKey)
            return try data.flatMap(NSKeyedUnarchiver.unarchiveTopLevelObjectWithData)
        }
    }
    
    func decodeErrorIfPresent(codableTypeKey: Key, valueKey: Key) throws -> Error? {
        let error = try decodeUserDataIfPresent(codableTypeKey: codableTypeKey, valueKey: valueKey)
        switch error {
        case nil:
            return nil
        case let error as Error:
            return error
        default:
            // This should never happen
            throw SwedbankPaySDKController.StateRestorationError.unknown
        }
    }
}

internal protocol ErasedCoder {
    var encodedTypeName: String { get }
    func encode<K: CodingKey>(to container: inout KeyedEncodingContainer<K>, key: K, value: Any) throws
    func decode<K: CodingKey>(from container: KeyedDecodingContainer<K>, key: K) throws -> Any
}

internal enum Coders {}
extension Coders {
    internal static var registeredCoders = CoderMap()
    internal static let internalCoders: CoderMap = {
        var map = CoderMap()
        map.registerInternalCoder(SwedbankPaySDKController.WebContentError.self)
        map.registerInternalCoder(SwedbankPaySDKController.StateRestorationError.self)
        return map
    }()
    
    static func registerCoder<T: Codable>(for type: T.Type, encodedTypeName: String) {
        registeredCoders.registerCoder(for: type, encodedTypeName: encodedTypeName)
    }
    static func getCoder(for codable: Codable) -> ErasedCoder? {
        let codableType = type(of: codable)
        return registeredCoders[codableType] ?? internalCoders[codableType]
    }
    static func getCoder(for encodedTypeName: String) -> ErasedCoder? {
        return registeredCoders[encodedTypeName] ?? internalCoders[encodedTypeName]
    }
}

internal struct CoderMap {
    internal var byType: [ObjectIdentifier: ErasedCoder] = [:]
    internal var byName: [String: ErasedCoder] = [:]
    
    mutating func registerCoder<T: Codable>(for type: T.Type, encodedTypeName: String) {
        let coder = TypedCoder<T>(encodedTypeName: encodedTypeName)
        byType[ObjectIdentifier(type)] = coder
        byName[encodedTypeName] = coder
    }
    
    subscript(type: Codable.Type) -> ErasedCoder? {
        return byType[ObjectIdentifier(type)]
    }
    subscript(encodedTypeName: String) -> ErasedCoder? {
        return byName[encodedTypeName]
    }
    
    internal struct TypedCoder<T: Codable>: ErasedCoder {
        let encodedTypeName: String
        func encode<K: CodingKey>(to container: inout KeyedEncodingContainer<K>, key: K, value: Any) throws {
            try container.encode(value as! T, forKey: key)
        }
        func decode<K: CodingKey>(from container: KeyedDecodingContainer<K>, key: K) throws -> Any {
            try container.decode(T.self, forKey: key)
        }
    }
}

extension CoderMap {
    mutating func registerInternalCoder<T: Codable>(_ type: T.Type) {
        let encodedTypeName = "\(internalEncodedTypeNamePrefix)\(String(describing: type))"
        registerCoder(for: type, encodedTypeName: encodedTypeName)
    }
}
