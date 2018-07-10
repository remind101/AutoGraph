[![AutoGraph](https://github.com/remind101/AutoGraph/blob/master/autograph.png)](https://github.com/remind101/AutoGraph/blob/master/autograph.png)

[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/AutoGraph.svg)](https://img.shields.io/cocoapods/v/AutoGraph.svg)
[![CircleCI](https://circleci.com/gh/remind101/AutoGraph.svg?style=shield&circle-token=3e12fea283d6d6476e480f1cc77e9b14a63e5487)](https://circleci.com/gh/remind101/AutoGraph)

The Swiftest way to GraphQL

- [Features](#features)
- [Usage](#usage)
- [Contributing](#contributing)
- [License](#license)

## Features 
- [ ] ⚡️ [Code Generation](#code-generation)
- [x] 💒 [Database Agnostic](#database-agnostic)
  - [x] 👑 [Realm](#realm)
    - [x] 🦃 Realm Obj-C
    - [ ] 🕊 Realm Swift
  - [ ] 💾 [Core Data](#core-data)
- [x] 🔨 [Query Builder](#query-builder)
- [x] ⛑ [Type safe Mapping](#crust-for-type-safe-mapping)
- [x] 🆒 [Type safe JSON](#jsonvalue-for-type-safe-json)
- [x] 🐙 [Threading](#threading)
- [x] 🌐 [Network Library](#network-library)
- [ ] 🔮 Network Library Agnostic
- [ ] 🥓 [Batched Queries](#batched-queries)
- [x] ❓ Supports Optional Types and Collections.

AutoGraph is a Swift client framework for making requests using GraphQL and mapping the responses to strongly typed models. Models may be represented by any type, including database model objects such as Realm or Core Data models. AutoGraph relies heavily on Swift's type safety to drive it, leading to safer, compile time checked code.

## Requirements
Swift 4.1.2+ - use version `0.5.1`+.
Swift 4.0 - use version `0.4.6`.
Swift 3 use version `0.3.0`.

### Platforms
- [x] iOS 8.0+
- [ ] tvOS
- [ ] watchOS
- [ ] macOS
- [ ] Linux

## Installation
### CocoaPods
```
platform :ios, '8.0'
use_frameworks!

pod 'AutoGraph'
```
### Future
- [ ] Swift Package Manager

## Code Generation
Code generation is in an alpha stage. If you're interested in testing it please open an inquiry.

## Database Agnostic
AutoGraph and it's mapping component [Crust](#crust-for-type-safe-mapping) are written to be database agnostic. To add support for a database to use in conjunction with AutoGraph, write an adapter class that inherits from Crust's [PersistanceAdapter](https://github.com/rexmas/Crust#persistance-adapter) protocol. This protocol maintains hooks where the business logic for writing to and reading from the database will live. A persistance adapter example already exists for Realm in the [tests](https://github.com/remind101/AutoGraph/blob/master/AutoGraphTests/Realm/RealmMappings.swift).

### Realm
Though AutoGraph is structured to be DB agnostic, it is heavily tested against the [Realm Cocoa](https://realm.io/docs/) database. Look [here](https://github.com/remind101/AutoGraph/blob/master/AutoGraphTests/AllFilmsRequest.swift) and [here](https://github.com/remind101/AutoGraph/tree/master/AutoGraphTests/Realm) for an example of how to use AutoGraph with Realm Objective-C. A RealmSwift Persistance Adapter example and tests are planned for the future.

### Core Data
AutoGraph's structure should allow for simple Core Data support. No tests or examples against Core Data currently exist but PRs are welcome!

## Query Builder
AutoGraph includes a GraphQL query builder to construct queries in a type safe manner. However, using the query builder is not required; any object which inherits `GraphQLQuery` can act as a query. String inherits this by default.


Query Example
```swift
Raw GraphQL         AutoGraph
-----------         ---------
query MyCoolQuery {         AutoGraphQL.Operation(type: .query, name: "MyCoolQuery", fields: [
  user {                        Object(name: "user", fields: [
    favorite_authors {              Object(name: "favorite_authors", fields: [,
      uuid                              "uuid",
      name                              "name"
    }                               ]),
    uuid                            "uuid",
    signature                       "signature"
  }                             ])
}
```

Mutation Example
```swift
Raw GraphQL
-----------         
mutation MyCoolMutation {
  updateFavoriteAuthor(uuid: "long_id", input: { name: "My Cool Name" })
  {
    favorite_author {
      uuid
      name
    }
  }
}

AutoGraph
---------
AutoGraphQL.Operation(type: .mutation, name: "MyCoolMutation", fields: [
                            Object(
                            name: "updateFavoriteAuthor",
                            arguments: [ // Continues "updateFavoriteAuthor".
                                "uuid" : "long_id",
                                "input" : [
                                   "name" : "My Cool Class"
                                ]
                            ],
                            fields: [
                                Object(
                                name: "favorite_author",
                                fields: [
                                    "uuid",
                                    "name"
                                    ])
                                ]
                        ])
```

### Supports
- [x] [Query Document](https://facebook.github.io/graphql/#sec-Language.Query-Document)
- [x] [Operations](https://facebook.github.io/graphql/#sec-Language.Operations)
- [x] [Mutations](http://graphql.org/learn/queries/#mutations)
- [x] [Selection Sets](https://facebook.github.io/graphql/#sec-Selection-Sets)
- [x] [Fields](https://facebook.github.io/graphql/#sec-Language.Fields)
- [x] [Arguments](https://facebook.github.io/graphql/#sec-Language.Arguments)
- [x] [Aliases](https://facebook.github.io/graphql/#sec-Field-Alias)
- [x] [Variables](https://facebook.github.io/graphql/#sec-Language.Variables)
- [x] [Input Values](https://facebook.github.io/graphql/#sec-Input-Values)
    - [x] [List Values](https://facebook.github.io/graphql/#sec-List-Value)
    - [x] [Input Object Values](https://facebook.github.io/graphql/#sec-Input-Object-Values)
- [x] [Fragments](https://facebook.github.io/graphql/#sec-Language.Fragments)
    - [x] Fragment Spread
    - [x] Fragment Definition
- [x] [Inline Fragments](https://facebook.github.io/graphql/#sec-Inline-Fragments)
- [x] [Directives](https://facebook.github.io/graphql/#sec-Language.Directives)

## Crust for type safe Mapping
AutoGraph relies entirely on [Crust](https://github.com/rexmas/Crust) for mapping JSON responses to models. Crust is a flexible framework that allows for the construction of multiple [Mappings](https://github.com/rexmas/Crust#how-to-map) to a single model and can simultaneously write to a corresponding database during mapping. Additionally, models can be represented by classes or structs.

Crust is an important component to AutoGraph's architecture. It allows AutoGraph to map multiple GraphQL [Fragments](http://graphql.org/learn/queries/#fragments) to a single model type, while storing all data into a DB of the developer's choice. More about Crust can be found in Crust's documentation.

## JSONValue for type safe JSON
Crust and by extension AutoGraph rely on [JSONValue](https://github.com/rexmas/JSONValue) for their JSON encoding and decoding mechanism. It offers many benefits including type safety, subscripting, and extensibility through protocols.

## Threading
AutoGraph performs all network requests and mapping off of the main thread. Since a `Request` will eventually return whole models back to the caller on the main thread, it's important to consider thread safety with the model types being used. For example, Realm model objects are thread confined; i.e. an exception will be thrown if a Realm model object is used from a thread it was not instantiated on. In order to safely pass the resulting model objects from the background to the main thread, `Request` has a `threadAdapter: ThreadAdapter` property which provides AutoGraph a way to safely pass models across thread boundaries.

E.g.
```swift
public class RealmThreadAdaptor: ThreadAdapter {
    public typealias BaseType = RLMObject

    public func threadSafeRepresentations(`for` objects: [RLMObject], ofType type: Any.Type) throws -> [RLMThreadSafeReference<RLMThreadConfined>] {
        return objects.map { RLMThreadSafeReference(threadConfined: $0) }
    }
    
    public func retrieveObjects(`for` representations: [RLMThreadSafeReference<RLMThreadConfined>]) throws -> [RLMObject] {
        let realm = RLMRealm.default()
        return representations.flatMap { realm.__resolve($0) as? RLMObject }
    }
}
```

For any resulting models that are safe to pass between threads, write a request that conforms to `ThreadUnconfinedRequest` instead of `Request` and `threadAdapter` will be ignored.

## Network Library
AutoGraph currently relies on [Alamofire](https://github.com/Alamofire/Alamofire) for networking. However this isn't a hard requirement. Work is planned to build a light-weight protocol separating the network library from the rest of AutoGraph. Pull requests for this are encouraged!

## Batched Queries
This is a planned feature that is not yet supported.

## Usage:

### Request Protocol

1. Create a class that conforms to the Request protocol. You can also extend an existing class to conform to this protocol. Request is a base protocol used for GraphQL requests sent through AutoGraph. It provides the following parameters.
    1. `query` - The query being sent. You may use the Query Builder or a String.
    2.  `mapping` - Defines how to map from the returned JSON payload to the result object.
    3. `threadAdapter` - Used to pass result objects across threads to return to the caller.
    4. A number of methods to inform the Request of its point in the life cycle.
```swift
class FilmRequest: Request {
    /*
     query film {
        film(id: "ZmlsbXM6MQ==") {
            title
            episodeID
            director
            openingCrawl
        }
     }
     */
    
    let query = Operation(type: .query,
                          name: "film",
                          fields: [
                            Object(name: "film",
                                   alias: nil,
                                   arguments: ["id" : "ZmlsbXM6MQ=="],
                                   fields: [
                                    "id",  // May use string literal or Scalar.
                                    "title",
                                    Scalar(name: "episodeID", alias: nil),
                                    Scalar(name: "director", alias: nil),
                                    Scalar(name: "openingCrawl", alias: nil)])
                            ])
    
    let variables: [AnyHashable : Any]? = nil
    
    // This is the `Mapping` that takes the returned JSON payload and converts it to a Film.
    var mapping: Binding<String, FilmMapping> {
        return Binding.mapping("data.film", FilmMapping(adapter: RealmAdapter(realm: RLMRealm.default())))
    }
    
    // This specifies what keys are included in the JSON payload (as defined by the query) that we will be mapping into Film.
    // It's possible that the query may be requesting a partial Film type; by only including these keys you're specifying to the mapping that any other keys will not be mapped.
    let mappingKeys: SetKeyCollection<FilmKey> = SetKeyCollection([.id, .title, .episodeId, .director, .openingCrawl])
    
    var threadAdapter: RealmThreadAdaptor? {
        return RealmThreadAdaptor()
    }
    
    public func willSend() throws { }
    public func didFinishRequest(response: HTTPURLResponse?, json: JSONValue) throws { }
    public func didFinish(result: Result<Film>) throws { }
}
```

### Mapping

1. Create a subclass of Mapping.
2. Define the primaryKeys for the object(s) being mapped using a PrimaryKeyDescriptor tuple.
    1. return `[ (property: <model_property>, keyPath: <json_keypath>, transform: nil) ]`
3. Implement the mapping(toMap:, context:) method using Crust's ← operator.
    1. Basic properties: `tomap.<property> <- (<json_keypath>, context)`
    2. Nested objects: `tomap.<object> <- (.mapping(<json_keypath>, <Mapping>), context)`
    3. To-Many relationships require an update policy.
        1. `tomap.<object> <- (.collectionMapping(<json_keypath>, <Mapping>, (.replace(delete: (all_old_objects) -> (objects_to_delete)) | .append, unique: Bool), context)`
        2. `unique` means we check against the primary key if the object is unique before inserting into the list. If we're updating an object in the list it will not be returned in `all_old_objects` for deletion.
4. In your request class, implement the mapping property to return a Binding value.
    1. `.collectionMapping` for list results.
    2. `.mapping` for single objects, (also work with list results but default to .replace, unique == true).
    3. The keyPath for the request will mirror the hierarchy of the query, with data at the root.

```swift
Raw GraphQL:
------------
{
  "data": {
    "user": {
        "authors": { // KeyPath = data.user.authors
        // ... Bunch o' authors
        }
    }
  }
}

AutoGraph:
----------
class MySweetRequest: Request {
    ...
    
    var mapping: Binding<String, AuthorMapping> {
        return Binding.mapping("data.user.authors", AuthorMapping())
    }
}
```

### Sending
#### Swift

1. Call send on AutoGraph
    1. `autoGraph.send(request, completion: { [weak self] result in ... }`
2. Handle the response
    1. result is a generic `Result<MappedObject>` enum with success and failure cases.

#### Objective-C
Sending via Objective-C isn't directly possible because of AutoGraph's use of `associatedtype` and generics. It is possible to build a bridge(s) from Swift into Objective-C to send requests. 

## Contributing

- Open an issue if you run into any problems.

### Pull Requests are welcome!

- Open an issue describing the feature add or problem being solved. An admin will respond ASAP to discuss the addition.
- You may begin working immediately if you so please, by adding an issue it helps inform others of what is already being worked on and facilitates discussion.
- Fork the project and submit a pull request. Please include tests for new code and an explanation of the problem being solved. An admin will review your code and approve it before merging.

## License
The MIT License (MIT)

Copyright (c) 2017-Present Remind101

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
