import Foundation
import JSONValueRX

/// Everywhere there is a *query error* in the spec it falls into this bucket of errors.
enum OperationQueryError: LocalizedError {
    case ambiguousOperationsError
    case missingOperationError(operationName: String)
    case failedToCoerceError(variableValue: Any?, variableType: InputType)
    
    public var errorDescription: String? {
        switch self {
        case .ambiguousOperationsError:
            return "Can only have 1 operation in an anonymous query for a request."
        case .missingOperationError(let operationName):
            return "No Operation for Operation Name \(operationName)"
        case .failedToCoerceError(let variableValue, let variableType):
            return "Failed to coerce variable value of \(String(describing: variableValue)) to variable type of \(variableType)"
        }
    }
}

/// Everywhere there is a *field error* in the spec it falls into this bucket of errors.
enum FieldError: LocalizedError {
    case nonNullValueIsNull(fieldResponseKey: String)
    case failedToCoerceToList(fieldResponseKey: String)
    case failedToCoerceToObject(fieldResponseKey: String)
    case failedToCoerceToScalar(fieldResponseKey: String)
    
    public var errorDescription: String? {
        switch self {
        case .nonNullValueIsNull(let fieldResponseKey):
            return "NonNull value is Null for field \(fieldResponseKey)"
        case .failedToCoerceToList(let fieldResponseKey):
            return "Failed to coerce value to List or Array value for field \(fieldResponseKey)"
        case .failedToCoerceToObject(let fieldResponseKey):
            return "Failed to coerce value to Object or Dictionary value for field \(fieldResponseKey)"
        case .failedToCoerceToScalar(let fieldResponseKey):
            return "Failed to coerce value to Scalar value for field \(fieldResponseKey)"
        }
    }
}

// NOTE: TODO: In theory we should allow receiving more than one FieldError but during execution we're just bailing out early.
enum ExecutionResult<Value> {
    case data(Value)
    case errors([FieldError])
}

// TODO: If we make ScalarValue canonical across the board then a whole lot less
// pattern matching for scalars necessary i.e. PayloadValue
public enum ScalarValue {
    case int(Int64)
    case float(Double)
    case string(String)
    case bool(Bool)
    case null // TODO: scalar's aren't null
}

public indirect enum CompletedValue<ResultMapType>: ResolvableValue {
    case scalar(ScalarValue)
    case object(ResultMapType)
    case list([CompletedValue<ResultMapType>])
    case null
    
    public var isNull: Bool {
        guard case .null = self else { return false }
        return true
    }
    
    public var asList: [CompletedValue<ResultMapType>]? {
        guard case .list(let list) = self else { return nil }
        return list
    }
}

public protocol ResolvableValue {
    var isNull: Bool { get }
    var asList: [Self]? { get }
}

public protocol Accumulator {
    associatedtype AccumulatedResults
    associatedtype AccumulatedValue
    
    var accumulatedResults: AccumulatedResults { get }
    mutating func accumulate(
        responseKey: String,
        value: CompletedValue<[String : AccumulatedValue]>,
        for field: Field,
        at path: Path,
        with variableValues: [AnyHashable : Any],
        cacheKeyFunc: CacheKeyForObject?
    ) throws -> AccumulatedValue
}

public protocol Resolver {
    associatedtype ObjectValue
    associatedtype ResolvedValue: ResolvableValue
    
    //### Value Resolution
    //
    //While nearly all of GraphQL execution can be described generically, ultimately
    //the internal system exposing the GraphQL interface must provide values.
    //This is exposed via {ResolveFieldValue}, which produces a value for a given
    //field on a type for a real value.
    //
    //As an example, this might accept the {objectType} `Person`, the {field}
    //{"soulMate"}, and the {objectValue} representing John Lennon. It would be
    //expected to yield the value representing Yoko Ono.
    //
    //ResolveFieldValue(objectType, objectValue, fieldName, argumentValues):
    //  * Let {resolver} be the internal function provided by {objectType} for
    //    determining the resolved value of a field named {fieldName}.
    //  * Return the result of calling {resolver}, providing {objectValue} and {argumentValues}.
    //
    //Note: It is common for {resolver} to be asynchronous due to relying on reading
    //an underlying database or networked service to produce a value. This
    //necessitates the rest of a GraphQL executor to handle an asynchronous
    //execution flow.
    func resolveFieldValue(
        field: Field,
        objectType: String,
        objectValue: ObjectValue,
        fieldName: String,
        argumentValues: [AnyHashable : InputValue]
    ) throws -> ResolvedValue
    
    func objectValue(from value: ResolvedValue, field: Field) -> ObjectValue?
    func scalarValue(from value: ResolvedValue, field: Field) -> ScalarValue?
}

/// Executes a GraphQL Request. https://facebook.github.io/graphql/June2018/#sec-Execution
public final class Executor<_Resolver: Resolver, _Accumulator: Accumulator>
where _Resolver.ResolvedValue == _Accumulator.AccumulatedValue {
    public let resolver: _Resolver
    public private(set) var accumulator: _Accumulator
    
    public var cacheKeyForObject: CacheKeyForObject?
    
    public init(resolver: _Resolver, accumulator: _Accumulator, cacheKeyForObject: CacheKeyForObject? = nil) {
        self.resolver = resolver
        self.accumulator = accumulator
        self.cacheKeyForObject = cacheKeyForObject
    }
    
    //# Execution
    //
    //GraphQL generates a response from a request via execution.
    //
    //A request for execution consists of a few pieces of information:
    //
    //* The schema to use, typically solely provided by the GraphQL service.
    //* A {Document} which must contain GraphQL {OperationDefinition} and may contain {FragmentDefinition}.
    //* Optionally: The name of the Operation in the Document to execute.
    //* Optionally: Values for any Variables defined by the Operation.
    //* An initial value corresponding to the root type being executed.
    //  Conceptually, an initial value represents the "universe" of data available via
    //  a GraphQL Service. It is common for a GraphQL Service to always use the same
    //  initial value for every request.
    //
    //Given this information, the result of {ExecuteRequest()} produces the response,
    //to be formatted according to the Response section below.
    //
    //
    //## Executing Requests
    //
    //To execute a request, the executor must have a parsed {Document} and a selected
    //operation name to run if the document defines multiple operations, otherwise the
    //document is expected to only contain a single operation. The result of the
    //request is determined by the result of executing this operation according to the
    //"Executing Operations” section below.
    //
    //ExecuteRequest(schema, document, operationName, variableValues, initialValue):
    //
    //  * Let {operation} be the result of {GetOperation(document, operationName)}.
    //  * Let {coercedVariableValues} be the result of {CoerceVariableValues(schema, operation, variableValues)}.
    //  * If {operation} is a query operation:
    //    * Return {ExecuteQuery(operation, schema, coercedVariableValues, initialValue)}.
    //  * Otherwise if {operation} is a mutation operation:
    //    * Return {ExecuteMutation(operation, schema, coercedVariableValues, initialValue)}.
    //  * Otherwise if {operation} is a subscription operation:
    //    * Return {Subscribe(operation, schema, coercedVariableValues, initialValue)}.
    // TODO: Resolver fetches data out of something.
    // TODO: Accumulator stores result value somewhere.
    // TODO: JSONAccumulator
    //  * complete value adds to json payload
    // TODO: RecordDestructuringResult accumulator
    //  * complete value adds to record payload and record set
    // TODO: Watch Accumulator
    //  * Accumulates watchers
    // TODO: Generic ExecutionAccumulator
    //  * generic calls for accumulation
    // TODO: CacheResolver
    //  * object reads from cache for cache key
    //  * scalar read from data for response key
    //  * directives do shit
    //  * if type is list and directives exist specialize query
    // TODO: JSONResolver
    //  * pull shit out of json object
    // TODO: Watch Resolver
    //  * creates watchers with semantics similar to CacheResolver, consists of cacheKey plus where clause/query.
    //    watch must be started on returned thread so they must be carried up and activated only once back on calling thread.
    func executeRequest(document: Document, operationName: String, variableValues: [AnyHashable : Any], initialValue: _Resolver.ObjectValue) throws -> ExecutionResult<[String : _Resolver.ResolvedValue]> {
        let operation = try ExecutorHelpers.getOperation(document: document, operationName: operationName)
        let coercedVariableValues = try ExecutorHelpers.coerceVariableValues(operation: operation, variableValues: variableValues)
        switch operation.type {
        case .query:
            return try self.executeQuery(query: operation, variableValues: coercedVariableValues, initialValue: initialValue, from: document)
        case .mutation:
            return try self.executeMutation(mutation: operation, variableValues: coercedVariableValues, initialValue: initialValue, from: document)
        case .subscription:
            fatalError("Do not yet support subscription")
        }
    }
    
    //## Executing Operations
    //
    //The type system, as described in the "Type System" section of the spec, must
    //provide a query root object type. If mutations or subscriptions are supported,
    //it must also provide a mutation or subscription root object type, respectively.
    //
    //### Query
    //
    //If the operation is a query, the result of the operation is the result of
    //executing the query’s top level selection set with the query root object type.
    //
    //An initial value may be provided when executing a query.
    //
    //ExecuteQuery(query, schema, variableValues, initialValue):
    //
    //  * Let {queryType} be the root Query type in {schema}.
    //  * Assert: {queryType} is an Object type.
    //  * Let {selectionSet} be the top level Selection Set in {query}.
    //  * Let {data} be the result of running
    //    {ExecuteSelectionSet(selectionSet, queryType, initialValue, variableValues)}
    //    *normally* (allowing parallelization).
    //  * Let {errors} be any *field errors* produced while executing the
    //    selection set.
    //  * Return an unordered map containing {data} and {errors}.
    func executeQuery(query: Operation, variableValues: [AnyHashable : Any], initialValue: _Resolver.ObjectValue, from document: Document) throws -> ExecutionResult<[String : _Resolver.ResolvedValue]> {
        // These are guarenteed server-side.
        //  * Let {queryType} be the root Query type in {schema}.
        //  * Assert: {queryType} is an Object type.
        
        return try self.execute(operation: query, variableValues: variableValues, initialValue: initialValue, from: document)
    }
    
    //### Mutation
    //
    //If the operation is a mutation, the result of the operation is the result of
    //executing the mutation’s top level selection set on the mutation root
    //object type. This selection set should be executed serially.
    //
    //It is expected that the top level fields in a mutation operation perform
    //side-effects on the underlying data system. Serial execution of the provided
    //mutations ensures against race conditions during these side-effects.
    //
    //ExecuteMutation(mutation, schema, variableValues, initialValue):
    //
    //  * Let {mutationType} be the root Mutation type in {schema}.
    //  * Assert: {mutationType} is an Object type.
    //  * Let {selectionSet} be the top level Selection Set in {mutation}.
    //  * Let {data} be the result of running
    //    {ExecuteSelectionSet(selectionSet, mutationType, initialValue, variableValues)}
    //    *serially*.
    //  * Let {errors} be any *field errors* produced while executing the
    //    selection set.
    //  * Return an unordered map containing {data} and {errors}.
    func executeMutation(mutation: Operation, variableValues: [AnyHashable : Any], initialValue: _Resolver.ObjectValue, from document: Document) throws -> ExecutionResult<[String : _Resolver.ResolvedValue]> {
        // These are guarenteed server-side.
        //  * Let {mutationType} be the root Mutation type in {schema}.
        //  * Assert: {mutationType} is an Object type.
        
        return try self.execute(operation: mutation, variableValues: variableValues, initialValue: initialValue, from: document)
    }
    
    /// Generic operation execution
    func execute(operation: Operation, variableValues: [AnyHashable : Any], initialValue: _Resolver.ObjectValue, from document: Document) throws -> ExecutionResult<[String : _Resolver.ResolvedValue]> {
        let selectionSet = operation.selectionSet
        do {
            let data = try self.executeSelectionSet(selectionSet: selectionSet.selections, objectType: "TODO", objectValue: initialValue, variableValues: variableValues, at: [operation.type], from: document)
            return .data(data)
        }
        catch let e as FieldError {
            return .errors([e])
        }
    }
    
    //### Subscription
    // Not yet supported.
    
    //## Executing Selection Sets
    //
    //To execute a selection set, the object value being evaluated and the object type
    //need to be known, as well as whether it must be executed serially, or may be
    //executed in parallel.
    //
    //First, the selection set is turned into a grouped field set; then, each
    //represented field in the grouped field set produces an entry into a
    //response map.
    //
    //ExecuteSelectionSet(selectionSet, objectType, objectValue, variableValues):
    //
    //  * Let {groupedFieldSet} be the result of
    //    {CollectFields(objectType, selectionSet, variableValues)}.
    //  * Initialize {resultMap} to an empty ordered map.
    //  * For each {groupedFieldSet} as {responseKey} and {fields}:
    //    * Let {fieldName} be the name of the first entry in {fields}.
    //      Note: This value is unaffected if an alias is used.
    //    * Let {fieldType} be the return type defined for the field {fieldName} of {objectType}.
    //    * If {fieldType} is defined:
    //      * Let {responseValue} be {ExecuteField(objectType, objectValue, fields, fieldType, variableValues)}.
    //      * Set {responseValue} as the value for {responseKey} in {resultMap}.
    //  * Return {resultMap}.
    //
    //Note: {resultMap} is ordered by which fields appear first in the query. This
    //is explained in greater detail in the Field Collection section below.
    //
    //**Errors and Non-Null Fields**
    //
    //If during {ExecuteSelectionSet()} a field with a non-null {fieldType} throws a
    //field error then that error must propagate to this entire selection set, either
    //resolving to {null} if allowed or further propagated to a parent field.
    //
    //If this occurs, any sibling fields which have not yet executed or have not yet
    //yielded a value may be cancelled to avoid unnecessary work.
    //
    //See the [Errors and Non-Nullability](#sec-Errors-and-Non-Nullability) section
    //of Field Execution for more about this behavior.
    func executeSelectionSet(
        selectionSet: [Selection],
        objectType: String,
        objectValue: _Resolver.ObjectValue,
        variableValues: [AnyHashable : Any],
        at path: Path,
        from originatingDocument: Document
    ) throws -> [String : _Resolver.ResolvedValue] {
        var groupedFieldSet = GroupedFields()
        var visitedFragments = [String]()
        collectFields(objectType: objectType,
                      selectionSet: selectionSet,
                      variableValues: variableValues,
                      visitedFragments: &visitedFragments,
                      into: &groupedFieldSet,
                      from: originatingDocument)

        return try groupedFieldSet.reduce(into: [String : _Resolver.ResolvedValue]()) { (result, fieldSet) in
            let (responseKey, fields) = fieldSet
            let field = fields[0]
            // Note: This value is unaffected if an alias is used.
            let fieldType = field.type
            let nextPath = path + [field]
            let responseValue = try self.executeField(objectType: objectType, objectValue: objectValue, fieldType: fieldType, fields: fields, variableValues: variableValues, at: nextPath, from: originatingDocument)
            let transformedValue = try self.accumulator.accumulate(responseKey: responseKey, value: responseValue, for: field, at: nextPath, with: variableValues, cacheKeyFunc: self.cacheKeyForObject)
            result[responseKey] = transformedValue
        }
    }
    
    //### Normal and Serial Execution
    //
    //Normally the executor can execute the entries in a grouped field set in whatever
    //order it chooses (normally in parallel). Because the resolution of fields other
    //than top-level mutation fields must always be side effect-free and idempotent,
    //the execution order must not affect the result, and hence the server has the
    //freedom to execute the field entries in whatever order it deems optimal.
    //
    //For example, given the following grouped field set to be executed normally:
    //
    //```graphql example
    //{
    //  birthday {
    //    month
    //  }
    //  address {
    //    street
    //  }
    //}
    //```
    //
    //A valid GraphQL executor can resolve the four fields in whatever order it
    //chose (however of course `birthday` must be resolved before `month`, and
    //`address` before `street`).
    //
    //When executing a mutation, the selections in the top most selection set will be
    //executed in serial order, starting with the first appearing field textually.
    //
    //When executing a grouped field set serially, the executor must consider each entry
    //from the grouped field set in the order provided in the grouped field set. It must
    //determine the corresponding entry in the result map for each item to completion
    //before it continues on to the next item in the grouped field set:
    //
    //For example, given the following selection set to be executed serially:
    //
    //```graphql example
    //{
    //  changeBirthday(birthday: $newBirthday) {
    //    month
    //  }
    //  changeAddress(address: $newAddress) {
    //    street
    //  }
    //}
    //```
    //
    //The executor must, in serial:
    //
    // - Run {ExecuteField()} for `changeBirthday`, which during {CompleteValue()}
    //   will execute the `{ month }` sub-selection set normally.
    // - Run {ExecuteField()} for `changeAddress`, which during {CompleteValue()}
    //   will execute the `{ street }` sub-selection set normally.
    //
    //As an illustrative example, let's assume we have a mutation field
    //`changeTheNumber` that returns an object containing one field,
    //`theNumber`. If we execute the following selection set serially:
    //
    //```graphql example
    //{
    //  first: changeTheNumber(newNumber: 1) {
    //    theNumber
    //  }
    //  second: changeTheNumber(newNumber: 3) {
    //    theNumber
    //  }
    //  third: changeTheNumber(newNumber: 2) {
    //    theNumber
    //  }
    //}
    //```
    //
    //The executor will execute the following serially:
    //
    // - Resolve the `changeTheNumber(newNumber: 1)` field
    // - Execute the `{ theNumber }` sub-selection set of `first` normally
    // - Resolve the `changeTheNumber(newNumber: 3)` field
    // - Execute the `{ theNumber }` sub-selection set of `second` normally
    // - Resolve the `changeTheNumber(newNumber: 2)` field
    // - Execute the `{ theNumber }` sub-selection set of `third` normally
    //
    //A correct executor must generate the following result for that selection set:
    //
    //```json example
    //{
    //  "first": {
    //    "theNumber": 1
    //  },
    //  "second": {
    //    "theNumber": 3
    //  },
    //  "third": {
    //    "theNumber": 2
    //  }
    //}
    //```
    //
    //## Executing Fields
    //
    //Each field requested in the grouped field set that is defined on the selected
    //objectType will result in an entry in the response map. Field execution first
    //coerces any provided argument values, then resolves a value for the field, and
    //finally completes that value either by recursively executing another selection
    //set or coercing a scalar value.
    //
    //ExecuteField(objectType, objectValue, fieldType, fields, variableValues):
    //  * Let {field} be the first entry in {fields}.
    //  * Let {fieldName} be the field name of {field}.
    //  * Let {argumentValues} be the result of {CoerceArgumentValues(objectType, field, variableValues)}
    //  * Let {resolvedValue} be {ResolveFieldValue(objectType, objectValue, fieldName, argumentValues)}.
    //  * Return the result of {CompleteValue(fieldType, fields, resolvedValue, variableValues)}.
    func executeField(
        objectType: String,
        objectValue: _Resolver.ObjectValue,
        fieldType: FieldType,
        fields: [Field],
        variableValues: [AnyHashable : Any],
        at path: Path,
        from originatingDocument: Document
    ) throws -> CompletedValue<[String : _Resolver.ResolvedValue]> {
        let field = fields[0]
        let fieldName = field.name
        let argumentValues = try ExecutorHelpers.coerceArgumentValues(objectType: objectType, field: field, variableValues: variableValues)
        // Resolve gets my data from somewhere e.g. DB or JSON payload.
        let resolvedValue = try self.resolver.resolveFieldValue(field: field, objectType: objectType, objectValue: objectValue, fieldName: fieldName, argumentValues: argumentValues)
        // Complete validates the data and if an object recursively traverses fields.
        let completedResult = try self.completeValue(fieldType: fieldType, fields: fields, result: resolvedValue, variableValues: variableValues, at: path, from: originatingDocument)
        return completedResult
    }

    //### Value Completion
    //
    //After resolving the value for a field, it is completed by ensuring it adheres
    //to the expected return type. If the return type is another Object type, then
    //the field execution process continues recursively.
    //
    //CompleteValue(fieldType, fields, result, variableValues):
    //  * If the {fieldType} is a Non-Null type:
    //    * Let {innerType} be the inner type of {fieldType}.
    //    * Let {completedResult} be the result of calling
    //      {CompleteValue(innerType, fields, result, variableValues)}.
    //    * If {completedResult} is {null}, throw a field error.
    //    * Return {completedResult}.
    //  * If {result} is {null} (or another internal value similar to {null} such as
    //    {undefined} or {NaN}), return {null}.
    //  * If {fieldType} is a List type:
    //    * If {result} is not a collection of values, throw a field error.
    //    * Let {innerType} be the inner type of {fieldType}.
    //    * Return a list where each list item is the result of calling
    //      {CompleteValue(innerType, fields, resultItem, variableValues)}, where
    //      {resultItem} is each item in {result}.
    //  * If {fieldType} is a Scalar or Enum type:
    //    * Return the result of "coercing" {result}, ensuring it is a legal value of
    //      {fieldType}, otherwise {null}.
    //  * If {fieldType} is an Object, Interface, or Union type:
    //    * If {fieldType} is an Object type.
    //      * Let {objectType} be {fieldType}.
    //    * Otherwise if {fieldType} is an Interface or Union type.
    //      * Let {objectType} be {ResolveAbstractType(fieldType, result)}.
    //    * Let {subSelectionSet} be the result of calling {MergeSelectionSets(fields)}.
    //    * Return the result of evaluating {ExecuteSelectionSet(subSelectionSet, objectType, result, variableValues)} *normally* (allowing for parallelization).
    func completeValue(
        fieldType: FieldType,
        fields: [Field],
        result: _Resolver.ResolvedValue,
        variableValues: [AnyHashable : Any],
        at path: Path,
        from originatingDocument: Document
    ) throws -> CompletedValue<[String : _Resolver.ResolvedValue]> {
        let typeIsNonNull: Bool = {
            if case .nonNull = fieldType {
                return true
            }
            return false
        }()
        
        if !typeIsNonNull && result.isNull {
            return .null
        }
        
        let field = fields[0]
        
        switch fieldType {
        // According to the spec we evaluate in this order: nonnull, list, scalar, object:
        case .nonNull(let innerType):
            let completedResult = try self.completeValue(fieldType: innerType, fields: fields, result: result, variableValues: variableValues, at: path, from: originatingDocument)
            if completedResult.isNull {
                throw FieldError.nonNullValueIsNull(fieldResponseKey: field.responseKey)
            }
            
            return completedResult
        case .list(let innerType):
            guard let list = result.asList else {
                throw FieldError.failedToCoerceToList(fieldResponseKey: field.responseKey)
            }
            return .list(try list.enumerated().map { element in
                let (index, result) = element
                let indexedPath = path + [index]
                return try self.completeValue(fieldType: innerType, fields: fields, result: result, variableValues: variableValues, at: indexedPath, from: originatingDocument)
            })
        case .scalar:   // Or Enum type.
            //    * Return the result of "coercing" {result}, ensuring it is a legal value of
            //      {fieldType}, otherwise {null}.
            // NOTE: Could do some validation here in theory if scalar carried the metatype of it's final type.
            guard let scalar = self.resolver.scalarValue(from: result, field: field) else {
                throw FieldError.failedToCoerceToScalar(fieldResponseKey: field.responseKey)
            }
            return .scalar(scalar)
        case .object:   // Or Interface or Union type.
            guard let nextObjectValue = self.resolver.objectValue(from: result, field: field) else {
                throw FieldError.failedToCoerceToObject(fieldResponseKey: fields[0].responseKey)
            }
            
            let subSelectionSet = ExecutorHelpers.mergeSelectionSets(fields: fields)
            let completedObject = try executeSelectionSet(selectionSet: subSelectionSet,
                                                          objectType: "TODO",
                                                          objectValue: nextObjectValue,
                                                          variableValues: variableValues,
                                                          at: path,
                                                          from: originatingDocument)
            return .object(completedObject)
        }
    }
}

/// Contains methods that are a part of GQL execution
/// (https://facebook.github.io/graphql/June2018/#sec-Execution)
/// but do not require any state.
struct ExecutorHelpers {
    //GetOperation(document, operationName):
    //
    //  * If {operationName} is {null}:
    //    * If {document} contains exactly one operation.
    //      * Return the Operation contained in the {document}.
    //    * Otherwise produce a query error requiring {operationName}.
    //  * Otherwise:
    //    * Let {operation} be the Operation named {operationName} in {document}.
    //    * If {operation} was not found, produce a query error.
    //    * Return {operation}.
    static func getOperation(document: Document, operationName: String?) throws -> Operation {
        guard let operationName = operationName else {
            guard document.operations.count == 1, let operation = document.operations.first else {
                throw OperationQueryError.ambiguousOperationsError
            }
            
            return operation
        }
        
        guard let operation = document.operations.first(where: { $0.name == operationName }) else {
            throw OperationQueryError.missingOperationError(operationName: operationName)
        }
        
        return operation
    }
    
    //### Coercing Variable Values
    //
    //If the operation has defined any variables, then the values for
    //those variables need to be coerced using the input coercion rules
    //of variable's declared type. If a query error is encountered during
    //input coercion of variable values, then the operation fails without
    //execution.
    //
    //CoerceVariableValues(schema, operation, variableValues):
    //
    //  * Let {coercedValues} be an empty unordered Map.
    //  * Let {variableDefinitions} be the variables defined by {operation}.
    //  * For each {variableDefinition} in {variableDefinitions}:
    //    * Let {variableName} be the name of {variableDefinition}.
    //    * Let {variableType} be the expected type of {variableDefinition}.
    //    * Assert: {IsInputType(variableType)} must be {true}.
    //    * Let {defaultValue} be the default value for {variableDefinition}.
    //    * Let {hasValue} be {true} if {variableValues} provides a value for the
    //      name {variableName}.
    //    * Let {value} be the value provided in {variableValues} for the
    //      name {variableName}.
    //    * If {hasValue} is not {true} and {defaultValue} exists (including {null}):
    //      * Add an entry to {coercedValues} named {variableName} with the
    //        value {defaultValue}.
    //    * Otherwise if {variableType} is a Non-Nullable type, and either {hasValue}
    //      is not {true} or {value} is {null}, throw a query error.
    //    * Otherwise if {hasValue} is true:
    //      * If {value} is {null}:
    //        * Add an entry to {coercedValues} named {variableName} with the
    //          value {null}.
    //      * Otherwise:
    //        * If {value} cannot be coerced according to the input coercion
    //          rules of {variableType}, throw a query error.
    //        * Let {coercedValue} be the result of coercing {value} according to the
    //          input coercion rules of {variableType}.
    //        * Add an entry to {coercedValues} named {variableName} with the
    //          value {coercedValue}.
    //  * Return {coercedValues}.
    //
    //Note: This algorithm is very similar to {CoerceArgumentValues()}.
    static public func coerceVariableValues(operation: Operation, variableValues: [AnyHashable : Any]) throws -> [AnyHashable : Any] {
        let coercedValues = try operation.variableDefinitions?.reduce(into: [AnyHashable : Any]()) { (coercedValues, variableDefinition) in
            let variableName = variableDefinition.name
            let variableType = variableDefinition.typeName
            // Assert: {IsInputType(variableType)} must be {true}. is guarenteed by the type system.
            let defaultValue = variableDefinition.defaultValue
            let value = variableValues[variableName]
            let hasValue = value != nil
            if !hasValue, let defaultValue = defaultValue {
                coercedValues[variableName] = defaultValue
            }
                // NOTE: Keep in mind that a nullable input type can be omitted, value == nil is omit, null is NSNull.
            else if case .nonNull = variableType, !hasValue || value == nil {
                throw OperationQueryError.failedToCoerceError(variableValue: value, variableType: variableType)
            }
            else if hasValue {
                if case let value as NSNull = value {
                    coercedValues[variableName] = value
                }
                else {
                    // TODO: Should have InputType map to the correct coerced type and do
                    // 'Let {coercedValue} be the result of coercing {value} according to the input coercion rules of {variableType}.'
                    // However, for now just relying on server-side validation.
                    coercedValues[variableName] = value
                }
            }
        }
        
        return coercedValues ?? [:]
    }
    
    //### Coercing Field Arguments
    //
    //Fields may include arguments which are provided to the underlying runtime in
    //order to correctly produce a value. These arguments are defined by the field in
    //the type system to have a specific input type.
    //
    //At each argument position in a query may be a literal {Value}, or a {Variable}
    //to be provided at runtime.
    //
    //CoerceArgumentValues(objectType, field, variableValues):
    //  * Let {coercedValues} be an empty unordered Map.
    //  * Let {argumentValues} be the argument values provided in {field}.
    //  * Let {fieldName} be the name of {field}.
    //  * Let {argumentDefinitions} be the arguments defined by {objectType} for the
    //    field named {fieldName}.
    //  * For each {argumentDefinition} in {argumentDefinitions}:
    //    * Let {argumentName} be the name of {argumentDefinition}.
    //    * Let {argumentType} be the expected type of {argumentDefinition}.
    //    * Let {defaultValue} be the default value for {argumentDefinition}.
    //    * Let {hasValue} be {true} if {argumentValues} provides a value for the
    //      name {argumentName}.
    //    * Let {argumentValue} be the value provided in {argumentValues} for the
    //      name {argumentName}.
    //    * If {argumentValue} is a {Variable}:
    //      * Let {variableName} be the name of {argumentValue}.
    //      * Let {hasValue} be {true} if {variableValues} provides a value for the
    //        name {variableName}.
    //      * Let {value} be the value provided in {variableValues} for the
    //        name {variableName}.
    //    * Otherwise, let {value} be {argumentValue}.
    //    * If {hasValue} is not {true} and {defaultValue} exists (including {null}):
    //      * Add an entry to {coercedValues} named {argumentName} with the
    //        value {defaultValue}.
    //    * Otherwise if {argumentType} is a Non-Nullable type, and either {hasValue}
    //      is not {true} or {value} is {null}, throw a field error.
    //    * Otherwise if {hasValue} is true:
    //      * If {value} is {null}:
    //        * Add an entry to {coercedValues} named {argumentName} with the
    //          value {null}.
    //      * Otherwise, if {argumentValue} is a {Variable}:
    //        * Add an entry to {coercedValues} named {argumentName} with the
    //          value {value}.
    //      * Otherwise:
    //        * If {value} cannot be coerced according to the input coercion
    //            rules of {variableType}, throw a field error.
    //        * Let {coercedValue} be the result of coercing {value} according to the
    //          input coercion rules of {variableType}.
    //        * Add an entry to {coercedValues} named {argumentName} with the
    //          value {coercedValue}.
    //  * Return {coercedValues}.
    //
    //Note: Variable values are not coerced because they are expected to be coerced
    //before executing the operation in {CoerceVariableValues()}, and valid queries
    //must only allow usage of variables of appropriate types.
    static func coerceArgumentValues(objectType: String, field: Field, variableValues: [AnyHashable : Any]) throws -> [AnyHashable : InputValue] {
        guard let argumentValues = field.arguments else {
            return [:]
        }
        // Our code gen'd arguments on fields have all the information we need so we skip this step.
        //  * Let {argumentDefinitions} be the arguments defined by {objectType} for the
        //    field named {fieldName}.
        
        let coercedValues = argumentValues.reduce(into: [AnyHashable : InputValue]()) { (coercedValues, argument) in
            let argumentName = argument.key
            // This is server-side only.
            //  * Let {defaultValue} be the default value for {argumentDefinition}.
            let argumentValue = argument.value
            let (value, hasValue) = { () -> (InputValue?, Bool) in
                if case let variableValue as Variable = argumentValue {
                    let variableName = variableValue.name
                    guard case let value as InputValue = variableValues[variableName] else {
                        return (nil, false)
                    }
                    return (value, true)
                }
                else {
                    return (argumentValue, true)
                }
            }()
            
            // This is server-side only.
            //    * If {hasValue} is not {true} and {defaultValue} exists (including {null}):
            //      * Add an entry to {coercedValues} named {argumentName} with the
            //        value {defaultValue}.
            //    * Otherwise if {argumentType} is a Non-Nullable type, and either {hasValue}
            //      is not {true} or {value} is {null}, throw a field error.
            
            // Some redudancy just so it's clearer to read and compare to the spec.
            if hasValue, let value = value {
                if value is NSNull || argumentValue is Variable  {
                    coercedValues[argumentName] = value
                }
                else {
                    // TODO: Should have InputType map to the correct coerced type and do
                    // 'Let {coercedValue} be the result of coercing {value} according to the input coercion rules of {variableType}.
                    // However, for now just relying on server-side validation.
                    coercedValues[argumentName] = value
                }
            }
        }
        return coercedValues
    }
    
    //**Resolving Abstract Types**
    //
    //When completing a field with an abstract return type, that is an Interface or
    //Union return type, first the abstract type must be resolved to a relevant Object
    //type. This determination is made by the internal system using whatever
    //means appropriate.
    //
    //Note: A common method of determining the Object type for an {objectValue} in
    //object-oriented environments, such as Java or C#, is to use the class name of
    //the {objectValue}.
    //
    //ResolveAbstractType(abstractType, objectValue):
    //  * Return the result of calling the internal method provided by the type
    //    system for determining the Object type of {abstractType} given the
    //    value {objectValue}.
    
    // Not doing this. Confirmed by code generator.
    
    //**Merging Selection Sets**
    //
    //When more than one fields of the same name are executed in parallel, their
    //selection sets are merged together when completing the value in order to
    //continue execution of the sub-selection sets.
    //
    //An example query illustrating parallel fields with the same name with
    //sub-selections.
    //
    //```graphql example
    //{
    //  me {
    //    firstName
    //  }
    //  me {
    //    lastName
    //  }
    //}
    //```
    //
    //After resolving the value for `me`, the selection sets are merged together so
    //`firstName` and `lastName` can be resolved for one value.
    //
    //MergeSelectionSets(fields):
    //  * Let {selectionSet} be an empty list.
    //  * For each {field} in {fields}:
    //    * Let {fieldSelectionSet} be the selection set of {field}.
    //    * If {fieldSelectionSet} is null or empty, continue to the next field.
    //    * Append all selections in {fieldSelectionSet} to {selectionSet}.
    //  * Return {selectionSet}.
    static func mergeSelectionSets(fields: [Field]) -> [Selection] {
        let selectionSet: [[Selection]] = fields.compactMap { field in
            return field.type.selectionSet?.selections
        }
        return selectionSet.flatMap { $0 }
    }
}
