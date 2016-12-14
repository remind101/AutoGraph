#import <Foundation/Foundation.h>
#import <Realm/Realm.h>


NS_ASSUME_NONNULL_BEGIN

@interface Film : RLMObject

@property (nullable) NSString *remoteId;
@property (nullable) NSString *title;
@property (nullable) NSNumber<RLMInt> *episode;
@property (nullable) NSString *openingCrawl;
@property (nullable) NSString *director;

@end

NS_ASSUME_NONNULL_END
