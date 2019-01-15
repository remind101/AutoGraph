import Foundation

// https://facebook.github.io/graphql/June2018/#CollectFields()
//The depth-first-search order of the field groups produced by {CollectFields()}
//is maintained through execution, ensuring that fields appear in the executed
//response in a stable and predictable order.
//
//CollectFields(objectType, selectionSet, variableValues, visitedFragments):
//
//  * If {visitedFragments} if not provided, initialize it to the empty set.
//  * Initialize {groupedFields} to an empty ordered map of lists.
//  * For each {selection} in {selectionSet}:
//    * If {selection} provides the directive `@skip`, let {skipDirective} be that directive.
//      * If {skipDirective}'s {if} argument is {true} or is a variable in {variableValues} with the value {true}, continue with the next
//      {selection} in {selectionSet}.
//    * If {selection} provides the directive `@include`, let {includeDirective} be that directive.
//      * If {includeDirective}'s {if} argument is not {true} and is not a variable in {variableValues} with the value {true}, continue with the next
//      {selection} in {selectionSet}.
//    * If {selection} is a {Field}:
//      * Let {responseKey} be the response key of {selection} (the alias if defined, otherwise the field name).
//      * Let {groupForResponseKey} be the list in {groupedFields} for
//        {responseKey}; if no such list exists, create it as an empty list.
//      * Append {selection} to the {groupForResponseKey}.
//    * If {selection} is a {FragmentSpread}:
//      * Let {fragmentSpreadName} be the name of {selection}.
//      * If {fragmentSpreadName} is in {visitedFragments}, continue with the
//        next {selection} in {selectionSet}.
//      * Add {fragmentSpreadName} to {visitedFragments}.
//      * Let {fragment} be the Fragment in the current Document whose name is
//        {fragmentSpreadName}.
//      * If no such {fragment} exists, continue with the next {selection} in
//        {selectionSet}.
//      * Let {fragmentType} be the type condition on {fragment}.
//      * If {DoesFragmentTypeApply(objectType, fragmentType)} is false, continue
//        with the next {selection} in {selectionSet}.
//      * Let {fragmentSelectionSet} be the top-level selection set of {fragment}.
//      * Let {fragmentGroupedFieldSet} be the result of calling
//        {CollectFields(objectType, fragmentSelectionSet, visitedFragments)}.
//      * For each {fragmentGroup} in {fragmentGroupedFieldSet}:
//        * Let {responseKey} be the response key shared by all fields in {fragmentGroup}.
//        * Let {groupForResponseKey} be the list in {groupedFields} for
//          {responseKey}; if no such list exists, create it as an empty list.
//        * Append all items in {fragmentGroup} to {groupForResponseKey}.
//    * If {selection} is an {InlineFragment}:
//      * Let {fragmentType} be the type condition on {selection}.
//      * If {fragmentType} is not {null} and {DoesFragmentTypeApply(objectType, fragmentType)} is false, continue
//        with the next {selection} in {selectionSet}.
//      * Let {fragmentSelectionSet} be the top-level selection set of {selection}.
//      * Let {fragmentGroupedFieldSet} be the result of calling {CollectFields(objectType, fragmentSelectionSet, variableValues, visitedFragments)}.
//      * For each {fragmentGroup} in {fragmentGroupedFieldSet}:
//        * Let {responseKey} be the response key shared by all fields in {fragmentGroup}.
//        * Let {groupForResponseKey} be the list in {groupedFields} for
//          {responseKey}; if no such list exists, create it as an empty list.
//        * Append all items in {fragmentGroup} to {groupForResponseKey}.
//  * Return {groupedFields}.
//
//DoesFragmentTypeApply(objectType, fragmentType):
//
//  * If {fragmentType} is an Object Type:
//    * if {objectType} and {fragmentType} are the same type, return {true}, otherwise return {false}.
//  * If {fragmentType} is an Interface Type:
//    * if {objectType} is an implementation of {fragmentType}, return {true} otherwise return {false}.
//  * If {fragmentType} is a Union:
//    * if {objectType} is a possible type of {fragmentType}, return {true} otherwise return {false}.
typealias GroupedFields = OrderedDictionary<String, [Field]>

enum PossibleDirectives: String {
    case skip
    case include
}

let ifArgumentName = "if"

/// Correlates to CollectFields(objectType, selectionSet, variableValues, visitedFragments)
/// https://facebook.github.io/graphql/June2018/#CollectFields()
func collectFields(
    objectType: String,
    selectionSet: [Selection],
    variableValues: [AnyHashable : Any],
    visitedFragments: inout Array<String>,
    into groupedFields: inout GroupedFields,
    from originatingDocument: Document
) {
    for selection in selectionSet {
        // If '@skip' directive is provided and is true then skip this field.
        if
            let skipDirective = selection.directives?.first(where: { $0.name == PossibleDirectives.skip.rawValue }),
            let ifVal = skipDirective.arguments?[ifArgumentName]
        {
            let isTrue: Bool = {
                switch ifVal {
                case let boolVal as Bool:
                    return boolVal
                case let variableDefinition as VariableDefinition<Bool>:
                    return (variableValues[variableDefinition.name] as? Bool) ?? false
                case let anyVariableDefinition as AnyVariableDefinition:
                    return (variableValues[anyVariableDefinition.name] as? Bool) ?? false
                default:
                    return false
                }
            }()
            if isTrue {
                continue
            }
        }
        
        // If '@include' directive is provided and is false then skip this field.
        if
            let includeDirective = selection.directives?.first(where: { $0.name == PossibleDirectives.include.rawValue }),
            let ifVal = includeDirective.arguments?[ifArgumentName]
        {
            let isTrue: Bool = {
                switch ifVal {
                case let boolVal as Bool:
                    return boolVal
                case let variableDefinition as VariableDefinition<Bool>:
                    return (variableValues[variableDefinition.name] as? Bool) ?? false
                case let anyVariableDefinition as AnyVariableDefinition:
                    return (variableValues[anyVariableDefinition.name] as? Bool) ?? false
                default:
                    return false
                }
            }()
            if !isTrue {
                continue
            }
        }
        
        switch selection {
        case .field(name: let name, alias: let alias, arguments: let arguments, directives: let directives, type: let fieldType):
            let field = Field(name: name, alias: alias, arguments: arguments, directives: directives, type: fieldType)
            let responseKey = alias ?? name
            // Optimized against copies.
            groupedFields.append(key: responseKey, value: field)
        case .fragmentSpread(name: let fragmentSpreadName, directives: _):
            guard !visitedFragments.contains(fragmentSpreadName) else {
                continue
            }
            visitedFragments.append(fragmentSpreadName)
            
            guard let fragment = originatingDocument.fragments.first(where: { $0.name == fragmentSpreadName }) else {
                continue
            }
            guard doesFragmentTypeApply(objectType: objectType, fragmentTypePossibleTypes: fragment.possibleTypes) else {
                continue
            }
            
            let fragmentSelectionSet = fragment.selectionSet
            collectFields(objectType: objectType,
                          selectionSet: fragmentSelectionSet.selections,
                          variableValues: variableValues,
                          visitedFragments: &visitedFragments,
                          into: &groupedFields,
                          from: originatingDocument)
        case .inlineFragment(namedType: _, directives: _, selectionSet: let selectionSet):
            // TODO: In the docs we're supposed to check doesFragmentTypeApply(objectType, namedType) but this requires
            // having possible types available. Since we already validate such notions in codegen and on the server
            // leaving that as a future enhancement.
            
            collectFields(objectType: objectType,
                          selectionSet: selectionSet.selections,
                          variableValues: variableValues,
                          visitedFragments: &visitedFragments,
                          into: &groupedFields,
                          from: originatingDocument)
        }
    }
}

/// Function correlates to DoesFragmentTypeApply(objectType, fragmentType)
/// https://facebook.github.io/graphql/June2018/#DoesFragmentTypeApply()
func doesFragmentTypeApply(objectType: String, fragmentTypePossibleTypes: [String]) -> Bool {
    return fragmentTypePossibleTypes.contains(objectType)
}
