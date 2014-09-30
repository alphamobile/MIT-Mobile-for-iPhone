#import <Foundation/Foundation.h>
#import "MITMappedObject.h"

@class MITLibrariesDate;

@interface MITLibrariesTerm : NSObject <MITMappedObject>

@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) MITLibrariesDate *dates;

@property (nonatomic, strong) NSArray *regularTerm;
@property (nonatomic, strong) NSArray *closingsTerm;
@property (nonatomic, strong) NSArray *exceptionsTerm;

- (BOOL)dateFallsInTerm:(NSDate *)date;
- (NSString *)hoursStringForDate:(NSDate *)date;
- (BOOL)isOpenAtDate:(NSDate *)date;

@end
