#import "EmergencyModule.h"
#import "EmergencyViewController.h"
#import "EmergencyContactsViewController.h"
#import "MITUIConstants.h"
#import "EmergencyData.h"
#import "MITJSON.h"
#import "MIT_MobileAppDelegate.h"
#import "CoreDataManager.h"

static NSString* const MITEmergencyHTMLFormatString = @"<html>\n<head>\n<style type=\"text/css\" media=\"screen\">\nbody { margin: 0; padding: 0; font-family: \"Helvetica Neue\", Helvetica; font-size: 17px; }\n</style>\n</head>\n<body>\n%@\n</body>\n</html>";

typedef NS_ENUM(NSUInteger, MITEmergencyTableSection) {
    MITEmergencyTableSectionAlerts = 0,
    MITEmergencyTableSectionContacts,
    MITEmergencyTableSectionCount
};

@interface EmergencyViewController ()
@property (weak) UIWebView *infoWebView;

@property (nonatomic,copy) NSString *htmlString;
@property BOOL refreshButtonPressed;
@property UIEdgeInsets webViewInsets;
@end

@implementation EmergencyViewController
- (id)initWithStyle:(UITableViewStyle)style {
    self = [super initWithStyle:style];
    if (self) {
        self.title = @"Emergency Info";
        if (NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_6_1) {
            _webViewInsets = UIEdgeInsetsMake(15., 15., 5., 15.);
        } else {
            _webViewInsets = UIEdgeInsetsMake(10., 10., 0., 10.);
        }
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refreshInfo:)];
    if (NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_6_1) {
        self.tableView.backgroundColor = [UIColor groupTableViewBackgroundColor];
    } else {
        self.tableView.backgroundColor = [UIColor mit_backgroundColor];
    }
	self.tableView.backgroundView = nil;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // register for emergencydata notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(infoDidLoad:) name:EmergencyInfoDidLoadNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(infoDidFailToLoad:) name:EmergencyInfoDidFailToLoadNotification object:nil];

}

- (void)viewDidDisappear:(BOOL)animated
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:EmergencyInfoDidLoadNotification object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:EmergencyInfoDidFailToLoadNotification object:nil];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if ([[[EmergencyData sharedData] lastUpdated] compare:[NSDate distantPast]] == NSOrderedDescending) {
		[self infoDidLoad:nil];
	}
    
    [[EmergencyData sharedData] setLastRead:[NSDate date]];
	EmergencyModule *emergencyModule = (EmergencyModule *)[MIT_MobileAppDelegate moduleForTag:EmergencyTag];
	[emergencyModule syncUnreadNotifications];
	[emergencyModule resetURL];
}

- (void)setHtmlString:(NSString *)htmlString
{
    if (![_htmlString isEqualToString:htmlString]) {
        _htmlString = [htmlString copy];
        [self.infoWebView loadHTMLString:self.htmlString
                                 baseURL:nil];
    }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return MITCanAutorotateForOrientation(interfaceOrientation, [self supportedInterfaceOrientations]);
}

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

- (void)refreshInfo:(id)sender {
	self.refreshButtonPressed = (sender != nil);
    [[EmergencyData sharedData] checkForEmergencies];
}

#pragma mark - UIWebView delegation
- (void)webViewDidFinishLoad:(UIWebView *)webView {
    if ([self.infoWebView isEqual:webView]) {
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:MITEmergencyTableSectionAlerts]
                      withRowAnimation:UITableViewRowAnimationFade];
    }
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    UIApplication *application = [UIApplication sharedApplication];
    NSURL *url = [request URL];
    if ([application canOpenURL:url]) {
        [application openURL:url];
    } else if ([[[request URL] absoluteString] isEqualToString:@"about:blank"]) {
        return YES;
    }
    
    return NO;
}

#pragma mark - Table view methods
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return MITEmergencyTableSectionCount;
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case MITEmergencyTableSectionAlerts: {
            return 1;
        }
        case MITEmergencyTableSectionContacts: {
            NSArray *numbers = [[EmergencyData sharedData] primaryPhoneNumbers];
            return [numbers count] + 1;
        }
        default: {
            return 0;
        }
    }
    
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray *contacts = [[EmergencyData sharedData] primaryPhoneNumbers];
    if (indexPath.section == MITEmergencyTableSectionAlerts) {
        CGFloat height = self.infoWebView.scrollView.contentSize.height + self.webViewInsets.bottom + self.webViewInsets.top;
        return height;
    } else if (indexPath.section == MITEmergencyTableSectionContacts && indexPath.row < [contacts count]) {
        // There's probably a better way to do this —
        // one that doesn't require hardcoding expected padding.
        
        // UITableViewCellStyleSubtitle layout differs between iOS 6 and 7
        static UIEdgeInsets labelInsets;
        if (NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_6_1) {
            labelInsets = UIEdgeInsetsMake(11., 15., 11., 34. + 2.);
        } else {
            labelInsets = UIEdgeInsetsMake(11., 10. + 10., 11., 10. + 39.);
        }
        
        NSString *title = contacts[indexPath.row][@"title"];
        NSString *phone = contacts[indexPath.row][@"phone"];
        
        CGFloat availableWidth = CGRectGetWidth(UIEdgeInsetsInsetRect(tableView.bounds, labelInsets));
        CGSize titleSize = [title sizeWithFont:[UIFont systemFontOfSize:[UIFont buttonFontSize]] constrainedToSize:CGSizeMake(availableWidth, 2000) lineBreakMode:NSLineBreakByWordWrapping];
        
        CGSize phoneSize = [phone sizeWithFont:[UIFont systemFontOfSize:[UIFont smallSystemFontSize]] constrainedToSize:CGSizeMake(availableWidth, 2000) lineBreakMode:NSLineBreakByTruncatingTail];
        
        return MAX(titleSize.height + phoneSize.height + labelInsets.top + labelInsets.bottom, tableView.rowHeight);
    } else {
        return 44.;
    }
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *alertCellId = @"AlertCell";
    static NSString *contactCellId = @"ContactCell";
    
    if (indexPath.section == MITEmergencyTableSectionAlerts) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:alertCellId];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:alertCellId];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.contentView.autoresizesSubviews = YES;
            cell.contentView.clipsToBounds = YES;
            
            UIWebView *webView = [[UIWebView alloc] initWithFrame:UIEdgeInsetsInsetRect(cell.contentView.bounds, self.webViewInsets)];
            webView.autoresizingMask = (UIViewAutoresizingFlexibleHeight |
                                        UIViewAutoresizingFlexibleWidth);
            webView.backgroundColor = [UIColor clearColor];
            webView.dataDetectorTypes = UIDataDetectorTypeAll;
            webView.delegate = self;
            webView.opaque = NO;
            
            webView.scrollView.scrollEnabled = NO;
            webView.scrollView.showsHorizontalScrollIndicator = NO;
            webView.scrollView.showsVerticalScrollIndicator = NO;
            webView.userInteractionEnabled = NO;
            [cell.contentView addSubview:webView];
            self.infoWebView = webView;

            if ([self.htmlString length]) {
                NSString *htmlString = self.htmlString;
                [webView loadHTMLString:htmlString
                                baseURL:nil];
            }
        }
        
        
        return cell;
    } else if (indexPath.section == MITEmergencyTableSectionContacts) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:contactCellId];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                          reuseIdentifier:contactCellId];
            cell.textLabel.numberOfLines = 0;
            cell.detailTextLabel.numberOfLines = 0;
            cell.detailTextLabel.textColor = [UIColor darkGrayColor];
        }
        
        NSArray *contacts = [[EmergencyData sharedData] primaryPhoneNumbers];
        if (indexPath.row < [contacts count]) {
            NSDictionary *contact = contacts[indexPath.row];
            cell.accessoryView = [UIImageView accessoryViewWithMITType:MITAccessoryViewPhone];
            cell.textLabel.text = contact[@"title"];
            cell.detailTextLabel.text = contact[@"phone"];
        } else {
            cell.textLabel.text = @"More Emergency Contacts";
            cell.detailTextLabel.text = nil;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
        
        return cell;
    }
    
	return nil;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == MITEmergencyTableSectionContacts) {
        NSArray *contacts = [[EmergencyData sharedData] primaryPhoneNumbers];
        if (indexPath.row < [contacts count]) {
            NSDictionary *contact = contacts[indexPath.row];
            NSURL *phoneURL = [NSURL URLWithString:[NSString stringWithFormat:@"tel://%@", contact[@"phone"]]];
            
            if ([[UIApplication sharedApplication] canOpenURL:phoneURL]) {
                [[UIApplication sharedApplication] openURL:phoneURL];
            }
            
            [tableView deselectRowAtIndexPath:indexPath
                                     animated:YES];
        } else {
            EmergencyContactsViewController *contactsVC = [[EmergencyContactsViewController alloc] init];
            [self.navigationController pushViewController:contactsVC animated:YES];
            
        }
    }
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == MITEmergencyTableSectionAlerts) {
        return nil;
    }
    
    return indexPath;
}


#pragma mark - Emergency Info Data Delegate
- (void)infoDidLoad:(NSNotification *)aNotification {
	self.refreshButtonPressed = NO;
    
    self.htmlString = [[EmergencyData sharedData] htmlString];
    
    if (self.navigationController.visibleViewController == self) {
        [[EmergencyData sharedData] setLastRead:[NSDate date]];
        EmergencyModule *emergencyModule = (EmergencyModule *)[MIT_MobileAppDelegate moduleForTag:EmergencyTag];
        [emergencyModule syncUnreadNotifications];
    }
}

- (void)infoDidFailToLoad:(NSNotification *)aNotification {
	if ([[EmergencyData sharedData] hasNeverLoaded]) {
		// Since emergency has never loaded successfully report failure
		self.htmlString = [NSString stringWithFormat:MITEmergencyHTMLFormatString, @"Failed to load notice."];
	}
	
	if (self.refreshButtonPressed) {
		UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Connection Failed"
                                                            message:@"Failed to load notice from server."
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
		[alertView show];
	}
	
	// touch handled
	self.refreshButtonPressed = NO;
}

@end

