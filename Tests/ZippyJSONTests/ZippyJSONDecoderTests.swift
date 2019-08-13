//Copyright (c) 2018 Michael Eisel. All rights reserved.

import XCTest
@testable import ZippyJSON

struct TestCodingKey: CodingKey {
    var stringValue: String

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    var intValue: Int? {
        return nil
    }

    init?(intValue: Int) {
        return nil
    }
}

extension DecodingError: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch lhs {
        case .typeMismatch(let lType, let lContext):
            if case let DecodingError.typeMismatch(rType, rContext) = rhs {
                return lType == rType && rContext == lContext
            }
        case .valueNotFound(let lType, let lContext):
            if case let DecodingError.valueNotFound(rType, rContext) = rhs {
                return lType == rType && rContext == lContext
            }
        case .keyNotFound(let lKey, let lContext):
            if case let DecodingError.keyNotFound(rKey, rContext) = rhs {
                return keysEqual(lKey, rKey) && rContext == lContext
            }
        case .dataCorrupted(let lContext):
            if case let DecodingError.dataCorrupted(rContext) = rhs {
                return rContext == lContext
            }
        @unknown default:
            return false
        }
        return false
    }
}

func keysEqual(_ lhs: CodingKey, _ rhs: CodingKey) -> Bool {
    lhs.stringValue == rhs.stringValue || (lhs.intValue != nil && lhs.intValue == rhs.intValue)
}

fileprivate struct JSONKey : CodingKey {
    public var stringValue: String
    public var intValue: Int?

    public init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    public init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }

    public init(stringValue: String, intValue: Int?) {
        self.stringValue = stringValue
        self.intValue = intValue
    }

    fileprivate init(index: Int) {
        self.stringValue = "Index \(index)"
        self.intValue = index
    }

    fileprivate static let `super` = JSONKey(stringValue: "super")!
}

extension DecodingError.Context: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        let pathsEqual = lhs.codingPath.count == rhs.codingPath.count && zip(lhs.codingPath, rhs.codingPath).allSatisfy { (a, b) in
            keysEqual(a, b)
        }
        return pathsEqual && lhs.debugDescription == rhs.debugDescription
    }
}

class ZippyJSONTests: XCTestCase {
    let decoder = ZippyJSONDecoder()
    lazy var base64Data = {
        return dataFromFile("base64.json")
    }()
    lazy var twitterData = {
        dataFromFile("twitter.json")
    }()
    lazy var canadaData = {
        self.dataFromFile("canada.json")
    }()

    func dataFromFile(_ file: String) -> Data {
        let path = Bundle(for: type(of: self)).path(forResource: file, ofType: "")!
        let string = try! String(contentsOfFile: path)
        return string.data(using: .utf8)!
    }

    func assertEqualsApple<T: Codable & Equatable>(data: Data, type: T.Type) {
        let testDecoder = ZippyJSONDecoder()
        let appleDecoder = JSONDecoder()
        let testObject = try! testDecoder.decode(type, from: data)
        let appleObject = try! appleDecoder.decode(type, from: data)
        XCTAssertEqual(appleObject, testObject)
    }

    func testRecursiveDecoding() {
        decoder.keyDecodingStrategy = .custom({ (keys) -> CodingKey in
            let recursiveDecoder = ZippyJSONDecoder()
            let data: Data = keys.last!.stringValue.data(using: .utf8)!
            return TestCodingKey(stringValue: try! recursiveDecoder.decode(String.self, from: data))!
        })
    }

    func _testFailure<T>(of value: T.Type,
                           json: String,
                           outputFormatting: JSONEncoder.OutputFormatting = [],
                           expectedError: DecodingError?,
                           dateEncodingStrategy: JSONEncoder.DateEncodingStrategy = .deferredToDate,
                           dateDecodingStrategy: ZippyJSONDecoder.DateDecodingStrategy = .deferredToDate,
                           dataEncodingStrategy: JSONEncoder.DataEncodingStrategy = .base64,
                           dataDecodingStrategy: ZippyJSONDecoder.DataDecodingStrategy = .base64,
                           keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy = .useDefaultKeys,
                           keyDecodingStrategy: ZippyJSONDecoder.KeyDecodingStrategy = .useDefaultKeys,
                           nonConformingFloatEncodingStrategy: JSONEncoder.NonConformingFloatEncodingStrategy = .throw,
                           nonConformingFloatDecodingStrategy: ZippyJSONDecoder.NonConformingFloatDecodingStrategy = .throw) where T : Decodable, T : Equatable {
        let decoder = ZippyJSONDecoder()
        decoder.dateDecodingStrategy = dateDecodingStrategy
        decoder.dataDecodingStrategy = dataDecodingStrategy
        decoder.nonConformingFloatDecodingStrategy = nonConformingFloatDecodingStrategy
        decoder.keyDecodingStrategy = keyDecodingStrategy
        do {
            try decoder.decode(T.self, from: json.data(using: .utf8)!)
        } catch {
            guard let expError = expectedError else {
                abort()
                // return
            }
            if let e = error as? DecodingError {
                if (e != expError) { fatalError() }
            } else {
                abort()
            }
        }
    }

    func _testRoundTrip<T>(of value: T,
                           json: String,
                           outputFormatting: JSONEncoder.OutputFormatting = [],
                           dateEncodingStrategy: JSONEncoder.DateEncodingStrategy = .deferredToDate,
                           dateDecodingStrategy: ZippyJSONDecoder.DateDecodingStrategy = .deferredToDate,
                           dataEncodingStrategy: JSONEncoder.DataEncodingStrategy = .base64,
                           dataDecodingStrategy: ZippyJSONDecoder.DataDecodingStrategy = .base64,
                           keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy = .useDefaultKeys,
                           keyDecodingStrategy: ZippyJSONDecoder.KeyDecodingStrategy = .useDefaultKeys,
                           nonConformingFloatEncodingStrategy: JSONEncoder.NonConformingFloatEncodingStrategy = .throw,
                           nonConformingFloatDecodingStrategy: ZippyJSONDecoder.NonConformingFloatDecodingStrategy = .throw) where T : Decodable, T : Equatable {
        do {
            let decoder = ZippyJSONDecoder()
            decoder.dateDecodingStrategy = dateDecodingStrategy
            decoder.dataDecodingStrategy = dataDecodingStrategy
            decoder.nonConformingFloatDecodingStrategy = nonConformingFloatDecodingStrategy
            decoder.keyDecodingStrategy = keyDecodingStrategy
            let decoded = try decoder.decode(T.self, from: json.data(using: .utf8)!)
            assert(decoded == value)
            // XCTAssertEqual(decoded, value)
        } catch {
            fatalError()
            XCTFail("Failed to decode \(T.self) from JSON: \(error)")
        }
    }

    func testDictionaryStuff() {
        struct Test: Codable, Equatable {
            let a: Bool
        }
        _testRoundTrip(of: Test(a: true), json: #"{"a": true}"#)
        _testRoundTrip(of: TopLevelWrapper(Test(a: true)), json: #"{"value": {"a": true}}"#)
        _testFailure(of: Test.self, json: #"{"b": true}"#, expectedError: DecodingError.keyNotFound(JSONKey(stringValue: "a")!, DecodingError.Context(codingPath: [], debugDescription: "No value associated with a.")))
        _testFailure(of: Test.self, json: #"{}"#, expectedError: DecodingError.keyNotFound(JSONKey(stringValue: "a")!, DecodingError.Context(codingPath: [], debugDescription: "No value associated with a.")))
        _testFailure(of: TopLevelWrapper<Test>.self, json: #"{"value": {}}"#, expectedError: DecodingError.keyNotFound(JSONKey(stringValue: "a")!, DecodingError.Context(codingPath: [], debugDescription: "No value associated with a.")))
        _testFailure(of: TopLevelWrapper<Test>.self, json: #"{"value": {"b": true}}"#, expectedError: DecodingError.keyNotFound(JSONKey(stringValue: "a")!, DecodingError.Context(codingPath: [JSONKey(stringValue: "value")!], debugDescription: "No value associated with a.")))
    }

    func testArrayStuff() {
        struct Test: Codable, Equatable {
            let a: Bool
            let b: Bool

            init(a: Bool, b: Bool) {
                self.a = a
                self.b = b
            }

            init(from decoder: Decoder) throws {
                var container = try decoder.unkeyedContainer()
                a = try container.decode(Bool.self)
                b = try container.decode(Bool.self)
            }
        }

        // Goes past the end
        _testFailure(of: Test.self, json: "[true]", expectedError: DecodingError.valueNotFound(Any.self, DecodingError.Context(codingPath: [JSONKey(index: 0)], debugDescription: "Cannot get next value -- unkeyed container is at end.")))
        _testFailure(of: Test.self, json: "[]", expectedError: DecodingError.valueNotFound(Any.self, DecodingError.Context(codingPath: [], debugDescription: "Cannot get next value -- unkeyed container is at end.")))
        _testFailure(of: TopLevelWrapper<Test>.self, json: #"{"value": [true]}"#, expectedError: DecodingError.valueNotFound(Any.self, DecodingError.Context(codingPath: [JSONKey(stringValue: "value")!, JSONKey(index: 0)], debugDescription: "Cannot get next value -- unkeyed container is at end.")))
        _testFailure(of: TopLevelWrapper<Test>.self, json: #"{"value": []}"#, expectedError: DecodingError.valueNotFound(Any.self, DecodingError.Context(codingPath: [JSONKey(stringValue: "value")!], debugDescription: "Cannot get next value -- unkeyed container is at end.")))
        // Left over
        _testRoundTrip(of: Test(a: false, b: true), json: "[false, true, false]")
        // Normals
        _testRoundTrip(of: Test(a: false, b: true), json: "[false, true]")
        _testRoundTrip(of: [false, true], json: "[false, true]")
        _testFailure(of: [Int].self, json: #"{"a": 1}"#, expectedError: DecodingError.typeMismatch([Any].self, DecodingError.Context(codingPath: [JSONKey(stringValue: "a")!], debugDescription: "Tried to unbox array, but it wasn\'t an array")))
    }

    func testDoubleParsing() {
        let testDoubles = try! decoder.decode(Canada.self, from: canadaData).features.first!.geometry.coordinates.flatMap { $0 }
        let appleDoubles = try! JSONDecoder().decode(Canada.self, from: canadaData).features.first!.geometry.coordinates.flatMap { $0 }
        let badOnes = zip(testDoubles, appleDoubles).filter { (t, a) -> Bool in
            t != a
        }
        XCTAssertEqual(badOnes.count, 1)
    }

    func testCamelCase() {
        let keyDecodingStrategies: [ZippyJSONDecoder.KeyDecodingStrategy] = [.useDefaultKeys, .convertFromSnakeCase]
        for keyDecodingStrategy in keyDecodingStrategies {
            let appleDecoder = Foundation.JSONDecoder()
            let foundationKeyDecodingStrategy: Foundation.JSONDecoder.KeyDecodingStrategy = ZippyJSONDecoder.convertKeyDecodingStrategy(keyDecodingStrategy)
            appleDecoder.keyDecodingStrategy = foundationKeyDecodingStrategy
            let testDecoder = ZippyJSONDecoder()
            testDecoder.keyDecodingStrategy = keyDecodingStrategy
            switch keyDecodingStrategy {
            case .useDefaultKeys:
                let appleObject = try! appleDecoder.decode(TwitterPayload.self, from: twitterData)
                let testObject = try! testDecoder.decode(TwitterPayload.self, from: twitterData)
                XCTAssertEqual(appleObject, testObject)
            case .convertFromSnakeCase:
                let appleObject = try! appleDecoder.decode(TwitterPayloadC.self, from: twitterData)
                let testObject = try! testDecoder.decode(TwitterPayloadC.self, from: twitterData)
                XCTAssertEqual(appleObject, testObject)
            default:
                fatalError()
            }
        }
    }

    func testMatchingErrors() {
    }
}
