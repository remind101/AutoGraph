#import "RLMArray+Utilities.h"

#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

@implementation RLMObject (Utilities)

+ (BOOL)isProperty:(NSString *)propertyName ofType:(Class)type
{
    NSString *typeString = NSStringFromClass(type);
    
    objc_property_t property = class_getProperty(self, [propertyName cStringUsingEncoding:NSUTF8StringEncoding]);
    if (property == nil)
    {
        // TODO: Return an error.
        NSAssert(NO, @"Attempting mapping to property '%@' that doesn't exist on class '%@'", propertyName, NSStringFromClass(self));
        return NO;
    }
    
    const char *attrsCString = property_getAttributes(property);
    
    NSString *attributeString = [NSString stringWithCString:attrsCString encoding:NSUTF8StringEncoding];
    if ([attributeString rangeOfString:typeString].location != NSNotFound)
    {
        return YES;
    }
    
    return NO;
}

+ (NSObject *)sanitizeValue:(id)value fromProperty:(NSString *)property realm:(RLMRealm *)realm
{
    if (![value isKindOfClass:[NSObject class]])
    {
        return value;
    }
    
    if (([self isProperty:property ofType:[NSNumber class]] && [value isKindOfClass:[NSString class]]) || [value isKindOfClass:[NSNumber class]])
    {
        RLMPropertyType type = [[[realm.schema schemaForClassName:NSStringFromClass(self)] objectForKeyedSubscript:property] type];
        switch (type)
        {
            case RLMPropertyTypeInt:
            {
                return @([value integerValue]);
            }
            case RLMPropertyTypeFloat:
            {
                return @([value floatValue]);
            }
            case RLMPropertyTypeDouble:
            {
                return @([value doubleValue]);
            }
            case RLMPropertyTypeBool:
            {
                return @([value boolValue]);
            }
            default:
            {
                // TODO: Return an error.
                NSAssert(NO, @"We should be handling all cases of number type coersion");
                return @([value integerValue]);
            }
        }
    }
    
    return value;
}

+ (nullable Class)getTypeOfProperty:(NSString *)propertyName
{
    objc_property_t property = class_getProperty(self, [propertyName cStringUsingEncoding:NSUTF8StringEncoding]);
    
    const char * type = property_getAttributes(property);
    
    NSString * typeString = [NSString stringWithUTF8String:type];
    NSArray * attributes = [typeString componentsSeparatedByString:@","];
    NSString * typeAttribute = [attributes objectAtIndex:0];
    NSString * propertyType = [typeAttribute substringFromIndex:1];
    const char * rawPropertyType = [propertyType UTF8String];
    
    if (strcmp(rawPropertyType, @encode(float)) == 0)
    {
        // float.
    }
    else if (strcmp(rawPropertyType, @encode(int)) == 0)
    {
        // int.
    }
    else if (strcmp(rawPropertyType, @encode(id)) == 0)
    {
        // Some sort of object.
    }
    else
    {
        // According to Apples Documentation you can determine the corresponding encoding values.
    }
    
    if ([typeAttribute hasPrefix:@"T@"])
    {
        // Turns @"NSDate" into NSDate.
        NSString * typeClassName = [typeAttribute substringWithRange:NSMakeRange(3, [typeAttribute length]-4)];
        Class typeClass = NSClassFromString(typeClassName);
        if (typeClass != nil)
        {
            return typeClass;
        }
    }
    
    return nil;
}

@end

@implementation RLMArray (Utilities)

- (void)addObjectNonGeneric:(RLMObject *)object
{
    [self addObject:object];
}

- (NSArray<RLMObject *> *)allObjects
{
    NSMutableArray *objects = [NSMutableArray array];
    
    for (NSUInteger i = 0; i < self.count; i++)
    {
        [objects addObject:[self objectAtIndex:i]];
    }
    
    return objects;
}

@end

NS_ASSUME_NONNULL_END
