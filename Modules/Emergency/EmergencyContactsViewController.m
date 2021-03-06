#import "EmergencyContactsViewController.h"
#import "MIT_MobileAppDelegate.h"
#import "UIKit+MITAdditions.h"
#import "EmergencyData.h"
#import "MITModule.h"

@interface EmergencyContactsViewController ()
- (NSString *)detailText:(NSManagedObject*)contactInfo;
@end

@implementation EmergencyContactsViewController

- (id)init
{
    return [self initWithStyle:UITableViewStylePlain];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    if (NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_6_1) {
        self.tableView.backgroundColor = [UIColor groupTableViewBackgroundColor];
    } else {
        self.tableView.backgroundColor = [UIColor whiteColor];
    }
    self.tableView.backgroundView = nil;
}

- (void)viewWillAppear:(BOOL)animated {
	self.emergencyContacts = [[EmergencyData sharedData] allPhoneNumbers];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(contactsDidLoad:) name:EmergencyContactsDidLoadNotification object:nil];
    
    if (!self.emergencyContacts) {
        [[EmergencyData sharedData] reloadContacts];
    }
	
	[MIT_MobileAppDelegate moduleForTag:EmergencyTag].currentPath = @"contacts";
}

- (void)viewWillDisappear:(BOOL)animated {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:EmergencyContactsDidLoadNotification object:nil];
}

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return MITCanAutorotateForOrientation(interfaceOrientation, [self supportedInterfaceOrientations]);
}

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

- (void)contactsDidLoad:(NSNotification *)aNotification {
    self.emergencyContacts = [[EmergencyData sharedData] allPhoneNumbers];
    [self.tableView reloadData];
}

#pragma mark Table view methods
// Do not delete this method. It is required by the MultiLineTableViewCell
// and will crash if it is removed.
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.emergencyContacts count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    // There's probably a better way to do this —
    // one that doesn't require hardcoding expected padding.
    
    // UITableViewCellStyleSubtitle layout differs between iOS 6 and 7
    static UIEdgeInsets labelInsets;
    if (NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_6_1) {
        labelInsets = UIEdgeInsetsMake(11., 15., 11., 34. + 2.);
    } else {
        labelInsets = UIEdgeInsetsMake(11., 10. + 10., 11., 10. + 39.);
    }
    
    NSManagedObject *contactInfo = self.emergencyContacts[indexPath.row];
    NSString *title = [contactInfo valueForKey:@"title"];
    NSString *detail = [self detailText:contactInfo];
    
    CGFloat availableWidth = CGRectGetWidth(UIEdgeInsetsInsetRect(tableView.bounds, labelInsets));
    CGSize titleSize = [title sizeWithFont:[UIFont systemFontOfSize:[UIFont buttonFontSize]] constrainedToSize:CGSizeMake(availableWidth, 2000) lineBreakMode:NSLineBreakByWordWrapping];
    
    CGSize detailSize = [detail sizeWithFont:[UIFont systemFontOfSize:[UIFont smallSystemFontSize]] constrainedToSize:CGSizeMake(availableWidth, 2000) lineBreakMode:NSLineBreakByTruncatingTail];
    
    return MAX(titleSize.height + detailSize.height + labelInsets.top + labelInsets.bottom, tableView.rowHeight);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
        cell.contentView.backgroundColor = [UIColor whiteColor];
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.accessoryView = [UIImageView accessoryViewWithMITType:MITAccessoryViewPhone];
        cell.textLabel.numberOfLines = 0;
        cell.detailTextLabel.numberOfLines = 0;
        cell.detailTextLabel.textColor = [UIColor darkGrayColor];
    }
    
    [self configureCell:cell
            atIndexPath:indexPath
           forTableView:tableView];

    return cell;
}

- (void)configureCell:(UITableViewCell*)cell atIndexPath:(NSIndexPath*)indexPath forTableView:(UITableView*)tableView
{
	NSManagedObject *contactInfo = self.emergencyContacts[indexPath.row];
	cell.textLabel.text = [contactInfo valueForKey:@"title"];
	cell.detailTextLabel.text = [self detailText:contactInfo];
}

- (NSString *)detailText:(NSManagedObject*)contactInfo {
	NSString *phoneString = [contactInfo valueForKey:@"phone"];
	phoneString = [NSString stringWithFormat:@"%@.%@.%@",
				   [phoneString substringToIndex:3], 
				   [phoneString substringWithRange:NSMakeRange(3, 3)], 
				   [phoneString substringFromIndex:6]];
	
    NSString *descriptionString = [contactInfo valueForKey:@"summary"];
    
	if ([descriptionString length]) {
		return [NSString stringWithFormat:@"%@ (%@)", descriptionString, phoneString];
	} else {
		return phoneString;
	}
}
	

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	
	NSDictionary *contactInfo = [self.emergencyContacts objectAtIndex:indexPath.row];
	
	// phone numbers that aren't purely numbers should be converted
	NSURL *phoneURL = [NSURL URLWithString:[NSString stringWithFormat:@"tel://%@", [contactInfo valueForKey:@"phone"]]];
	if ([[UIApplication sharedApplication] canOpenURL:phoneURL]) {
		[[UIApplication sharedApplication] openURL:phoneURL];
    }

    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}




@end

