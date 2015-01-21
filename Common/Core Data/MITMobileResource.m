#import <RestKit/RestKit.h>
#import "MITMobileResource.h"

static inline void MITMobileEnumerateRequestMethodsUsingBlock(RKRequestMethod method, void (^block)(RKRequestMethod method))
{
    NSCParameterAssert(block);

    NSArray *methods = @[@(RKRequestMethodGET),
                         @(RKRequestMethodPOST),
                         @(RKRequestMethodPUT),
                         @(RKRequestMethodDELETE),
                         @(RKRequestMethodHEAD),
                         @(RKRequestMethodPATCH),
                         @(RKRequestMethodOPTIONS)];
    [methods enumerateObjectsUsingBlock:^(NSNumber *requestMethod, NSUInteger idx, BOOL *stop) {
        RKRequestMethod desiredMethod = [requestMethod integerValue];

        if (desiredMethod & method) {
            block(desiredMethod);
        }
    }];
}

#pragma mark Private Classes
@interface MITMobileResourceMapping : NSObject
@property(nonatomic,copy) NSString *keyPath;
@property(nonatomic,strong) NSArray *mappings;
@property(nonatomic) RKRequestMethod requestMethod;

- (instancetype)initWithKeyPath:(NSString*)keyPath requestMethod:(RKRequestMethod)method;
- (void)addMapping:(RKMapping*)mapping;
- (void)enumerateMappingsUsingBlock:(void(^)(NSString *keyPath, RKMapping *mapping))block;
@end

#pragma mark -
@interface MITMobileResource ()
@property (nonatomic,strong) NSMutableArray *registeredMappings;
@end

@implementation MITMobileResource

+ (instancetype)resourceWithName:(NSString*)name
                     pathPattern:(NSString*)path
                                mapping:(RKMapping*)mapping
                                 method:(RKRequestMethod)method
{
    MITMobileResource *resource = [[MITMobileResource alloc] initWithName:name pathPattern:path];
    [resource addMapping:mapping
               atKeyPath:nil
        forRequestMethod:method];
    return resource;
}

- (instancetype)init
{
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:@"failed to call designated initializer. Invoke -initWithName:pathPattern: instead"
                                 userInfo:nil];
}

- (instancetype)initWithName:(NSString*)name pathPattern:(NSString *)pathPattern
{
    NSParameterAssert(pathPattern);

    self = [super init];
    if (self) {
        _pathPattern = [pathPattern copy];
        _name = [name copy];
    }

    return self;
}

- (NSMutableArray*)registeredMappings
{
    if (!_registeredMappings) {
        _registeredMappings = [[NSMutableArray alloc] init];
        [self loadMappings];
    }

    return _registeredMappings;
}

- (void)loadMappings
{
    return;
}

- (void)addMapping:(RKMapping*)mapping atKeyPath:(NSString*)keyPath forRequestMethod:(RKRequestMethod)method
{
    NSParameterAssert(mapping);

    MITMobileEnumerateRequestMethodsUsingBlock(method, ^(RKRequestMethod requestMethod) {
        MITMobileResourceMapping *resourceMapping = [self _resourceMappingForKeyPath:keyPath requestMethod:requestMethod];
        [resourceMapping addMapping:mapping];
    });
}

- (void)enumerateMappingsUsingBlock:(void (^)(NSString *keyPath, RKRequestMethod method, NSArray *mappings))block
{
    NSParameterAssert(block);

    [self.registeredMappings enumerateObjectsUsingBlock:^(MITMobileResourceMapping *mapping, NSUInteger idx, BOOL *stop) {
        block(mapping.keyPath,mapping.requestMethod,mapping.mappings);
    }];
}

- (void)enumerateMappingsForRequestMethod:(RKRequestMethod)method usingBlock:(void (^)(NSString *keyPath, RKMapping *mapping))block
{
    NSParameterAssert(block);

    MITMobileEnumerateRequestMethodsUsingBlock(method, ^(RKRequestMethod method) {
        [self.registeredMappings enumerateObjectsUsingBlock:^(MITMobileResourceMapping *resourceMapping, NSUInteger idx, BOOL *stop) {
            if (resourceMapping.requestMethod == method) {
                [resourceMapping enumerateMappingsUsingBlock:^(NSString *keyPath, RKMapping *mapping) {
                    block(keyPath,mapping);
                }];
            }
        }];
    });
}

- (MITMobileResourceMapping*)_resourceMappingForKeyPath:(NSString*)keyPath requestMethod:(RKRequestMethod)method
{
    __block MITMobileResourceMapping *resourceMapping = nil;
    [self.registeredMappings enumerateObjectsUsingBlock:^(MITMobileResourceMapping *mapping, NSUInteger idx, BOOL *stop) {
        if (mapping.requestMethod == method) {
            if ((mapping.keyPath == keyPath) || [mapping.keyPath isEqualToString:keyPath]) {
                resourceMapping = mapping;
                (*stop) = YES;
            }
        }
    }];

    if (!resourceMapping) {
        resourceMapping = [[MITMobileResourceMapping alloc] initWithKeyPath:keyPath requestMethod:method];
        [self.registeredMappings addObject:resourceMapping];
    }

    return resourceMapping;
}

- (RKRequestMethod)requestMethods
{
    __block RKRequestMethod methods = 0;
    [self.registeredMappings enumerateObjectsUsingBlock:^(MITMobileResourceMapping *resourceMapping, NSUInteger idx, BOOL *stop) {
        methods |= resourceMapping.requestMethod;
    }];

    return methods;
}


@end


@implementation MITMobileResourceMapping
- (instancetype)initWithKeyPath:(NSString*)keyPath requestMethod:(RKRequestMethod)method
{
    self = [super init];
    if (self) {
        _keyPath = [keyPath copy];
        _requestMethod = method;
    }

    return self;
}

- (void)addMapping:(RKMapping*)mapping
{
    NSParameterAssert(mapping);

    NSMutableArray *mappings = [NSMutableArray arrayWithArray:self.mappings];
    [mappings addObject:mapping];
    self.mappings = mappings;
}

- (void)enumerateMappingsUsingBlock:(void(^)(NSString *keyPath, RKMapping *mapping))block
{
    NSParameterAssert(block);

    [self.mappings enumerateObjectsUsingBlock:^(RKMapping *mapping, NSUInteger idx, BOOL *stop) {
        block(self.keyPath,mapping);
    }];
}

- (NSUInteger)hash {
    return [self.keyPath hash];
}

- (BOOL)isEqual:(id)object
{
    if ([super isEqual:object]) {
        return YES;
    } else if ([object isKindOfClass:[self class]]) {
        MITMobileResourceMapping *otherMapping = (MITMobileResourceMapping*)object;
        return [self isEqualToResourceMapping:otherMapping];
    } else {
        return NO;
    }
}

- (BOOL)isEqualToResourceMapping:(MITMobileResourceMapping*)otherMapping
{
    return ([self.keyPath isEqualToString:otherMapping.keyPath] &&
            [self.mappings isEqualToArray:otherMapping.mappings] &&
            self.requestMethod == otherMapping.requestMethod);
}

@end
