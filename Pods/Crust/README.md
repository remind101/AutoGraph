[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/Crust.svg)](https://img.shields.io/cocoapods/v/Crust.svg)
[![Build Status](https://travis-ci.org/rexmas/Crust.svg)](https://travis-ci.org/rexmas/Crust)

## Crust
A flexible Swift framework for converting classes and structs to and from JSON with support for storage solutions such as Realm.

## Features 🎸
- [Structs and Classes](#structs-and-classes)
- [Separation of Concerns (Mapped Model, Mapping, Storage)](#separation-of-concerns)
- [Type safe JSON](#jsonvalue-for-type-safe-json)
- [How To Map](#how-to-map)
  - [Nested Mappings](#nested-mappings)
  - [Binding and Collections](#binding-and-collections)
  - [Mapping Payload](#mapping-payload)
  - [Custom Transformations](#custom-transformations)
  - [Different Mappings for Same Model](#different-mappings-for-same-model)
- [Persistance Adapter](#persistance-adapter)
- [Realm](#realm)
- Supports Optional Types and Collections.

## Requirements
iOS 8.0+
Swift 4.0+
see `swift-3` tag (v 0.6.0..<0.7.0) for Swift 3

## Installation
### CocoaPods
```
platform :ios, '8.0'
use_frameworks!

pod 'Crust'
```

## Structs and Classes
Can map to/from classes or structs
```swift
class Company {
    var employees = Array<Employee>()
    var uuid: String = ""
    var name: String = ""
    var foundingDate: NSDate = NSDate()
    var founder: Employee?
    var pendingLawsuits: Int = 0
}
```
If you have no need for storage, which will generaly be the case for structs, use `AnyMappable`.
```swift
struct Person: AnyMappable {
    var bankAccounts: Array<Int> = [ 1234, 5678 ]
    var attitude: String = "awesome"
    var hairColor: HairColor = .Unknown
    var ownsCat: Bool? = nil
}
```

## Separation of Concerns

By design Crust is built with [separation of concerns](https://en.wikipedia.org/wiki/Separation_of_concerns) in mind. It makes no assumptions about how many ways a user would like to map to and from JSON and how many various ways the user would like to store their models.

Crust has 2 basic protocols:
- `Mapping`
	- How to map JSON to and from a particular model - (model is set by the `associatedtype MappedObject` if mapping to an sequence of objects set `associatedtype SequenceKind`).
	- May include primary key(s) and nested mapping(s).
- `PersistanceAdapter`
	- How to store and retrieve model objects used for mapping from a backing store (e.g. Core Data, Realm, etc.).

And 2 additional protocols when no storage `PersistanceAdapter` is required:
- `AnyMappable`
	- Inherited by the model (class or struct) to be mapped to and from JSON.
- `AnyMapping`
	- A `Mapping` that does not require an `PersistanceAdapter`.

There are no limitations on the number of various `Mapping`s and `PersistanceAdapter`s one may create per model for different use cases.

## JSONValue for type safe JSON
Crust relies on [JSONValue](https://github.com/rexmas/JSONValue) for it's JSON encoding and decoding mechanism. It offers many benefits including type safety, subscripting, and extensibility through protocols.

## How To Map

1. Create a set of `MappingKey`s that define the key paths from the JSON payload to your model.
    ```swift
    enum EmployeeKey: MappingKey {
        case uuid
        case name
        case employer(Set<CompanyKey>)

        var keyPath: String {
            switch self {
            case .employer(_):          return "company"
            case .uuid:                 return "data.uuid"  // This means our JSON has a 'data' payload we're elevating.
            case .name:                 return "data.name"
            }
        }

        // You can specifically specify what keys you'd like to map from in the `keyedBy` argument of the mapper. This function retrieves the nested keys.
        func nestedMappingKeys<Key: MappingKey>() -> AnyKeyCollection<Key>? {
            switch self {
            case .employer(let companyKeys):
                return companyKeys.anyKeyCollection()
            default:
                return nil
            }
        }
    }

    enum CompanyKey: MappingKey {
        case uuid
        case name
        case employees(Set<EmployeeKey>)
        case founder(Set<EmployeeKey>)
        case foundingDate
        case pendingLawsuits

        var keyPath: String {
            switch self {
            case .uuid:                 "uuid"
            case .name:                 "name"
            case .employees(_):         "employees"
            case .founder(_):           "founder"
            case .foundingDate:         "data.founding_date"
            case .pendingLawsuits:      "data.lawsuits_pending"
            }
        }

        func nestedMappingKeys<Key: MappingKey>() -> AnyKeyCollection<Key>? {
            switch self {
            case .employees(let employeeKeys):
                return employeeKeys.anyKeyCollection()
            case .founder(let employeeKeys):
                return employeeKeys.anyKeyCollection()
            default:
                return nil
            }
        }
    }
    ```

2. Create your mappings for your model using `Mapping` if with storage or `AnyMapping` if without storage.

    With storage (assume `CoreDataAdapter` conforms to `PersistanceAdapter`)
    ```swift
    class EmployeeMapping: Mapping {
    
        var adapter: CoreDataAdapter
        var primaryKeys: [Mapping.PrimaryKeyDescriptor]? {
            // property == attribute on the model, keyPath == keypath in the JSON blob, transform == tranform to apply to data from JSON blob.
            return [ (property: "uuid", keyPath: EmployeeKey.uuid.keyPath, transform: nil) ]
        }

        required init(adapter: CoreDataAdapter) {
            self.adapter = adapter
        }
    
        func mapping(inout toMap: inout Employee, payload: MappingPayload<EmployeeKey>) throws {
            // Company must be transformed into something Core Data can use in this case.
            let companyMapping = CompanyTransformableMapping()
            
            // No need to map the primary key here.
            toMap.employer              <- .mapping(.employer([]), companyMapping) >*<
            toMap.name                  <- .name >*<
            payload
        }
    }
    ```
    Without storage
    ```swift
    class CompanyMapping: AnyMapping {
        // associatedtype MappedObject = Company is inferred by `toMap`
    
        func mapping(inout toMap: inout Company, payload: MappingPayload<CompanyKey>) throws {
            let employeeMapping = EmployeeMapping(adapter: CoreDataAdapter())
        
            toMap.employees             <- .mapping(.employees([]), employeeMapping) >*<
            toMap.founder               <- .mapping(.founder([]), employeeMapping) >*<
            toMap.uuid                  <- .uuid >*<
            toMap.name                  <- .name >*<
            toMap.foundingDate          <- .foundingDate  >*<
            toMap.pendingLawsuits       <- .pendingLawsuits  >*<
            payload
        }
    }
    ```

3. Create your Crust Mapper.
    ```swift
    let mapper = Mapper()
    ```

4. Use the mapper to convert to and from `JSONValue` objects
    ```swift
    let json = try! JSONValue(object: [
                "uuid" : "uuid123",
                "name" : "name",
                "employees" : [
                    [ "data" : [ "name" : "Fred", "uuid" : "ABC123" ] ],
                    [ "data" : [ "name" : "Wilma", "uuid" : "XYZ098" ] ]
                ]
                "founder" : NSNull(),
                "data" : [
                    "lawsuits_pending" : 5
                ],
                // Works with '.' keypaths too.
                "data.founding_date" : NSDate().toISOString(),
            ]
    )

    // Just map 'uuid', 'name', 'employees.name', 'employees.uuid'
    let company: Company = try! mapper.map(from: json, using: CompanyMapping(), keyedBy: [.uuid, .name, .employees([.name, .uuid])])

    // Or if json is an array and you'd like to map everything.
    let company: [Company] = try! mapper.map(from: json, using: CompanyMapping(), keyedBy: AllKeys())
    ```

NOTE:
`JSONValue` can be converted back to an `AnyObject` variation of json via `json.values()` and to `NSData` via `try! json.encode()`.

### Nested Mappings
Crust supports nested mappings for nested models
E.g. from above
```swift
func mapping(inout toMap: Company, payload: MappingPayload<CompanyKey>) throws {
    let employeeMapping = EmployeeMapping(adapter: CoreDataAdapter())
    
    toMap.employees <- Binding.mapping(.employees([]), employeeMapping) >*<
    payload
}
```

### Binding and Collections

`Binding` provides specialized directives when mapping collections. Use the `.collectionMapping` case to inform the mapper of these directives. They include
* replace and/or delete objects
* append objects to the collection
* unique objects in collection (merge duplicates)
  * The latest mapped properties overwrite the existing object's properties during uniquing. Properties not mapped remain unchanged.
  * Uniquing works automatically if the `Element`s of the collection being mapped follow `Equatable`.
  * If the `Element`s do not follow `Equatable` then uniquing is ignored unless `UniquingFunctions` are explicitly provided and the mapping function `map(toCollection field:, using binding:, uniquing:)` is used.
* Accept "null" values to map from the collection.

This table provides some examples of how "null" json values are mapped depending on the type of Collection being mapped to and given the value of `nullable` and whether values or "null" are present in the JSON payload.

| append / replace  | nullable  | vals / null | Array     | Array?      | RLMArray  |
|-------------------|-----------|-------------|-----------|-------------|-----------|
| append            | yes or no | vals        | append    | append      | append    |
| append            | yes       | null        | no-op     | no-op       | no-op     |
| replace           | yes or no | vals        | replace   | replace     | replace   |
| replace           | yes       | null        | removeAll | assign null | removeAll |
| append or replace | no        | null        | error     | error       | error     |

By default using `.mapping` will `(insert: .replace(delete: nil), unique: true, nullable: true)`.

```swift
public enum CollectionInsertionMethod<Container: Sequence> {
    case append
    case replace(delete: ((_ orphansToDelete: Container) -> Container)?)
}

public typealias CollectionUpdatePolicy<Container: Sequence> =
    (insert: CollectionInsertionMethod<Container>, unique: Bool, nullable: Bool)

public enum Binding<M: Mapping>: Keypath {
    case mapping(Keypath, M)
    case collectionMapping(Keypath, M, CollectionUpdatePolicy<M.SequenceKind>)
}
```

Usage:
```swift
let employeeMapping = EmployeeMapping(adapter: CoreDataAdapter())
let binding = Binding.collectionMapping("", employeeMapping, (.replace(delete: nil), true, true))
toMap.employees <- (binding, payload)
```
Look in ./Mapper/MappingProtocols.swift for more.

### Mapping Payload
Every `mapping` passes through a `Payload: MappingPayload<T>` which must be included during the mapping. The `payload` includes error information that is propagated back from the mapping to the caller and contextual information about the json and object being mapped to/from.

There are two ways to include the payload during mapping:

1. Include it as a tuple.

   ```swift
   func mapping(inout toMap: Company, payload: MappingPayload<CompanyKey>) throws {
       toMap.uuid <- (.uuid, payload)
       toMap.name <- (.name, payload)
   }
   ```
2. Use a specially included operator `>*<` which merges the result of the right expression with the left expression into a tuple. This may be chained in succession.

   ```swift
   func mapping(inout toMap: Company, payload: MappingPayload<CompanyKey>) throws {
       toMap.uuid <- .uuid >*<
       toMap.name <- .name >*<
       payload
   }
   ```

### Custom Transformations
To create a simple custom transformation (such as to basic value types) implement the `Transform` protocol
```swift
public protocol Transform: AnyMapping {
    func fromJSON(_ json: JSONValue) throws -> MappedObject
    func toJSON(_ obj: MappedObject) -> JSONValue
}
```
and use it like any other `Mapping`.

### Different Mappings for Same Model
Multiple `Mapping`s are allowed for the same model.
```swift
class CompanyMapping: AnyMapping {
    func mapping(inout toMap: Company, payload: MappingPayload<CompanyKey>) throws {
        toMap.uuid <- .uuid >*<
        toMap.name <- .name >*<
        payload
    }
}

class CompanyMappingWithNameUUIDReversed: AnyMapping {
	func mapping(inout toMap: Company, payload: MappingPayload<CompanyKey>) throws {
        toMap.uuid <- .name >*<
        toMap.name <- .uuid >*<
        payload
    }
}
```
Just use two different mappings.
```swift
let mapper = Mapper()
let company1 = try! mapper.map(from: json, using: CompanyMapping(), keyedBy: AllKeys())
let company2 = try! mapper.map(from: json, using: CompanyMappingWithNameUUIDReversed(), keyedBy: AllKeys())
```

## Persistance Adapter
Follow the `PersistanceAdapter` protocol to store data into Core Data, Realm, etc.

The object conforming to `PersistanceAdapter` must include two `associatedtype`s:
- `BaseType` - the top level class for this storage systems model objects.
  - Core Data this would be `NSManagedObject`.
  - Realm this would be `RLMObject`.
  - RealmSwift this would be `Object`.
- `ResultsType: Collection` - Used for object lookups. Should be set to a collection of `BaseType`s.

The `Mapping` must then set it's `associatedtype AdapterKind = <Your Adapter>` to use it during mapping.

## Realm
There are tests included in `./RealmCrustTests` that include examples of how to use Crust with realm-cocoa (Obj-C).

If you wish to use Crust with RealmSwift check out this (slightly outdated) repo for examples.
https://github.com/rexmas/RealmCrust

## Contributing

Pull requests are welcome!

- Open an issue if you run into any problems.
- Fork the project and submit a pull request to contribute. Please include tests for new code.

## License
The MIT License (MIT)

Copyright (c) 2015-2017 Rex

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
