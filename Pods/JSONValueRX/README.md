[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/JSONValueRX.svg)](https://img.shields.io/cocoapods/v/JSONValueRX.svg)
[![Build Status](https://travis-ci.org/rexmas/JSONValue.svg)](https://travis-ci.org/rexmas/JSONValue)

# JSONValue
Simple JSON representation supporting subscripting and pattern matching.
JSONValue uses an algebraic datatype representation of JSON for type safety and pattern matching.
```swift
enum JSONValue: CustomStringConvertible, Hashable {
    case array([JSONValue])
    case object([String : JSONValue])
    case number(JSONNumber)
    case string(String)
    case bool(Bool)
    case null
}

public enum JSONNumber: Hashable {
    case int(Int64)
    case fraction(Double)
}

```
# Requirements
### Supported Platforms
iOS 8.0+
MacOS 10.12+

### Supported Languages
Swift 5.0+

# Installation
### CocoaPods
```
platform :ios, '8.0'
use_frameworks!

pod 'JSONValueRX'
```
### Swift Package Manager (SPM)
```swift
dependencies: [
    .package(url: "https://github.com/rexmas/JSONValue.git", from: "6.0.0")
]
```

#### Build Xcode Project
swift package generate-xcodeproj

# Subscripting
Supports `.` indexing
```swift
let dict = [ "fis" : [ "h" : "food" ]]
var jsonVal = try! JSONValue(object: dict)

print(jsonVal["fis.h"]) // Optional(JSONString(food))

jsonVal["awe.some"] = try! JSONValue(object: "cool")
print(jsonVal["awe.some"]) // Optional(JSONString(cool))
```
Supports `.` in keys
```swift
let dict = [ "fis.h" : "food" ]
var jsonVal = try! JSONValue(object: dict)

print(jsonVal["fis.h"]) // Optional(JSONString(food))

jsonVal[["awe.some"]] = try! JSONValue(object: "cool")
print(jsonVal["awe.some"]) // Optional(string(cool))
```

# Equatable
```swift
print(JSONValue.number(.int(1)) == JSONValue.number(.int(1))) // true
```

# Hashable
`extension JSONValue: Hashable`

Inverted key/value pairs do not collide.
```swift
let hashable1 = try! JSONValue(object: ["warp" : "drive"])
let hashable2 = try! JSONValue(object: ["drive" : "warp"])

print(hashable1.hashValue) // -7189088994080390660
print(hashable2.hashValue) // -215843780535174243
```

# Codable

#### Decode from JSON to JSONValue

```swift
let jsonString = """
{
    "_id": "5d140a3fb5bbd5eaa41b512e",
    "guid": "9b0f3717-2f21-4a81-8902-92d2278a92f0",
    "isActive": false,
    "age": 30
}
"""
let jsonValue = try! JSONDecoder().decode(JSONValue.self, from: jsonString.data(using: .utf8)!)
```

#### Encode JSONValue to JSON

```swift
let jsonValue = JSONValue.object(["_id" : .string("5d140a3fb5bbd5eaa41b512e")])
let jsonData = try! JSONEncoder().encode(jsonValue)
```

#### Decode from JSONValue to a Struct

```swift
let jsonValue = JSONValue.array([
    .object([
        "_id": .string("5d140a3fb5bbd5eaa41b512e"),
        "guid": .string("9b0f3717-2f21-4a81-8902-92d2278a92f0"),
        "isActive": .bool(false),
        "age": .number(.int(30)),
        "name": .object([
        "first": .string("Rosales"),
        "last": .string("Mcintosh")
        ]),
        "company": JSONValue.null,
        "latitude": .string("-58.182284"),
        "longitude": .string("-159.420718"),
        "tags": .array([
        .string("aute"),
        .string("aute")
        ])
    ])
])

struct Output: Decodable, Equatable {
    let _id: String
    let guid: String
    let isActive: Bool
    let age: Int
    let name: [String: String]
    let company: String?
    let latitude: String
    let longitude: String
    let tags: [String]
}

let output: Array<Output> = try! jsonValue.decode()
```

# Encoding/Decoding from String, Data without Codable
```swift
public func encode() throws -> Data
public static func decode(_ data: Data) throws -> JSONValue
public static func decode(_ string: String) throws -> JSONValue
```

# Custom Encoding/Decoding without Codable
```swift
public protocol JSONDecodable {
    associatedtype ConversionType = Self
    static func fromJSON(_ x: JSONValue) -> ConversionType?
}

public protocol JSONEncodable {
    associatedtype ConversionType
    static func toJSON(_ x: ConversionType) -> JSONValue
}

public protocol JSONable: JSONDecodable, JSONEncodable { }
```
The following support `JSONable` for out-of-the-box Encoding/Decoding.
```swift
NSNull
Double
Bool
Int (and varieties -> Int64, Int32, ...)
UInt (and varieties -> UInt64, UInt32, ...)
Date
NSDate
Array
String
Dictionary
```
`Date` uses built in `ISO` encoding/decoding to/from `.string`

# Contributing

- If a bug is discovered please open an issue.
- Fork the project and submit a pull request to contribute.
- Keep Linux tests up-to-date `swift test --generate-linuxmain`

# License
The MIT License (MIT)

Copyright (c) 2015-Present Rex

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
