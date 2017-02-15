#import <Realm/Realm.h>

NS_ASSUME_NONNULL_BEGIN

@interface RLMObject (Utilities)

+ (BOOL)isProperty:(NSString *)propertyName ofType:(Class)type;
+ (NSObject *)sanitizeValue:(id)value fromProperty:(NSString *)property realm:(RLMRealm *)realm;

+ (nullable Class)getTypeOfProperty:(NSString *)propertyName;

@end

@interface RLMArray (Utilities)

+ (instancetype)createInstanceWithClass:(Class)class;
- (void)addObjectNonGeneric:(RLMObject *)object;
- (nullable NSNumber *)indexOfObjectNonGeneric:(RLMObject *)object;

- (NSArray<__kindof RLMObject *> *)allObjects;

@end

NS_ASSUME_NONNULL_END
