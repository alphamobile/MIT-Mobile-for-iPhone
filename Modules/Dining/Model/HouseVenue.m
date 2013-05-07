#import "HouseVenue.h"
#import "VenueLocation.h"
#import "DiningDay.h"
#import "DiningMeal.h"
#import "CoreDataManager.h"

@implementation HouseVenue

@dynamic name;
@dynamic shortName;
@dynamic iconImage;
@dynamic iconURL;
@dynamic url;
@dynamic paymentMethods;
@dynamic menuDays;
@dynamic location;

+ (HouseVenue *)newVenueWithDictionary:(NSDictionary *)dict {
    HouseVenue *venue = [CoreDataManager insertNewObjectForEntityForName:@"HouseVenue"];
    
    venue.name = dict[@"name"];
    venue.shortName = dict[@"short_name"];
    venue.iconURL = dict[@"icon_url"];
    venue.url = dict[@"url"];

    venue.location = [VenueLocation newLocationWithDictionary:dict[@"location"]];

    NSMutableSet *paymentMethods = [NSMutableSet set];
    for (NSString *payment in dict[@"payment"]) {
        [paymentMethods addObject:payment];
    }
    venue.paymentMethods = paymentMethods;
    
    for (NSDictionary *dayDict in dict[@"meals_by_day"]) {
        DiningDay *day = [DiningDay newDayWithDictionary:dayDict];
        if (day) {
            [venue addMenuDaysObject:day];
        }
    }
    
    return venue;
}

- (BOOL)isOpenNow {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateStyle:NSDateFormatterShortStyle];
    [formatter setTimeZone:[NSTimeZone timeZoneWithName:@"America/New_York"]];
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *components = [calendar components:(NSHourCalendarUnit | NSMinuteCalendarUnit) fromDate:[NSDate date]];
    components.hour = 13;
    components.year = 2013;
    components.month = 5;
    components.day = 3;
    
    NSDate *date = [calendar dateFromComponents:components];
    DiningDay *today = [self dayForDate:date];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"startTime <= %@ AND endTime >= %@", date, date];
    
    return ([[[today.meals set] filteredSetUsingPredicate:predicate] count] > 0);
}

- (NSString *)hoursNow {
    // TODO: current startTime/endTime time range
    return @"Open until 11am";
    // next time range
    // return @"Closed until 5pm";
    // no more time ranges for today
    // return @"Closed";
    // closed with a message
    // return @"Closed for renovations"
}

- (NSString *)hoursToday {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateStyle:NSDateFormatterShortStyle];
    [formatter setTimeZone:[NSTimeZone timeZoneWithName:@"America/New_York"]];
    DiningDay *today = [self dayForDate:[formatter dateFromString:@"5/3/2013"]];
    return today.allHoursSummary;
    // TODO: or closed with a message
    // return @"Closed for renovations"
}

- (DiningDay *)dayForDate:(NSDate *)date {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *components = [calendar components:(NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit) fromDate:date];
    NSDate *dayDate = [calendar dateFromComponents:components];
    
    NSSet *matchingDays = [self.menuDays filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"date == %@", dayDate]];
    
    return [matchingDays anyObject];
}

- (NSString *)description {
    return [NSString stringWithFormat:
     @"name: %@ shortName: %@ payment: %@ url: %@ \n"
     , self.name, self.shortName, [[self.paymentMethods allObjects] componentsJoinedByString:@", "], self.url];
}

@end