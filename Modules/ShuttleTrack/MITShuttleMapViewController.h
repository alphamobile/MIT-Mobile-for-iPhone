#import <UIKit/UIKit.h>

@class MITShuttleRoute;
@class MITShuttleStop;

@protocol MITShuttleMapViewControllerDelegate;

typedef enum {
    MITShuttleMapStateContracted = 0,
    MITShuttleMapStateContracting,
    MITShuttleMapStateExpanded,
    MITShuttleMapStateExpanding
} MITShuttleMapState;

@interface MITShuttleMapViewController : UIViewController

- (instancetype)initWithRoute:(MITShuttleRoute *)route;
- (void)setRoute:(MITShuttleRoute *)route stop:(MITShuttleStop *)stop;
- (void)routeUpdated;

@property (strong, nonatomic) MITShuttleRoute *route;
@property (strong, nonatomic) MITShuttleRoute *secondaryRoute;
@property (strong, nonatomic) MITShuttleStop *stop;
@property (nonatomic) MITShuttleMapState state;
@property (nonatomic, weak) id<MITShuttleMapViewControllerDelegate> delegate;

@end

@protocol MITShuttleMapViewControllerDelegate <NSObject>

@optional
- (void)shuttleMapViewControllerExitFullscreenButtonPressed:(MITShuttleMapViewController *)mapViewController;
- (void)shuttleMapViewController:(MITShuttleMapViewController *)mapViewController didSelectStop:(MITShuttleStop *)stop;
- (void)shuttleMapViewController:(MITShuttleMapViewController *)mapViewController didSelectRoute:(MITShuttleRoute *)route;

@end