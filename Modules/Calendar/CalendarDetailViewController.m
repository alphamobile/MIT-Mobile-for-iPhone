#import "CalendarDetailViewController.h"
#import "MITCalendarEvent.h"
#import "EventCategory.h"
#import "MITUIConstants.h"
#import "MultiLineTableViewCell.h"
#import "Foundation+MITAdditions.h"
#import "URLShortener.h"
#import "CalendarDataManager.h"
#import <EventKit/EventKit.h>
#import "MobileRequestOperation.h"

#define kCategoriesWebViewTag 521
#define kDescriptionWebViewTag 516

@interface CalendarDetailViewController ()
@property (nonatomic,strong) UISegmentedControl *eventPager;
@property (nonatomic,getter=isLoading) BOOL loading;
@property (nonatomic,strong) NSArray *rowTypes;
@property (nonatomic,strong) NSString *descriptionString;
@property (nonatomic,strong) NSString *categoriesString;
@property (nonatomic) CGFloat descriptionHeight;
@property (nonatomic) CGFloat categoriesHeight;

- (void)presentEditorForEvent:(MITCalendarEvent*)calendarEvent
                    withNotes:(NSString*)notes
              usingEventStore:(EKEventStore*)eventStore;

@end

@implementation CalendarDetailViewController
- (void)loadView
{
    CGRect mainFrame = [[UIScreen mainScreen] applicationFrame];
    
    if (self.navigationController && (self.navigationController.navigationBarHidden == NO))
    {
        CGFloat navBarHeight = CGRectGetHeight(self.navigationController.navigationBar.frame);
        mainFrame.origin.y += navBarHeight;
        mainFrame.size.height -= navBarHeight;
    }
    
    
    UIView *mainView = [[UIView alloc] initWithFrame:mainFrame];
    CGRect mainBounds = mainView.bounds;
    
    {
        CGRect tableViewFrame = CGRectMake(CGRectGetMinX(mainBounds),
                                           CGRectGetMinY(mainBounds),
                                           CGRectGetWidth(mainBounds),
                                           CGRectGetHeight(mainBounds));
        
        UITableView *tableView = [[UITableView alloc] initWithFrame:tableViewFrame
                                                              style:UITableViewStylePlain];
        tableView.delegate = self;
        tableView.dataSource = self;
        tableView.autoresizingMask = (UIViewAutoresizingFlexibleHeight |
                                      UIViewAutoresizingFlexibleWidth);
        
        self.tableView = tableView;
        [mainView addSubview:tableView];
    }
    
    self.view = mainView;
}

- (void)viewDidLoad {
    [super viewDidLoad];
	
	self.shareDelegate = self;
	
	// setup nav bar
	if ([self.events count] > 1) {
        UIBarButtonItem *shareItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(share:)];
		self.navigationItem.rightBarButtonItem = shareItem;
	}
    
	self.descriptionString = nil;
    self.categoriesString = nil;
	
	// set up table rows
	[self reloadEvent];
    if ([self.event hasMoreDetails] && [self.event.summary length] == 0) {
        [self requestEventDetails];
    }
	
	self.descriptionHeight = 0;
}

- (void)showNextEvent:(id)sender
{
	if ([sender isKindOfClass:[UISegmentedControl class]]) {
        NSInteger i = self.eventPager.selectedSegmentIndex;
		NSInteger currentEventIndex = [self.events indexOfObject:self.event];
		if (i == 0) { // previous
            if (currentEventIndex > 0) {
                currentEventIndex--;
            }
		} else {
            NSInteger maxIndex = [self.events count] - 1;
            if (currentEventIndex < maxIndex) {
                currentEventIndex++;
            }
		}
		self.event = self.events[currentEventIndex];
		[self reloadEvent];
        if ([self.event hasMoreDetails] && [self.event.summary length] == 0) {
            [self requestEventDetails];
        }
    }
}

- (void)requestEventDetails
{
    if (self.isLoading) {
        return;
    }

    MobileRequestOperation *request = [[MobileRequestOperation alloc] initWithModule:CalendarTag
                                                                             command:@"detail"
                                                                          parameters:@{@"id" : [self.event.eventID description]}];

    request.completeBlock = ^(MobileRequestOperation *operation, id jsonResult, NSString *contentType, NSError *error) {
        self.loading = NO;
        
        if (error) {
            DDLogVerbose(@"Calendar 'detail' request failed: %@",error);
        } else {
            if ([jsonResult isKindOfClass:[NSDictionary class]]) {
                if ([jsonResult[@"id"] integerValue] == [self.event.eventID integerValue]) {
                    [self.event updateWithDict:jsonResult];
                    [self reloadEvent];
                }
            }
        }
    };

    self.loading = YES;
    [[MobileRequestOperation defaultQueue] addOperation:request];
}

- (void)reloadEvent
{
	[self setupHeader];
    
    if ([self.events count] > 1) {
        NSInteger currentEventIndex = [self.events indexOfObject:self.event];
        [self.eventPager setEnabled:(currentEventIndex > 0) forSegmentAtIndex:0];
        [self.eventPager setEnabled:(currentEventIndex < [self.events count] - 1) forSegmentAtIndex:1];
    }
	
    NSMutableArray *rowTypes = [NSMutableArray array];
    
	if (self.event.start) {
		[rowTypes addObject:@(CalendarDetailRowTypeTime)];
	}
    
	if (self.event.shortloc || self.event.location) {
		[rowTypes addObject:@(CalendarDetailRowTypeLocation)];
	}

	if (self.event.phone) {
		[rowTypes addObject:@(CalendarDetailRowTypePhone)];
	}
    
	if (self.event.url) {
		[rowTypes addObject:@(CalendarDetailRowTypeURL)];
	}
    
	if (self.event.summary.length) {
		[rowTypes addObject:@(CalendarDetailRowTypeDescription)];
        self.descriptionString = [self htmlStringFromString:self.event.summary];
	}
    
	if ([self.event.categories count] > 0) {
		[rowTypes addObject:@(CalendarDetailRowTypeCategories)];
        
        NSMutableString *categoriesBody = [NSMutableString stringWithString:@"Categorized as:<ul>"];
        for (EventCategory *category in self.event.categories) {
            NSString *catIDString = [NSString stringWithFormat:@"catID=%d", [category.catID intValue]];
            if(category.listID) {
                catIDString = [catIDString stringByAppendingFormat:@"&listID=%@", category.listID];
            }
            NSURL *categoryURL = [NSURL internalURLWithModuleTag:CalendarTag
                                                            path:CalendarStateCategoryEventList
                                                           query:catIDString];
            [categoriesBody appendString:[NSString stringWithFormat:
                                          @"<li><a href=\"%@\">%@</a></li>", [categoryURL absoluteString], category.title]];
        }
        
        [categoriesBody appendString:@"</ul>"];
        self.categoriesString = [self htmlStringFromString:categoriesBody];
        
        UIFont *cellFont = [UIFont systemFontOfSize:CELL_STANDARD_FONT_SIZE];
        CGSize textSize = [CalendarTag sizeWithFont:cellFont];
        // one line height per category, +1 each for "Categorized as" and <ul> spacing, 5px between lines
        self.categoriesHeight = (textSize.height + 5.0) * ([self.event.categories count] + 2);
	}
    
	self.rowTypes = rowTypes;
	[self.tableView reloadData];
}

- (void)setupHeader {	
	CGRect tableFrame = self.tableView.frame;
	
	CGFloat titlePadding = (NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_6_1) ? 15. : 10.;
    CGFloat titleWidth;
    titleWidth = tableFrame.size.width - titlePadding * 2;
	UIFont *titleFont = [UIFont boldSystemFontOfSize:20.0];
	CGSize titleSize = [self.event.title sizeWithFont:titleFont
									constrainedToSize:CGSizeMake(titleWidth, 2010.0)];
	UILabel *titleView = [[UILabel alloc] initWithFrame:CGRectMake(titlePadding, titlePadding, titleSize.width, titleSize.height)];
	titleView.lineBreakMode = NSLineBreakByWordWrapping;
	titleView.numberOfLines = 0;
	titleView.font = titleFont;
	titleView.text = self.event.title;
	
	CGRect titleFrame = CGRectMake(0.0, 0.0, tableFrame.size.width, titleSize.height + titlePadding * 2);
	self.tableView.tableHeaderView = [[UIView alloc] initWithFrame:titleFrame];
	[self.tableView.tableHeaderView addSubview:titleView];
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

- (UIInterfaceOrientation) preferredInterfaceOrientationForPresentation
{
    return UIInterfaceOrientationPortrait;
}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)setEvent:(MITCalendarEvent *)anEvent {
	if ([self.event isEqual:anEvent] == NO) {
        _event = anEvent;
        
        self.descriptionString = nil;
        self.categoriesString = nil;
    }
    
    

}

#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [self.rowTypes count];
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
	NSInteger rowType = [self.rowTypes[indexPath.row] integerValue];
	NSString *CellIdentifier = [NSString stringWithFormat:@"%d", rowType];

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        if (rowType == CalendarDetailRowTypeCategories || rowType == CalendarDetailRowTypeDescription) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
			cell.selectionStyle = UITableViewCellSelectionStyleNone;
        } else {
            cell = [[MultiLineTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
        }
    }
    
	[cell applyStandardFonts];
	
    CGFloat webHorizontalPadding = (NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_6_1) ? 15. : 10.;
    CGFloat webVerticalPadding = 10.;
    
	switch (rowType) {
		case CalendarDetailRowTypeTime:
			cell.textLabel.text = 
            [self.event dateStringWithDateStyle:NSDateFormatterFullStyle 
                                 timeStyle:NSDateFormatterShortStyle 
                                 separator:@"\n"];
            cell.accessoryView = 
            [UIImageView accessoryViewWithMITType:MITAccessoryViewCalendar];
			break;
		case CalendarDetailRowTypeLocation:
			cell.textLabel.text = (self.event.location != nil) ? self.event.location : self.event.shortloc;
            cell.accessoryView = [UIImageView accessoryViewWithMITType:MITAccessoryViewMap];
			if (![self.event hasCoords]) {
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
				cell.accessoryView.hidden = YES;
            }
			break;
		case CalendarDetailRowTypePhone:
			cell.textLabel.text = self.event.phone;
			cell.accessoryView = [UIImageView accessoryViewWithMITType:MITAccessoryViewPhone];			
			break;
		case CalendarDetailRowTypeURL:
			cell.textLabel.text = self.event.url;
			cell.textLabel.font = [UIFont systemFontOfSize:CELL_STANDARD_FONT_SIZE];
			cell.textLabel.textColor = EMBEDDED_LINK_FONT_COLOR;
			cell.accessoryView = [UIImageView accessoryViewWithMITType:MITAccessoryViewExternal];
			break;
		case CalendarDetailRowTypeDescription:
        {
            UIWebView *webView = (UIWebView *)[cell viewWithTag:kDescriptionWebViewTag];
			webView.delegate = self;
			CGFloat webViewHeight;
			if (self.descriptionHeight > 0) {
				webViewHeight = self.descriptionHeight;
			} else {
				webViewHeight = 2000;
			}

            CGRect frame = CGRectMake(webHorizontalPadding, webVerticalPadding, self.tableView.frame.size.width - 2 * webHorizontalPadding, webViewHeight);
            if (!webView) {
                webView = [[UIWebView alloc] initWithFrame:frame];
				webView.scrollView.scrollsToTop = NO;
				webView.scrollView.scrollEnabled = NO;
                
                webView.delegate = self;
                [webView loadHTMLString:self.descriptionString
                                baseURL:nil];
                webView.tag = kDescriptionWebViewTag;
                [cell.contentView addSubview:webView];
            } else {
                webView.frame = frame;
                [webView loadHTMLString:self.descriptionString
                                baseURL:nil];
            }
					
			break;
        }
		case CalendarDetailRowTypeCategories:
        {
            UIWebView *webView = (UIWebView *)[cell viewWithTag:kCategoriesWebViewTag];
            CGRect frame = CGRectMake(webHorizontalPadding,
                                      webVerticalPadding,
                                      self.tableView.frame.size.width - 2 * webHorizontalPadding,
                                      self.categoriesHeight);
            if (!webView) {
                webView = [[UIWebView alloc] initWithFrame:frame];
                webView.scrollView.scrollsToTop = NO;
				
                [webView loadHTMLString:self.categoriesString
                                baseURL:nil];
                webView.tag = kCategoriesWebViewTag;
                [cell.contentView addSubview:webView];
            } else {
                webView.frame = frame;
                [webView loadHTMLString:self.categoriesString
                                baseURL:nil];
            }

			break;
        }
	}
	
    return cell;
}

- (NSString *)htmlStringFromString:(NSString *)source {
	NSURL *baseURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] resourcePath] isDirectory:YES];
	NSURL *fileURL = [NSURL URLWithString:@"calendar/events_template.html" relativeToURL:baseURL];
	NSError *error;
	NSMutableString *target = [NSMutableString stringWithContentsOfURL:fileURL encoding:NSUTF8StringEncoding error:&error];
	if (!target) {
		DDLogError(@"Failed to load template at %@. %@", fileURL, [error userInfo]);
	}

    CGFloat webHorizontalPadding = (NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_6_1) ? 15. : 10.;

    NSString *maxWidth = [NSString stringWithFormat:@"%.0f", self.tableView.frame.size.width - 2 * webHorizontalPadding];
    [target replaceOccurrencesOfString:@"__WIDTH__" withString:maxWidth options:NSLiteralSearch range:NSMakeRange(0, target.length)];
    
	[target replaceOccurrencesOfStrings:@[@"__BODY__"]
							withStrings:@[source]
								options:NSLiteralSearch];

	return [NSString stringWithString:target];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	NSInteger rowType = [self.rowTypes[indexPath.row] integerValue];
	
	NSString *cellText = nil;
	UIFont *cellFont = nil;
	CGFloat constraintWidth;

	switch (rowType) {
		case CalendarDetailRowTypeCategories:
			return self.categoriesHeight;

		case CalendarDetailRowTypeTime:
			cellText = [self.event dateStringWithDateStyle:NSDateFormatterFullStyle timeStyle:NSDateFormatterShortStyle separator:@"\n"];
			cellFont = [UIFont boldSystemFontOfSize:CELL_STANDARD_FONT_SIZE];
			constraintWidth = tableView.frame.size.width - 21.0;
			break;
		case CalendarDetailRowTypeDescription:
			// this is the same font defined in the html template
			if(self.descriptionHeight > 0) {
				return self.descriptionHeight + CELL_VERTICAL_PADDING * 2;
			} else {
				return 400.0;
			}

			break;
		case CalendarDetailRowTypeURL:
			cellText = self.event.url;
			cellFont = [UIFont systemFontOfSize:CELL_STANDARD_FONT_SIZE];
			// 33 and 21 are from MultiLineTableViewCell.m
			constraintWidth = tableView.frame.size.width - 33.0 - 21.0;
			break;
		case CalendarDetailRowTypeLocation:
			cellText = (self.event.location != nil) ? self.event.location : self.event.shortloc;
			cellFont = [UIFont boldSystemFontOfSize:CELL_STANDARD_FONT_SIZE];
			// 33 and 21 are from MultiLineTableViewCell.m
			constraintWidth = tableView.frame.size.width - 33.0 - 21.0;
			break;
		default:
			return 44.0;
	}

	CGSize textSize = [cellText sizeWithFont:cellFont
						   constrainedToSize:CGSizeMake(constraintWidth, 2010.0)
							   lineBreakMode:NSLineBreakByWordWrapping];
	
	// constant defined in MultiLineTableViewcell.h
	return textSize.height + CELL_VERTICAL_PADDING * 2;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

	NSInteger rowType = [self.rowTypes[indexPath.row] integerValue];
	
	switch (rowType) {
        case CalendarDetailRowTypeTime:
        {
            EKEventStore *eventStore = [[EKEventStore alloc] init];

            NSString *eventNotes = nil;
            NSInteger rowCount = [self tableView:tableView
                           numberOfRowsInSection:indexPath.section];
            NSInteger likelyIndexOfDescriptionRow = rowCount - 2;
            NSIndexPath *descriptionIndexPath = [NSIndexPath indexPathForRow:likelyIndexOfDescriptionRow
                                                                   inSection:indexPath.section];
            if (descriptionIndexPath.row > 0) {
                UITableViewCell *cell = [tableView cellForRowAtIndexPath:descriptionIndexPath];
                UIWebView *webView = (UIWebView *)[cell viewWithTag:kDescriptionWebViewTag];
                eventNotes = [webView stringByEvaluatingJavaScriptFromString:@"function f(){ return document.body.innerText; } f();"];
            }
            
            if ([eventStore respondsToSelector:NSSelectorFromString(@"requestAccessToEntityType:completion:")]) {
                [eventStore requestAccessToEntityType:EKEntityTypeEvent
                                           completion:^(BOOL granted, NSError *error) {
                                               dispatch_async(dispatch_get_main_queue(), ^{
                                                   if (granted) {
                                                       [self presentEditorForEvent:self.event
                                                                         withNotes:eventNotes
                                                                   usingEventStore:eventStore];
                                                   } else {
                                                       UIAlertView *alertView = nil;
                                                       if (error) {
                                                           alertView = [UIAlertView alertViewForError:error
                                                                                            withTitle:self.navigationController.title
                                                                                    alertViewDelegate:nil];
                                                       } else {
                                                           alertView = [[UIAlertView alloc] initWithTitle:self.navigationController.title
                                                                                                  message:@"Unable to save event"
                                                                                                 delegate:nil
                                                                                        cancelButtonTitle:@"Done"
                                                                                        otherButtonTitles:nil];
                                                       }
                                                       
                                                       [alertView show];
                                                   }
                                               });
                                           }];
            } else {
                [self presentEditorForEvent:self.event
                                  withNotes:eventNotes
                            usingEventStore:eventStore];
            }
            
            break;
        }
		case CalendarDetailRowTypeLocation:
            if ([self.event hasCoords]) {
                [[UIApplication sharedApplication] openURL:[NSURL internalURLWithModuleTag:CampusMapTag
                                                                                      path:@"search"
                                                                                     query:self.event.shortloc]];
            }
			break;
		case CalendarDetailRowTypePhone:
		{
			NSString *phoneString = [self.event.phone stringByReplacingOccurrencesOfString:@"-" withString:@""];
			NSURL *phoneURL = [NSURL URLWithString:[NSString stringWithFormat:@"tel://%@", phoneString]];
			if ([[UIApplication sharedApplication] canOpenURL:phoneURL]) {
				[[UIApplication sharedApplication] openURL:phoneURL];
			}
			break;
		}
		case CalendarDetailRowTypeURL:
		{
			NSURL *eventURL = [NSURL URLWithString:self.event.url];
			if ([[UIApplication sharedApplication] canOpenURL:eventURL]) {
				[[UIApplication sharedApplication] openURL:eventURL];
			}
			break;
		}
		default:
			break;
	}
	
	[tableView deselectRowAtIndexPath:indexPath animated:NO];
}

#pragma mark ShareItemDelegate

- (NSString *)actionSheetTitle {
	return @"Share this event";
}

- (NSString *)emailSubject {
	return [NSString stringWithFormat:@"MIT Event: %@", self.event.title];
}

- (NSString *)emailBody {
	return [NSString stringWithFormat:@"I thought you might be interested in this event...\n\n%@\n\n%@",
            self.event.summary,
            self.event.url];
}

- (NSString *)fbDialogPrompt {
	return nil;
}

- (NSString *)fbDialogAttachment {
	return [NSString stringWithFormat:
			@"{\"name\":\"%@\","
			"\"href\":\"%@\","
			"\"description\":\"%@\""
			"}",
			[self.event.title stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""],
            self.event.url,
            [self.event.summary stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""]];
}

- (NSString *)twitterUrl {
    return self.event.url;
}

- (NSString *)twitterTitle {
	return self.event.title;
}

#pragma mark JSONLoadedDelegate for background refreshing of events


#pragma mark -
#pragma mark UIWebView delegation

- (void)webViewDidFinishLoad:(UIWebView *)webView {
	// calculate webView height, if it change we need to reload table
	CGFloat newDescriptionHeight = [[webView stringByEvaluatingJavaScriptFromString:@"document.getElementById(\"main-content\").scrollHeight;"] floatValue];
    CGRect frame = webView.frame;
    frame.size.height = newDescriptionHeight;
    webView.frame = frame;

	if(newDescriptionHeight != self.descriptionHeight) {
		self.descriptionHeight = newDescriptionHeight;
		[self.tableView reloadData];
	}	
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
	if (navigationType == UIWebViewNavigationTypeLinkClicked) {
		[[UIApplication sharedApplication] openURL:[request URL]];
		return NO;
	}
	
	return YES;
}

#pragma mark EKEventEditViewDelegate
- (void)eventEditViewController:(EKEventEditViewController *)controller 
          didCompleteWithAction:(EKEventEditViewAction)action {
    [controller dismissViewControllerAnimated:YES completion:NULL];
}

- (void)presentEditorForEvent:(MITCalendarEvent*)calendarEvent
                    withNotes:(NSString*)notes
              usingEventStore:(EKEventStore*)eventStore
{
    EKEvent *event = [EKEvent eventWithEventStore:eventStore];
    event.calendar = [eventStore defaultCalendarForNewEvents];
    event.notes = notes;
    [calendarEvent setUpEKEvent:event];

    EKEventEditViewController *eventViewController = [[EKEventEditViewController alloc] init];
    eventViewController.event = event;
    eventViewController.eventStore = eventStore;
    eventViewController.editViewDelegate = self;
    [self presentViewController:eventViewController animated:YES completion:NULL];
}

@end
