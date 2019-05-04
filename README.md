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
- [x] 🔨 [Query Builder](#query-builder)
- [x] ⛑ [Type safe Mapping](#crust-for-type-safe-mapping)
- [x] 🆒 [Type safe JSON](#jsonvalue-for-type-safe-json)
- [x] 🐙 [Threading](#threading)
- [x] 🌐 [Network Library](#network-library)
- [ ] 🔮 Network Library Agnostic
- [ ] 🥓 [Batched Queries](#batched-queries)

AutoGraph is a Swift client framework for making requests using GraphQL and mapping the responses to strongly typed models. Models may be represented by any `Decodable` type. AutoGraph relies heavily on Swift's type safety to drive it, leading to safer, compile time checked code.

## Requirements

Swift 5.0

- Swift 5.0 pre Decodable - use version `0.8.0`
- Swift 4.2+ - use version `0.7.0`.
- Swift 4.1.2 - use version `0.5.1`.
- Swift 4.0 - use version `0.4.6`.
- Swift 3 use version `0.3.0`.

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

### Swift Package Manager (SPM)

```swift
dependencies: [
.package(url: "https://github.com/remind101/AutoGraph.git", .upToNextMinor(from: "0.9.0"))
]
```

## Code Generation

Code generation is in an early-alpha stage. If you're interested in testing it please open an inquiry.

## Databases

##### Update
Previously this project would map into any arbitrary database directly via a database mapping library. In practice we've found that mapping to pure structs through Codable is simpler and enables more flexibility when combined with code generation. If you wish to still map directly to a database in the old style please use version `0.8.0`. Going forward we are internally exploring different methods of code generation that enable flexible, code generated database caching behind the scenes. We hope to open source our efforts in the future, stay tuned.

## Query Builder

AutoGraph includes a GraphQL query builder to construct queries in a type safe manner. However, using the query builder is not required; any object which inherits `GraphQLQuery` can act as a query. `String` inherits this by default.

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

## Decodable for type safe Models

AutoGraph relies entirely on [Decodable](https://developer.apple.com/documentation/foundation/archives_and_serialization/encoding_and_decoding_custom_types) for mapping GraphQL JSON responses to data models. It's as easy as conforming the model to `Decodable`!

## Threading

AutoGraph performs all network requests and mapping off of the main thread. Since a `Request` will eventually return whole models back to the caller on the main thread, it's important to consider thread safety with the model types being used. For this reason, using immutable `struct` types as models is recommended.

## Network Library

AutoGraph currently relies on [Alamofire](https://github.com/Alamofire/Alamofire) for networking. However this isn't a hard requirement. Pull requests for this are encouraged!

## Usage:

### Request Protocol

1. Create a class that conforms to the Request protocol. You can also extend an existing class to conform to this protocol. Request is a base protocol used for GraphQL requests sent through AutoGraph. It provides the following parameters.
   1. `queryDocument` - The query being sent. You may use the Query Builder or a String.
   2. `variables` - The variables to be sent with the query. A `Dictionary` is accepted.
   2. `rootKeyPath` - Defines where to start mapping data from. Empty string (`""`) will map from the root of the JSON.
   3. An `associatedtype SerializedObject: Decodable` must be provided to tell AutoGraph what data model to decode to.
   4. A number of methods to inform the Request of its point in the life cycle.

```swift
class FilmRequest: Request {
    /*
     query film {
        film(id: "ZmlsbXM6MQ==") {
            id
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
                                    Scalar(name: "title", alias: nil),
                                    Scalar(name: "episodeID", alias: nil),
                                    Scalar(name: "director", alias: nil),
                                    Scalar(name: "openingCrawl", alias: nil)])
                            ])
    
    let variables: [AnyHashable : Any]? = nil

    let rootKeyPath: String = "data.film"

    public func willSend() throws { }
    public func didFinishRequest(response: HTTPURLResponse?, json: JSONValue) throws { }
    public func didFinish(result: Result<Film>) throws { }
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
- Keep LinuxTests up-to-date `swift test --generate-linuxmain`
- If you see an error like this while building from the command line `could not build Objective-C module` try prepending commands with `xcrun -sdk macosx`

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
