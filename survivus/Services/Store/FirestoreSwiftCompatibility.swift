#if canImport(FirebaseFirestore) && !canImport(FirebaseFirestoreSwift)
import Foundation
import FirebaseFirestore

// MARK: - Property wrappers

@propertyWrapper
struct DocumentID<Value>: Codable where Value: LosslessStringConvertible & Codable {
    var wrappedValue: Value?

    init() {
        wrappedValue = nil
    }

    init(from decoder: Decoder) throws {
        guard let container = try? decoder.singleValueContainer() else {
            wrappedValue = nil
            return
        }

        if container.decodeNil() {
            wrappedValue = nil
            return
        }

        let stringValue = try container.decode(String.self)
        if let value = Value(stringValue) {
            wrappedValue = value
        } else {
            wrappedValue = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let value = wrappedValue {
            try container.encode(value.description)
        } else {
            try container.encodeNil()
        }
    }
}

// MARK: - Firestore Codable helpers

private enum FirestoreCompatibilityError: Error {
    case missingData
    case invalidJSONObjectValue(Any)
    case unexpectedTopLevel
}

private enum FirestoreJSONAdapter {
    static func makeJSONObject(from value: Any) throws -> Any {
        switch value {
        case let dictionary as [String: Any]:
            return try dictionary.reduce(into: [String: Any]()) { result, entry in
                result[entry.key] = try makeJSONObject(from: entry.value)
            }
        case let array as [Any]:
            return try array.map { try makeJSONObject(from: $0) }
        case is String, is Bool, is NSNull:
            return value
        case let number as NSNumber:
            return number
        case let date as Date:
            return date.timeIntervalSince1970
        case let timestamp as Timestamp:
            return timestamp.dateValue().timeIntervalSince1970
        default:
            return String(describing: value)
        }
    }
}

extension DocumentSnapshot {
    func data<T: Decodable>(as type: T.Type, decoder: JSONDecoder = JSONDecoder()) throws -> T {
        guard var rawData = data() else {
            throw FirestoreCompatibilityError.missingData
        }

        if rawData["documentId"] == nil {
            rawData["documentId"] = documentID
        }

        let jsonObject = try FirestoreJSONAdapter.makeJSONObject(from: rawData)
        guard let dictionary = jsonObject as? [String: Any] else {
            throw FirestoreCompatibilityError.unexpectedTopLevel
        }

        let jsonData = try JSONSerialization.data(withJSONObject: dictionary, options: [])
        return try decoder.decode(T.self, from: jsonData)
    }
}

extension DocumentReference {
    func setData<T: Encodable>(from value: T, merge: Bool = false, encoder: JSONEncoder = JSONEncoder()) throws {
        let data = try encoder.encode(value)
        let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])

        guard let dictionary = jsonObject as? [String: Any] else {
            throw FirestoreCompatibilityError.unexpectedTopLevel
        }

        try setData(dictionary, merge: merge)
    }
}
#endif
