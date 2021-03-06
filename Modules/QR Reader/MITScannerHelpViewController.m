#import "MITScannerHelpViewController.h"
#import "UIKit+MITAdditions.h"

@implementation MITScannerHelpViewController
- (id)init
{
    return [self initWithNibName:nil
                          bundle:nil];
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:@"MITScannerHelpViewController"
                           bundle:nil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    if (NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_6_1) {
        self.view.backgroundColor = [UIColor groupTableViewBackgroundColor];
    } else {
        self.view.backgroundColor = [UIColor mit_backgroundColor];
    }
    self.title = @"Scanner Help";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissHelp:)];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    self.helpTextView = nil;
    self.doneButton = nil;
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

- (IBAction)dismissHelp:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:NULL];
}

@end
