#import "MITDiningHomeContainerViewControllerPad.h"
#import "UIKit+MITAdditions.h"
#import "MITDiningLinksTableViewController.h"
#import "MITSingleWebViewCellTableViewController.h"
#import "MITDiningDining.h"
#import "MITCoreData.h"
#import "MITDiningHouseHomeViewControllerPad.h"
#import "MITDiningRetailHomeViewControllerPad.h"
#import "MITDiningWebservices.h"
#import "MITDiningVenues.h"
#import "MITDiningFilterViewController.h"

@interface MITDiningHomeContainerViewControllerPad () <NSFetchedResultsControllerDelegate, MITDiningFilterDelegate>

@property (nonatomic, strong) NSFetchedResultsController *fetchedResultsController;
@property (nonatomic, strong) MITDiningDining *diningData;
@property (nonatomic, strong) UISegmentedControl *diningVenueTypeControl;
@property (nonatomic, strong) UIPopoverController *announcementsPopoverController;
@property (nonatomic, strong) UIPopoverController *linksPopoverController;
@property (nonatomic, strong) UIPopoverController *filtersPopoverController;
@property (nonatomic, strong) UIBarButtonItem *announcementsBarButton;
@property (nonatomic, strong) UIBarButtonItem *linksBarButton;
@property (nonatomic, strong) UIBarButtonItem *filtersBarButton;

@property (nonatomic, strong) IBOutlet UIView *containerView;
@property (nonatomic, strong) MITDiningHouseHomeViewControllerPad *diningHouseViewController;
@property (nonatomic, strong) MITDiningRetailHomeViewControllerPad *diningRetailViewController;

@end

@implementation MITDiningHomeContainerViewControllerPad

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    [self setupNavBar];
    [self setupToolbar];
    [self setupDiningHouseViewController];
    [self setupDiningRetailViewController];
    [self showDiningHouseViewController];
    
    [self setupFetchedResultsController];
    [MITDiningWebservices getDiningWithCompletion:NULL];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)setupNavBar
{
    self.navigationController.navigationBar.translucent = NO;
    
    [self.navigationController.navigationBar setShadowImage:[UIImage imageNamed:@"global/TransparentPixel"]];
    NSLog(@"navbar bg: %@", self.navigationController.navigationBar.backgroundColor);
    NSLog(@"mit bg: %@", [UIColor mit_backgroundColor]);
    
    CGRect rect = CGRectMake(0.0f, 0.0f, 1.0f, 1.0f);
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSetFillColorWithColor(context, [[UIColor whiteColor] CGColor]);
    CGContextFillRect(context, rect);
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    [self.navigationController.navigationBar setBackgroundImage:image forBarMetrics:UIBarMetricsDefault];
    
    self.diningVenueTypeControl = [[UISegmentedControl alloc] initWithItems:@[@"Dining Halls", @"Other"]];
    [self.diningVenueTypeControl setSelectedSegmentIndex:0];
    [self.diningVenueTypeControl addTarget:self action:@selector(diningSegmentedControlChanged) forControlEvents:UIControlEventValueChanged];
    self.navigationItem.titleView = self.diningVenueTypeControl;
}

- (void)setupToolbar
{
    self.navigationController.toolbar.translucent = NO;
    self.announcementsBarButton = [[UIBarButtonItem alloc] initWithTitle:@"Announcements" style:UIBarButtonItemStylePlain target:self action:@selector(announcementsButtonPressed:)];
    self.linksBarButton = [[UIBarButtonItem alloc] initWithTitle:@"Links" style:UIBarButtonItemStylePlain target:self action:@selector(linksButtonPressed:)];
    self.filtersBarButton = [[UIBarButtonItem alloc] initWithTitle:@"Filters" style:UIBarButtonItemStylePlain target:self action:@selector(filtersButtonPressed:)];
    
    CGSize announcementsSize = [self.announcementsBarButton.title sizeWithAttributes:[self.announcementsBarButton titleTextAttributesForState:UIControlStateNormal]];
    CGSize filtersSize = [self.filtersBarButton.title sizeWithAttributes:[self.announcementsBarButton titleTextAttributesForState:UIControlStateNormal]];
    
    UIBarButtonItem *evenPaddingButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    evenPaddingButton.width = announcementsSize.width - filtersSize.width;
    
    self.toolbarItems = @[self.announcementsBarButton,
                          [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
                          self.linksBarButton,
                          [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
                          evenPaddingButton,
                          self.filtersBarButton];
}

- (void)setupDiningHouseViewController
{
    self.diningHouseViewController = [[MITDiningHouseHomeViewControllerPad alloc] initWithNibName:nil bundle:nil];
}

- (void)setupDiningRetailViewController
{
    self.diningRetailViewController = [[MITDiningRetailHomeViewControllerPad alloc] initWithNibName:nil bundle:nil];
}

- (void)showDiningHouseViewController
{
    [self.diningRetailViewController.view removeFromSuperview];
    [self.diningRetailViewController removeFromParentViewController];
    
    [self addChildViewController:self.diningHouseViewController];
    self.diningHouseViewController.view.frame = self.containerView.bounds;
    self.diningHouseViewController.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.containerView addSubview:self.diningHouseViewController.view];
    [self.diningHouseViewController didMoveToParentViewController:self];
    
    [self.containerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-0-[houseView]-0-|" options:0 metrics:nil views:@{@"houseView": self.diningHouseViewController.view}]];
    [self.containerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-0-[houseView]-0-|" options:0 metrics:nil views:@{@"houseView": self.diningHouseViewController.view}]];
}

- (void)showDiningRetailViewController
{
    [self.diningHouseViewController.view removeFromSuperview];
    [self.diningHouseViewController removeFromParentViewController];
    
    [self addChildViewController:self.diningRetailViewController];
    self.diningRetailViewController.view.frame = self.containerView.bounds;
    self.diningRetailViewController.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.containerView addSubview:self.diningRetailViewController.view];
    [self.diningRetailViewController didMoveToParentViewController:self];
    
    [self.containerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-0-[retailView]-0-|" options:0 metrics:nil views:@{@"retailView": self.diningRetailViewController.view}]];
    [self.containerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-0-[retailView]-0-|" options:0 metrics:nil views:@{@"retailView": self.diningRetailViewController.view}]];
}

- (void)diningSegmentedControlChanged
{
    switch (self.diningVenueTypeControl.selectedSegmentIndex) {
        case 0: {
            [self showDiningHouseViewController];
            break;
        }
        case 1: {
            [self showDiningRetailViewController];
            break;
        }
    }
}

#pragma mark - Toolbar Button Actions

- (void)announcementsButtonPressed:(id)sender
{
    MITSingleWebViewCellTableViewController *vc = [[MITSingleWebViewCellTableViewController alloc] init];
    vc.title = @"Announcements";
    vc.webViewInsets = UIEdgeInsetsMake(10, 0, 10, 10);
    vc.htmlContent = self.diningData.announcementsHTML;
    
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:vc];
    
    self.announcementsPopoverController = [[UIPopoverController alloc] initWithContentViewController:navController];
    [self.announcementsPopoverController presentPopoverFromBarButtonItem:self.announcementsBarButton permittedArrowDirections:UIPopoverArrowDirectionDown animated:YES];
}

- (void)linksButtonPressed:(id)sender
{
    MITDiningLinksTableViewController *vc = [[MITDiningLinksTableViewController alloc] init];
    vc.diningLinks = [self.diningData.links array];
    vc.title = @"Links";
    
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:vc];
    
    self.linksPopoverController = [[UIPopoverController alloc] initWithContentViewController:navController];
    [self.linksPopoverController presentPopoverFromBarButtonItem:self.linksBarButton permittedArrowDirections:UIPopoverArrowDirectionDown animated:YES];
}

- (void)filtersButtonPressed:(id)sender
{
    MITDiningFilterViewController *filterVC = [[MITDiningFilterViewController alloc] init];
    NSSet *filtersSet = [NSSet setWithArray:self.diningHouseViewController.dietaryFlagFilters];
    [filterVC setSelectedFilters:filtersSet];
    filterVC.delegate = self;
    
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:filterVC];
    
    self.filtersPopoverController = [[UIPopoverController alloc] initWithContentViewController:navController];
    [self.filtersPopoverController setPopoverContentSize:CGSizeMake(320, [filterVC targetTableViewHeight] + navController.navigationBar.frame.size.height)];
    [self.filtersPopoverController presentPopoverFromBarButtonItem:self.filtersBarButton permittedArrowDirections:UIPopoverArrowDirectionDown animated:YES];
}

#pragma mark - MITDiningFilterDelegate Methods

- (void)applyFilters:(NSSet *)filters
{
    [self.diningHouseViewController setDietaryFlagFilters:[filters allObjects]];
}

#pragma mark - Fetched Results Controller

- (void)setupFetchedResultsController
{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"MITDiningDining"
                                              inManagedObjectContext:[[MITCoreDataController defaultController] mainQueueContext]];
    [fetchRequest setEntity:entity];
    
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"url"
                                                                   ascending:YES];
    [fetchRequest setSortDescriptors:@[sortDescriptor]];
    
    NSFetchedResultsController *fetchedResultsController =
    [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                        managedObjectContext:[[MITCoreDataController defaultController] mainQueueContext]
                                          sectionNameKeyPath:nil
                                                   cacheName:nil];
    self.fetchedResultsController = fetchedResultsController;
    _fetchedResultsController.delegate = self;
    
    [self.fetchedResultsController performFetch:nil];
    if (self.fetchedResultsController.fetchedObjects.count > 0) {
        self.diningData = self.fetchedResultsController.fetchedObjects[0];
        self.diningHouseViewController.diningHouses = [self.diningData.venues.house array];
        self.diningRetailViewController.retailVenues = [self.diningData.venues.retail array];
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    if (self.fetchedResultsController.fetchedObjects.count > 0) {
        self.diningData = self.fetchedResultsController.fetchedObjects[0];
        self.diningHouseViewController.diningHouses = [self.diningData.venues.house array];
        self.diningRetailViewController.retailVenues = [self.diningData.venues.retail array];
    }
}

@end