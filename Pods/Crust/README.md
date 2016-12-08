[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/Crust.svg)](https://img.shields.io/cocoapods/v/Crust.svg)
[![Build Status](https://travis-ci.org/rexmas/Crust.svg)](https://travis-ci.org/rexmas/Crust)

#Crust
A flexible Swift framework for converting classes and structs to and from JSON with support for storage solutions such as Realm.

#Features 🎸
- [Structs and Classes](#structs-and-classes)
- [Separation of Concerns (Mapped Model, Mapping, Storage)](#separation-of-concerns)
- [Type safe JSON](#jsonvalue-for-type-safe-json)
- [How To Map](#how-to-map)
  - [Nested Mappings](#nested-mappings)
  - [Mapping Context](#mapping-context)
  - [Custom Transformations](#custom-transformations)
  - [Different Mappings for Same Model](#different-mappings-for-same-model)
- [Storage Adaptor](#storage-adaptor)
- [Realm](#realm)
- Supports Optional Types and Collections.

#Requirements
iOS 8.0+
Swift 3.0+

#Installation
### CocoaPods
```
platform :ios, '8.0'
use_frameworks!

pod 'Crust'
```

#Structs and Classes
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

#Separation of Concerns

By design Crust is built with [separation of concerns](https://en.wikipedia.org/wiki/Separation_of_concerns) in mind. It makes no assumptions about how many ways a user would like to map to and from JSON and how many various ways the user would like to store their models.

Crust has 2 basic protocols:
- `Mapping`
	- How to map JSON to and from a particular model - (model is set by the `typealias MappedObject`).
	- May include primary key(s) and nested mapping(s).
- `Adaptor`
	- How to store and retrieve model objects used for mapping from a backing store (e.g. Core Data, Realm, etc.).

And 2 additional protocols when no storage `Adaptor` is required:
- `AnyMappable`
	- Inherited by the model (class or struct) to be mapped to and from JSON.
- `AnyMapping`
	- A `Mapping` that does not require an `Adaptor`.

There are no limitations on the number of various `Mapping`s and `Adaptor`s one may create per model for different use cases.

#JSONValue for type safe JSON
Crust relies on [JSONValue](https://github.com/rexmas/JSONValue) for it's JSON encoding and decoding mechanism. It offers many benefits including type safety, subscripting, and extensibility through protocols.

#How To Map

1. Create your mappings for your model using `Mapping` if with storage or `AnyMapping` if without storage.

    With storage (assume `CoreDataAdaptor` conforms to `Adaptor`)
    ```swift
    class EmployeeMapping: Mapping {
    
        var adaptor: CoreDataAdaptor
        var primaryKeys: [String, Keypath]? {
            return [ "uuid" : "data.uuid" ]    // Key == attribute on the model, Value == keypath in the JSON blob.
        }

        required init(adaptor: CoreDataAdaptor) {
            self.adaptor = adaptor
        }
    
        func mapping(tomap: inout Employee, context: MappingContext) {
            // Company must be transformed into something Core Data can use in this case.
            let companyMapping = CompanyTransformableMapping()
        
            tomap.employer              <- .mapping("company", companyMapping) >*<
            tomap.uuid                  <- "data.uuid" >*<
            tomap.name                  <- "data.name" >*<
            context
        }
    }
    ```
    Without storage
    ```swift
    class CompanyMapping: AnyMapping {
        // associatedtype MappedObject = Company is inferred by `tomap`
    
        func mapping(tomap: inout Company, context: MappingContext) {
            let employeeMapping = EmployeeMapping(adaptor: CoreDataAdaptor())
        
            tomap.employees             <- .mapping("employees", employeeMapping) >*<
            tomap.founder               <- .mapping("founder", employeeMapping) >*<
            tomap.uuid                  <- "uuid" >*<
            tomap.name                  <- "name" >*<
            tomap.foundingDate          <- "data.founding_date"  >*<
            tomap.pendingLawsuits       <- "data.lawsuits.pending"  >*<
            context
        }
    }
    ```

2. Create your Crust Mapper.
    ```swift
    let mapper = CRMapper()<Company, CompanyMapping>
    ```

3. Use the mapper to convert to and from `JSONValue` objects
    ```swift
    let json = try! JSONValue(object: [
                "uuid" : "uuid123",
                "name" : "name",
                "employees" : [
                    [ "name" : "Fred", "uuid" : "ABC123" ],
                    [ "name" : "Wilma", "uuid" : "XYZ098" ]
                ]
                "founder" : NSNull(),
                "data" : [
                    "lawsuits" : [
                        "pending" : 5
                    ]
                ],
                "data.founding_date" : NSDate().toISOString(),
            ]
    )
    let company = try! mapper.mapFromJSONToNewObject(json: json, mapping: CompanyMapping())
    ```

NOTE:
`JSONValue` can be converted back to an `AnyObject` variation of json via `json.values()` and to `NSData` via `try! json.encode()`.

###Nested Mappings
Crust supports nested mappings for nested models
E.g. from above
```swift
func mapping(inout tomap: Company, context: MappingContext) {
    let employeeMapping = EmployeeMapping(adaptor: CoreDataAdaptor())
    
    tomap.employees <- Spec.mapping("employees", employeeMapping) >*<
    context
}
```

###Mapping Context
Every `mapping` passes through a `context: MappingContext` which must be included during the mapping. The `context` includes error information that is propagated back from the mapping to the caller and contextual information about the json and object being mapped to/from.

There are two ways to include the context during mapping:

1. Include it as a tuple.

   ```swift
   func mapping(inout tomap: Company, context: MappingContext) {
       tomap.uuid <- ("uuid", context)
       tomap.name <- ("name", context)
   }
   ```
2. Use a specially included operator `>*<` which merges the result of the right expression with the left expression into a tuple. This may be chained in succession.

   ```swift
   func mapping(inout tomap: Company, context: MappingContext) {
       tomap.uuid <- "uuid" >*<
       tomap.name <- "name" >*<
       context
   }
   ```

###Custom Transformations
To create a simple custom transformation (such as to basic value types) implement the `Transform` protocol
```swift
public protocol Transform: AnyMapping {
    func fromJSON(_ json: JSONValue) throws -> MappedObject
    func toJSON(_ obj: MappedObject) -> JSONValue
}
```
and use it like any other `Mapping`.

###Different Mappings for Same Model
Multiple `Mapping`s are allowed for the same model.
```swift
class CompanyMapping: AnyMapping {
    func mapping(inout tomap: Company, context: MappingContext) {
        tomap.uuid <- "uuid" >*<
        tomap.name <- "name" >*<
        context
    }
}

class CompanyMappingWithNameUUIDReversed: AnyMapping {
	func mapping(inout tomap: Company, context: MappingContext) {
        tomap.uuid <- "name" >*<
        tomap.name <- "uuid" >*<
        context
    }
}
```
Just use two different mappers.
```swift
let mapper1 = CRMapper<Company, CompanyMapping>()
let mapper2 = CRMapper<Company, CompanyMappingWithNameUUIDReversed>()
```

#Storage Adaptor
Follow the `Adaptor` protocol to create a storage adaptor to Core Data, Realm, etc.

The object conforming to `Adaptor` must include two `associatedtype`s:
- `BaseType` - the top level class for this storage systems model objects.
  - Core Data this would be `NSManagedObject`.
  - Realm this would be `Object`.
- `ResultsType: Collection` - Used for object lookups. Should return a collection of `BaseType`s.

The `Mapping` must then set it's `associatedtype AdaptorKind = <Your Adaptor>` to use it during mapping.

#Realm
There are tests included in `./RealmCrustTests` that include examples of how to use Crust with realm-cocoa (Obj-C).

If you wish to use Crust with RealmSwift check out this (slightly outdated) repo for examples.
https://github.com/rexmas/RealmCrust

#Contributing

We love pull requests and solving bugs.

- Open an issue if you run into any problems.
- Fork the project and submit a pull request to contribute. Please include tests for new code.

#License
The MIT License (MIT)

Copyright (c) 2015-2016 Rex

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
