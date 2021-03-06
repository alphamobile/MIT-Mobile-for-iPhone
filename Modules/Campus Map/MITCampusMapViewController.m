#import "MITCampusMapViewController.h"
#import "MITAdditions.h"
#import "MITMapModel.h"

#import "MITCoreData.h"
#import "MITAdditions.h"

#import "MGSMapView.h"
#import "MGSLayer.h"
#import "MITModule.h"

#import "MITMapCategoriesViewController.h"
#import "MITMapBookmarksViewController.h"
#import "MITMapDetailViewController.h"
#import "MITNavigationController.h"

static NSString* const MITCampusMapReuseIdentifierSearchCell = @"MITCampusMapReuseIdentifierSearchCell";

// Used in the updateToolbarItems: method to determine
// the sorted order of the bar items. The starting value
// was picked at random and has no significance.
typedef NS_ENUM(NSInteger, MITCampusMapItemTag) {
    MITCampusMapItemTagGeotrackingItem = 0xFF00,
    MITCampusMapItemTagFavoritesItem,
    MITCampusMapItemTagBrowseItem
};

@interface MITCampusMapViewController () <UISearchDisplayDelegate, UISearchBarDelegate,
                                            UITableViewDataSource, UITableViewDelegate,
                                            MGSMapViewDelegate, MITMapCategoriesDelegate,
                                            MITMapPlaceSelectionDelegate>
@property (nonatomic,weak) IBOutlet UISearchBar *searchBar;
@property (nonatomic,weak) IBOutlet MGSMapView *mapView;
@property (nonatomic,strong) IBOutlet UISearchDisplayController *searchController;

@property (nonatomic,strong) NSManagedObjectContext *managedObjectContext;
@property (nonatomic,copy) NSArray *recentSearches;
@property (nonatomic,copy) NSArray *selectedPlaces;

@property (nonatomic,getter = isSearching) BOOL searching;
@property (nonatomic,getter = isShowingList) BOOL showingList;
@property (nonatomic,getter = isGeotrackingEnabled) BOOL geotrackingEnabled;
@property (nonatomic,getter = isInterfaceHidden) BOOL interfaceHidden;


- (void)setInterfaceHidden:(BOOL)interfaceHidden animated:(BOOL)animated;
@end

@implementation MITCampusMapViewController {
    NSString* _pendingSearchQuery;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {

    }

    return self;
}

- (BOOL)hidesBottomBarWhenPushed
{
    return NO;
}

- (void)loadView
{
    UIView *controllerView = [[UIView alloc] init];
    controllerView.backgroundColor = [UIColor mit_backgroundColor];
    self.view = controllerView;

    MGSMapView *mapView = [[MGSMapView alloc] init];
    mapView.delegate = self;
    mapView.translatesAutoresizingMaskIntoConstraints = NO;
    [controllerView addSubview:mapView];
    self.mapView = mapView;

    UISearchBar *searchBar = [[UISearchBar alloc] init];
    searchBar.placeholder = @"Search MIT Campus";
    searchBar.translucent = YES;
    searchBar.delegate = self;
    searchBar.translatesAutoresizingMaskIntoConstraints = NO;
    [searchBar sizeToFit];
    
    if (NSFoundationVersionNumber <= NSFoundationVersionNumber_iOS_6_1) {
        searchBar.tintColor = [UIColor MITTintColor];
        self.navigationController.toolbar.barStyle = UIBarStyleBlack;
    }

    [controllerView addSubview:searchBar];
    self.searchBar = searchBar;

    NSDictionary *views = @{@"mapView" : mapView,
                            @"searchBar" : searchBar};

    // probably a more elegant way to do this, but it works for now
    [controllerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[mapView]|"
                                                                           options:0
                                                                           metrics:nil
                                                                             views:views]];

    [controllerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[mapView]|"
                                                                           options:0
                                                                           metrics:nil
                                                                             views:views]];

    [controllerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[searchBar]-(>=0)-|"
                                                                           options:0
                                                                           metrics:nil
                                                                             views:views]];

    [controllerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[searchBar]|"
                                                                           options:0
                                                                           metrics:nil
                                                                             views:views]];

    if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)]) {
        // Make sure that the map view extends all the way under the toolbar in
        // iOS 7
        self.edgesForExtendedLayout = UIRectEdgeBottom;
    }

    self.title = [[[MIT_MobileAppDelegate applicationDelegate] moduleForTag:CampusMapTag] longName];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    if (!self.interfaceHidden) {
        [self.navigationController setToolbarHidden:NO animated:animated];
    }

    [self updateToolbarItems:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    if (_pendingSearchQuery) {
        NSString *searchQuery = _pendingSearchQuery;
        _pendingSearchQuery = nil;

        self.searchBar.text = searchQuery;
        [[MITMapModelController sharedController] searchMapWithQuery:searchQuery
                                                              loaded:^(NSArray *objects, NSError *error) {
                                                                  if (!error) {
                                                                      self.selectedPlaces = objects;
                                                                  } else {
                                                                      DDLogVerbose(@"Failed to perform search '%@', %@",_pendingSearchQuery,error);
                                                                  }
                                                              }];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.navigationController setToolbarHidden:YES animated:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

#pragma mark - Search Handling
- (void)setSearching:(BOOL)searching
{
    [self setSearching:searching animated:NO];
}

- (void)setSearching:(BOOL)searching animated:(BOOL)animated
{
    if (_searching != searching) {
        _searching = searching;
        
        if (_searching) {
            if (!self.searchDisplayController) {
                UISearchDisplayController *searchController = [[UISearchDisplayController alloc] initWithSearchBar:self.searchBar
                                                                                                contentsController:self];
                searchController.delegate = self;
                searchController.searchResultsDataSource = self;
                searchController.searchResultsDelegate = self;
                self.searchController = searchController;
            }
            
            [self.searchController setActive:YES animated:animated];
        } else {
            [self.searchController setActive:NO animated:animated];
            self.recentSearches = nil;
        }
    }
}

#pragma mark - Browse Handling
- (IBAction)browseItemWasTapped:(UIBarButtonItem*)sender
{
    MITMapCategoriesViewController *categoryBrowseController = [[MITMapCategoriesViewController alloc] init];
    categoryBrowseController.delegate = self;

    UINavigationController *navigationController = [[MITNavigationController alloc] initWithRootViewController:categoryBrowseController];
    navigationController.navigationBarHidden = NO;
    [self presentViewController:navigationController
                       animated:YES
                     completion:nil];
}

- (IBAction)favoritesItemWasTapped:(UIBarButtonItem*)sender
{
    MITMapBookmarksViewController *bookmarksViewController = [[MITMapBookmarksViewController alloc] init];
    bookmarksViewController.delegate = self;

    UINavigationController *navigationController = [[MITNavigationController alloc] initWithRootViewController:bookmarksViewController];
    navigationController.navigationBarHidden = NO;
    [self presentViewController:navigationController
                       animated:YES
                     completion:nil];
}

- (IBAction)listItemWasTapped:(UIBarButtonItem*)sender
{
    
}

- (IBAction)geotrackingItemWasTapped:(UIBarButtonItem*)sender
{
    self.geotrackingEnabled = !self.isGeotrackingEnabled;
}

#pragma mark - Dynamic Properties
- (void)setPendingSearch:(NSString*)pendingSearch
{
    _pendingSearchQuery = pendingSearch;
}

- (BOOL)hasFavorites
{
    NSUInteger numberOfBookmarks = [[MITMapModelController sharedController] numberOfBookmarks];

    return ((numberOfBookmarks != NSNotFound) && (numberOfBookmarks > 0));
}

- (void)setSelectedPlaces:(NSOrderedSet *)selectedPlaces {
    [self setSelectedPlaces:selectedPlaces
                   animated:YES];
}

- (void)setSelectedPlaces:(NSOrderedSet *)selectedPlaces animated:(BOOL)animated
{
    _selectedPlaces = [selectedPlaces copy];
    [self didChangeSelectedPlaces:animated];
}

- (void)didChangeSelectedPlaces:(BOOL)animated
{
    // Update the map with the latest list of selectedPlaces
    [self.mapView defaultLayer].annotations = [NSOrderedSet orderedSetWithArray:self.selectedPlaces];

    if ([self.selectedPlaces count]) {
        self.mapView.mapRegion = MKCoordinateRegionForMGSAnnotations([NSSet setWithArray:self.selectedPlaces]);

        if ([self.selectedPlaces count] == 1) {
            [self.mapView showCalloutForAnnotation:self.selectedPlaces[0]];
        }

        // We don't have time to implement this right now.
//        UIBarButtonItem *listItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"map/item_list"]
//                                                                     style:UIBarButtonItemStylePlain
//                                                                    target:self
//                                                                    action:@selector(listItemWasTapped:)];
//        [self.navigationItem setRightBarButtonItem:listItem animated:animated];
    } else {
//        [self.navigationItem setRightBarButtonItem:nil animated:animated];
    }
}

- (void)setGeotrackingEnabled:(BOOL)geotrackingEnabled
{
    if (self.geotrackingEnabled != geotrackingEnabled) {
        _geotrackingEnabled = geotrackingEnabled;
        self.mapView.trackUserLocation = _geotrackingEnabled;

        [self updateToolbarItems:YES];
    }
}

- (void)setInterfaceHidden:(BOOL)interfaceHidden
{
    [self setInterfaceHidden:interfaceHidden animated:YES];
}

- (void)setInterfaceHidden:(BOOL)interfaceHidden animated:(BOOL)animated
{
    if (self.interfaceHidden != interfaceHidden) {
        _interfaceHidden = interfaceHidden;

        if (_interfaceHidden) {
            [UIView animateWithDuration:(animated ? 0.25 : 0.)
                                  delay:0
                                options:0
                             animations:^{
                                 self.searchBar.layer.affineTransform = CGAffineTransformMakeTranslation(0., -CGRectGetMaxY(self.searchBar.frame));

                                 [self.navigationController setToolbarHidden:YES
                                                                    animated:animated];

                             }
                             completion:^(BOOL finished) {
                                 self.searchBar.hidden = YES;
                             }];
        } else {
            [UIView animateWithDuration:(animated ? 0.20 : 0.)
                             animations:^{
                                 self.searchBar.hidden = NO;
                                 self.searchBar.layer.affineTransform = CGAffineTransformIdentity;
                                 [self.navigationController setToolbarHidden:NO
                                                                    animated:animated];
                             }];


        }
    }
}

// TODO: Think of alternate ways to do this. Maybe in viewWillAppear: instead?
// Potential issue: Assignment! If MOC is changed and either searchResults or
// selectedPlaces is set then ReallyBadThings may happen.
- (NSManagedObjectContext*)managedObjectContext
{
    if (!_managedObjectContext) {
        _managedObjectContext = [[MITCoreDataController defaultController] mainQueueContext];
    }

    return _managedObjectContext;
}

#pragma mark - UI State management
- (void)updateToolbarItems:(BOOL)animated
{
    NSMutableArray *toolbarItems = [[NSMutableArray alloc] init];

    NSString *geoFilledName = @"global/location_filled";
    NSString *geoEmptyName = @"global/location";
    NSString *favoritesName = @"global/star";
    if (NSFoundationVersionNumber <= NSFoundationVersionNumber_iOS_6_1) {
        geoFilledName = @"global/location_filled_iOS_6";
        geoEmptyName = @"global/location_iOS_6";
        favoritesName = @"global/star_iOS_6";
    }
    
    UIBarButtonItem *geotrackingItem = nil;
    if (self.isGeotrackingEnabled) {
        geotrackingItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:geoFilledName]
                                                           style:UIBarButtonItemStylePlain
                                                          target:self
                                                          action:@selector(geotrackingItemWasTapped:)];
    } else {
        geotrackingItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:geoEmptyName]
                                                           style:UIBarButtonItemStylePlain
                                                          target:self
                                                          action:@selector(geotrackingItemWasTapped:)];
    }
    geotrackingItem.tag = MITCampusMapItemTagGeotrackingItem;
    [toolbarItems addObject:geotrackingItem];

    UIBarButtonItem *favoritesItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:favoritesName]
                                                                      style:UIBarButtonItemStylePlain
                                                                     target:self
                                                                     action:@selector(favoritesItemWasTapped:)];
    favoritesItem.tag = MITCampusMapItemTagFavoritesItem;
    [toolbarItems addObject:favoritesItem];
    
    UIBarButtonItem *browseItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemBookmarks
                                                                                target:self
                                                                                action:@selector(browseItemWasTapped:)];
    browseItem.tag = MITCampusMapItemTagBrowseItem;
    [toolbarItems addObject:browseItem];
    
    // Sort the toolbar items into their proper order
    // This uses the assigned tags for the sorted order
    // of the items and then inserts spaces as needed between them
    [toolbarItems sortUsingComparator:^NSComparisonResult(UIView *view1, UIView *view2) {
        return [@(view1.tag) compare:@(view2.tag)];
    }];

    NSUInteger maxIndex = [toolbarItems count] - 1;
    [[toolbarItems copy] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if (idx < maxIndex) {
            [toolbarItems insertObject:[UIBarButtonItem flexibleSpace]
                               atIndex:((2 * idx) + 1)];
        }
    }];
    
    [toolbarItems insertObject:[UIBarButtonItem fixedSpaceWithWidth:20.] atIndex:0];
    [toolbarItems addObject:[UIBarButtonItem fixedSpaceWithWidth:20.]];

    [self setToolbarItems:toolbarItems
                 animated:animated];
}

#pragma mark - Delegate Methods
#pragma mark UISearchDisplayDelegate
- (void)searchDisplayController:(UISearchDisplayController *)controller didLoadSearchResultsTableView:(UITableView *)tableView
{
    [tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:MITCampusMapReuseIdentifierSearchCell];
}

- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString
{
    [[MITMapModelController sharedController] recentSearchesForPartialString:searchString
                                                                      loaded:^(NSFetchRequest *fetchRequest, NSDate *lastUpdated, NSError *error) {
                                                                          if (error) {
                                                                              self.recentSearches = nil;
                                                                          } else {
                                                                              [[MITCoreDataController defaultController] performBackgroundFetch:fetchRequest
                                                                                                                                     completion:^(NSOrderedSet *fetchedObjectIDs, NSError *error) {
                                                                                                                                         self.recentSearches = [self.managedObjectContext objectsWithIDs:[fetchedObjectIDs array]];
                                                                                                                                     }];
                                                                          }

                                                                          [controller.searchResultsTableView reloadData];
                                                                      }];

    return NO;
}

- (void)searchDisplayControllerDidEndSearch:(UISearchDisplayController *)controller
{
    [controller.searchBar resignFirstResponder];
    self.searching = NO;
}


#pragma mark UISearchBarDelegate
- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar
{
    [self setSearching:YES animated:YES];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    [[MITMapModelController sharedController] searchMapWithQuery:searchBar.text
                                                          loaded:^(NSArray *objects, NSError *error) {
                                                              if (!error) {
                                                                  self.selectedPlaces = objects;
                                                              } else {
                                                                  DDLogVerbose(@"Failed to perform search '%@', %@",searchBar.text,error);
                                                              }
                                                          }];
    [searchBar resignFirstResponder];
    [self setSearching:NO animated:YES];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    [self setSearching:NO animated:YES];
}


#pragma mark UITableViewDataSource
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if (self.searchDisplayController.searchResultsTableView == tableView) {
        if (self.recentSearches) {
            return 1;
        } else {
            return 0;
        }
    } else {
        return 0;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (self.searchDisplayController.searchResultsTableView == tableView) {
        return [self.recentSearches count];
    }
    
    return 0;
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSDateFormatter *cachedFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cachedFormatter = [[NSDateFormatter alloc] init];
        [cachedFormatter setDoesRelativeDateFormatting:YES];
        [cachedFormatter setTimeStyle:NSDateFormatterShortStyle];
        [cachedFormatter setDateStyle:NSDateFormatterMediumStyle];
    });

    if (self.searchDisplayController.searchResultsTableView == tableView) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:MITCampusMapReuseIdentifierSearchCell
                                                                forIndexPath:indexPath];
        
        MITMapSearch *search = self.recentSearches[indexPath.row];
        cell.textLabel.text = search.searchTerm;
        
        [cachedFormatter setDefaultDate:[NSDate date]];
        cell.detailTextLabel.text = [cachedFormatter stringFromDate:search.date];
        
        return cell;
    } else {
        return nil;
    }
}

#pragma mark UITableViewDelegate


#pragma mark MGSMapViewDelegate
- (void)mapView:(MGSMapView *)mapView userLocationUpdateFailedWithError:(NSError *)error
{
    self.geotrackingEnabled = NO;
}

- (void)mapView:(MGSMapView *)mapView didReceiveTapAtCoordinate:(CLLocationCoordinate2D)coordinate screenPoint:(CGPoint)screenPoint
{

}

- (void)mapView:(MGSMapView *)mapView calloutDidReceiveTapForAnnotation:(id<MGSAnnotation>)annotation
{
    MITMapPlace *tappedPlace = (MITMapPlace*)annotation;
    MITMapDetailViewController *detailController = [[MITMapDetailViewController alloc] initWithPlace:tappedPlace];

    [self.navigationController pushViewController:detailController animated:YES];
}

#pragma mark MITMapPlaceSelectionDelegate
- (void)placesController:(MITMapPlacesViewController *)controller didSelectPlaces:(NSArray *)objects
{
    self.selectedPlaces = objects;
    [self dismissViewControllerAnimated:YES completion:^{
        DDLogVerbose(@"'places' action completed with %d results", [objects count]);
    }];
}

- (void)placesControllerDidCancelSelection:(MITMapPlacesViewController *)controller
{
    [self dismissViewControllerAnimated:YES completion:^{
        DDLogVerbose(@"'places' action canceled by user");
    }];
}

#pragma mark MITMapCategoriesDelegate
- (void)controller:(MITMapCategoriesViewController *)controller didSelectCategory:(MITMapCategory *)category
{
    NSArray *sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"identifier" ascending:YES]];
    self.selectedPlaces = [[category.places allObjects] sortedArrayUsingDescriptors:sortDescriptors];
    [self dismissViewControllerAnimated:YES completion:^{
        DDLogVerbose(@"'browse' action completed with category '%@'",category.name);
    }];
}

- (void)controller:(MITMapCategoriesViewController *)controller didSelectObjects:(NSArray *)objects inCategory:(MITMapCategory *)category
{
    self.selectedPlaces = objects;
    [self dismissViewControllerAnimated:YES completion:^{
        DDLogVerbose(@"'browse' action completed with %d results in category '%@'",[objects count],category.name);
    }];
}

- (void)controllerDidCancelSelection:(MITMapCategoriesViewController *)controller
{
    [self dismissViewControllerAnimated:YES completion:^{
        DDLogVerbose(@"'browse' action canceled by user");
    }];
}

@end
