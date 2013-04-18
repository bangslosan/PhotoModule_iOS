#import "MySingleton.h"

#import "PTShowcaseViewController.h"

#import "GMGridView.h"
#import "GMGridViewLayoutStrategies.h"

// Thumbnail
#import "PTVideoThumbnailImageView.h"
#import "PTPdfThumbnailImageView.h"

// Detail
#import "PTGroupDetailViewController.h"
#import "PTImageDetailViewController.h"
#import "Photo.h"

#import <MediaPlayer/MediaPlayer.h>

#define THUMBNAIL_TAG   1
#define TEXT_TAG        2
#define DETAIL_TEXT_TAG 3

@interface PTShowcaseViewController () <GMGridViewDataSource, GMGridViewActionDelegate>

- (void)setupShowcaseViewForInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;
//- (void)dismissImageDetailViewController;

// Supported cells for content types
- (GMGridViewCell *)GMGridView:(GMGridView *)gridView cellForContentType:(PTContentType)contentType withOrientation:(PTItemOrientation)orientation;
- (GMGridViewCell *)GMGridView:(GMGridView *)gridView groupCellWithOrientation:(PTItemOrientation)orientation;
- (GMGridViewCell *)GMGridView:(GMGridView *)gridView imageCellWithOrientation:(PTItemOrientation)orientation;
- (GMGridViewCell *)GMGridView:(GMGridView *)gridView videoCellWithOrientation:(PTItemOrientation)orientation;
- (GMGridViewCell *)GMGridView:(GMGridView *)gridView pdfCellWithOrientation:(PTItemOrientation)orientation;

@end

@implementation PTShowcaseViewController

@synthesize detailOn = _detailOn;
@synthesize showcaseView = _showcaseView;
@synthesize detailViewController = _detailViewController;

- (id)init
{
    self = [super init];
    if (self)
    {
        // Custom initialization
        self.showcaseView = [[PTShowcaseView alloc] initWithUniqueName:nil];
        self.showcaseView.showcaseDelegate = self;
        self.showcaseView.showcaseDataSource = self;
    }
    return self;
}

- (id)initWithUniqueName:(NSString *)uniqueName
{
    self = [super init];
    if (self)
    {
        // Custom initialization
        self.showcaseView = [[PTShowcaseView alloc] initWithUniqueName:uniqueName];
        self.showcaseView.showcaseDelegate = self;
        self.showcaseView.showcaseDataSource = self;
    }
    return self;
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView
{
    self.detailOn = NO;
    
    self.showcaseView.centerGrid = NO;
    [self setupShowcaseViewForInterfaceOrientation:[[UIApplication sharedApplication] statusBarOrientation]];

    self.view = self.showcaseView;
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad
{
    [super viewDidLoad];

    // Internal
    self.showcaseView.dataSource = self; // this will trigger 'reloadData' automatically
    self.showcaseView.actionDelegate = self;
}

-(void) dealloc
{
    NSLog(@"[PTShowcaseViewController] dealloc");
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    
    self.showcaseView = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
	return interfaceOrientation == UIInterfaceOrientationMaskPortrait;
    
    //if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
    //{
    //    return interfaceOrientation == UIInterfaceOrientationPortrait || UIInterfaceOrientationIsLandscape(interfaceOrientation);
    //}
    
    //return YES;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [self setupShowcaseViewForInterfaceOrientation:toInterfaceOrientation];
}

#pragma mark - Private

- (void)setupShowcaseViewForInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    self.showcaseView.minEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 0);
    self.showcaseView.itemSpacing = 0;
}

/* =============================================================================
 * Supported cells for content types
 * =============================================================================
 */
- (GMGridViewCell *)GMGridView:(GMGridView *)gridView cellForContentType:(PTContentType)contentType withOrientation:(PTItemOrientation)orientation
{
    GMGridViewCell *cell = nil;
    switch (contentType)
    {
        case PTContentTypeGroup:
        {
            cell = [self GMGridView:gridView groupCellWithOrientation:orientation];
            break;
        }
            
        case PTContentTypeImage:
        {
            cell = [self GMGridView:gridView imageCellWithOrientation:orientation];
            break;
        }
            
        case PTContentTypeVideo:
        {
            cell = [self GMGridView:gridView videoCellWithOrientation:orientation];
            break;
        }
            
        case PTContentTypePdf:
        {
            cell = [self GMGridView:gridView pdfCellWithOrientation:orientation];
            break;
        }
            
        default: NSAssert(NO, @"Unknown content-type.");
    }
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        UILabel *textLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0, 80.0, 80.0, 20.0)];
        textLabel.tag = TEXT_TAG;
        textLabel.font = [UIFont systemFontOfSize:10.0];
        textLabel.textAlignment = UITextAlignmentCenter;
        textLabel.lineBreakMode = UILineBreakModeMiddleTruncation;
        textLabel.textColor = [UIColor whiteColor];
        textLabel.shadowOffset = CGSizeMake(0.0, 1.0);
        textLabel.shadowColor = [UIColor blackColor];
        textLabel.backgroundColor = [UIColor clearColor];
        
        [cell addSubview:textLabel];
    }
    else {
        UILabel *textLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0, 256.0, 256.0, 20.0)];
        textLabel.tag = TEXT_TAG;
        textLabel.font = [UIFont systemFontOfSize:10.0];
        textLabel.textAlignment = UITextAlignmentCenter;
        textLabel.lineBreakMode = UILineBreakModeMiddleTruncation;
        textLabel.textColor = [UIColor whiteColor];
        textLabel.shadowOffset = CGSizeMake(0.0, 1.0);
        textLabel.shadowColor = [UIColor blackColor];
        textLabel.backgroundColor = [UIColor clearColor];
        
        [cell addSubview:textLabel];
    }
    
    return cell;
}

- (GMGridViewCell *)GMGridView:(GMGridView *)gridView groupCellWithOrientation:(PTItemOrientation)orientation;
{
    NSString *cellIdentifier = orientation == PTItemOrientationPortrait ? @"GroupPortraitCell" : @"GroupLandscapeCell";

    GMGridViewCell *cell = [gridView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        cell = [[GMGridViewCell alloc] init];
        cell.reuseIdentifier = cellIdentifier;
        
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
            // Placeholder
            
            NSString *placeholderImageName = @"PTShowcase.bundle/group.png";
            CGRect placeholderImageNameImageViewFrame = CGRectMake(2.0, 2.0, 75.0, 75.0);
            
            UIImageView *placeholderImageView = [[UIImageView alloc] initWithFrame:placeholderImageNameImageViewFrame];
            placeholderImageView.image = [UIImage imageNamed:placeholderImageName];
            [cell addSubview:placeholderImageView];
        }
        else {
            // Back Image
            
            NSString *backImageName = [NSString stringWithFormat:@"PTShowcase.bundle/%@-%@.png", @"group",
                                       orientation == PTItemOrientationPortrait ? @"portrait" : @"landscape"];
            CGRect backImageViewFrame = CGRectMake(0.0, 0.0, 256.0, 256.0);
            
            UIImageView *backImageView = [[UIImageView alloc] initWithFrame:backImageViewFrame];
            backImageView.image = [UIImage imageNamed:backImageName];
            [cell addSubview:backImageView];
            
            // Thumbnail
            
            NSString *loadingImageName = [NSString stringWithFormat:@"PTShowcase.bundle/%@-%@.png", @"thumbnail-loading",
                                          orientation == PTItemOrientationPortrait ? @"portrait" : @"landscape"];
            CGRect loadingImageViewFrame = orientation == PTItemOrientationPortrait
            ? CGRectMake(60.0, 28.0, 135.0, 180.0)
            : CGRectMake(40.0, 50.0, 180.0, 135.0);
            
            NINetworkImageView *thumbnailView = [[NINetworkImageView alloc] initWithFrame:loadingImageViewFrame];
            thumbnailView.tag = THUMBNAIL_TAG;
            thumbnailView.initialImage = [UIImage imageNamed:loadingImageName];
            [cell addSubview:thumbnailView];
        }
    }
    
    return cell;
}

- (GMGridViewCell *)GMGridView:(GMGridView *)gridView imageCellWithOrientation:(PTItemOrientation)orientation;
{
    NSString *cellIdentifier = orientation == PTItemOrientationPortrait ? @"ImagePortraitCell" : @"ImageLandscapeCell";

    GMGridViewCell *cell = [gridView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil)
    {
        cell = [[GMGridViewCell alloc] init];
        cell.reuseIdentifier = cellIdentifier;
        
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
            // Thumbnail
            
            NSString *loadingImageName = @"PTShowcase.bundle/image-loading.png";
            CGRect loadingImageViewFrame = CGRectMake(2.0, 2.0, 75.0, 75.0);
            
            NINetworkImageView *thumbnailView = [[NINetworkImageView alloc] initWithFrame:loadingImageViewFrame];
            thumbnailView.tag = THUMBNAIL_TAG;
            thumbnailView.initialImage = [UIImage imageNamed:loadingImageName];
            [cell addSubview:thumbnailView];
            
            // Overlap
            
            UIImageView *overlapView = [[UIImageView alloc] initWithFrame:loadingImageViewFrame];
            overlapView.image = [UIImage imageNamed:@"PTShowcase.bundle/image-overlap.png"];
            [cell addSubview:overlapView];
        }
        else {
            // Thumbnail
            
            NSString *loadingImageName = [NSString stringWithFormat:@"PTShowcase.bundle/%@-%@.png", @"thumbnail-loading",
                                          orientation == PTItemOrientationPortrait ? @"portrait" : @"landscape"];
            CGRect loadingImageViewFrame = orientation == PTItemOrientationPortrait
            ? CGRectMake(38.0, 8.0, 180.0, 240.0)
            : CGRectMake(8.0, 28.0, 240.0, 180.0);
            
            NINetworkImageView *thumbnailView = [[NINetworkImageView alloc] initWithFrame:loadingImageViewFrame];
            thumbnailView.tag = THUMBNAIL_TAG;
            thumbnailView.initialImage = [UIImage imageNamed:loadingImageName];
            [cell addSubview:thumbnailView];
            
            // Overlap
            
            NSString *overlapImageName = [NSString stringWithFormat:@"PTShowcase.bundle/%@-%@.png", @"image-overlap",
                                          orientation == PTItemOrientationPortrait ? @"portrait" : @"landscape"];
            UIImageView *overlapView = [[UIImageView alloc] initWithFrame:loadingImageViewFrame];
            overlapView.image = [UIImage imageNamed:overlapImageName];
            [cell addSubview:overlapView];
        }
    }
    return cell;
}

- (GMGridViewCell *)GMGridView:(GMGridView *)gridView videoCellWithOrientation:(PTItemOrientation)orientation;
{
    static NSString *CellIdentifier = @"VideoCell";

    GMGridViewCell *cell = [gridView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[GMGridViewCell alloc] init];
        cell.reuseIdentifier = CellIdentifier;
        
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
            // Thumbnail
            
            NSString *loadingImageName = @"PTShowcase.bundle/video-loading.png";
            CGRect loadingImageViewFrame = CGRectMake(2.0, 2.0, 75.0, 75.0);
            UIImage *maskedImage = [PTVideoThumbnailImageView applyMask:[UIImage imageNamed:loadingImageName] forOrientation:orientation];
            
            PTVideoThumbnailImageView *thumbnailView = [[PTVideoThumbnailImageView alloc] initWithFrame:loadingImageViewFrame];
            thumbnailView.tag = THUMBNAIL_TAG;
            thumbnailView.initialImage = maskedImage;
            [cell addSubview:thumbnailView];
            
            // Overlap
            
            UIImageView *overlapView = [[UIImageView alloc] initWithFrame:loadingImageViewFrame];
            overlapView.image = [UIImage imageNamed:@"PTShowcase.bundle/video-overlap.png"];
            [cell addSubview:overlapView];
        }
        else {
            // Thumbnail
            
            NSString *loadingImageName = @"PTShowcase.bundle/video-loading.png";
            CGRect loadingImageViewFrame = CGRectMake(0.0, 30.0, 240.0, 180.0);
            UIImage *maskedImage = [PTVideoThumbnailImageView applyMask:[UIImage imageNamed:loadingImageName] forOrientation:orientation];
            
            PTVideoThumbnailImageView *thumbnailView = [[PTVideoThumbnailImageView alloc] initWithFrame:loadingImageViewFrame];
            thumbnailView.tag = THUMBNAIL_TAG;
            thumbnailView.initialImage = maskedImage;
            [cell addSubview:thumbnailView];
            
            // Overlap
            
            UIImageView *overlapView = [[UIImageView alloc] initWithFrame:loadingImageViewFrame];
            overlapView.image = [UIImage imageNamed:@"PTShowcase.bundle/video-overlap.png"];
            [cell addSubview:overlapView];
        }
    }
    
    return cell;
}

- (GMGridViewCell *)GMGridView:(GMGridView *)gridView pdfCellWithOrientation:(PTItemOrientation)orientation;
{
    NSString *cellIdentifier = orientation == PTItemOrientationPortrait ? @"PdfPortraitCell" : @"PdfLandscapeCell";

    GMGridViewCell *cell = [gridView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        cell = [[GMGridViewCell alloc] init];
        cell.reuseIdentifier = cellIdentifier;
        
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
            // Thumbnail
            
            NSString *loadingImageName = @"PTShowcase.bundle/document-loading.png";
            CGRect loadingImageViewFrame = CGRectMake(2.0, 2.0, 75.0, 75.0);
            UIImage *maskedImage = [PTPdfThumbnailImageView applyMask:[UIImage imageNamed:loadingImageName] forOrientation:orientation];
            
            PTPdfThumbnailImageView *thumbnailView = [[PTPdfThumbnailImageView alloc] initWithFrame:loadingImageViewFrame];
            thumbnailView.tag = THUMBNAIL_TAG;
            thumbnailView.initialImage = maskedImage;
            [cell addSubview:thumbnailView];
            
            // Overlap
            
            UIImageView *overlapView = [[UIImageView alloc] initWithFrame:loadingImageViewFrame];
            overlapView.image = [UIImage imageNamed:@"PTShowcase.bundle/document-overlap.png"];
            [cell addSubview:overlapView];
        }
        else {
            // Back Image
            
            NSString *backImageName = [NSString stringWithFormat:@"PTShowcase.bundle/%@-%@.png", @"document-pages",
                                       orientation == PTItemOrientationPortrait ? @"portrait" : @"landscape"];
            CGRect backImageViewFrame = CGRectMake(0.0, 0.0, 256.0, 256.0);
            
            UIImageView *backImageView = [[UIImageView alloc] initWithFrame:backImageViewFrame];
            backImageView.image = [UIImage imageNamed:backImageName];
            [cell addSubview:backImageView];
            
            // Thumbnail
            
            NSString *loadingImageName = [NSString stringWithFormat:@"PTShowcase.bundle/%@-%@.png", @"thumbnail-loading",
                                          orientation == PTItemOrientationPortrait ? @"portrait" : @"landscape"];
            CGRect loadingImageViewFrame = orientation == PTItemOrientationPortrait
            ? CGRectMake(60.0, 38.0, 135.0, 180.0)
            : CGRectMake(38.0, 61.0, 180.0, 135.0);
            
            NINetworkImageView *thumbnailView = [[NINetworkImageView alloc] initWithFrame:loadingImageViewFrame];
            thumbnailView.tag = THUMBNAIL_TAG;
            thumbnailView.initialImage = [UIImage imageNamed:loadingImageName];
            [cell addSubview:thumbnailView];
        }
    }
    
    return cell;
}

#pragma mark - GMGridViewDataSource

- (NSInteger)numberOfItemsInGMGridView:(GMGridView *)gridView
{
    return [self.showcaseView numberOfItems];
}

- (CGSize)GMGridView:(GMGridView *)gridView sizeForItemsInInterfaceOrientation:(UIInterfaceOrientation)orientation
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return CGSizeMake(80.0, 80.0+20.0);
    }

    return CGSizeMake(256.0, 256.0+20.0);
}

- (GMGridViewCell *)GMGridView:(GMGridView *)gridView cellForItemAtIndex:(NSInteger)index
{
    PTContentType contentType = [self.showcaseView contentTypeForItemAtIndex:index];
    PTItemOrientation orientation = [self.showcaseView orientationForItemAtIndex:index];
    NSString *thumbnailImageSource = [self.showcaseView sourceForThumbnailImageOfItemAtIndex:index];

    // Dequeue or generate a new cell
    GMGridViewCell *cell = [self GMGridView:gridView cellForContentType:contentType withOrientation:orientation];

    // Configure the cell...
    
    NINetworkImageView *thumbnailView = (NINetworkImageView *)[cell viewWithTag:THUMBNAIL_TAG];
    thumbnailView.contentMode = UIViewContentModeScaleAspectFill;
    [thumbnailView setPathToNetworkImage:thumbnailImageSource];

    UILabel *textLabel = (UILabel *)[cell viewWithTag:TEXT_TAG];
    
    Photo *photo = (Photo *)[gSingleton.mainData objectAtIndex:index];
    
    if ([photo.description length] == 0)
        textLabel.text = photo.label.getDisplayText;
    else
        textLabel.text = photo.description;
    
    NSString *uniqueName = [self.showcaseView uniqueNameForItemAtIndex:index];
    
    cell.fileName = uniqueName;
    cell.lab = textLabel;
    cell.ind = index;
    
    // start listening to label events
    [cell initEvents];
    
    if (photo.selected)
    {
        cell.backgroundColor = [UIColor blueColor];
    }
    else
    {
        cell.backgroundColor = [UIColor clearColor];
    }
    
    //cell.backgroundColor = [UIColor greenColor];
    //textLabel.backgroundColor = [UIColor redColor];
    
    return cell;
}

#pragma mark - GMGridViewActionDelegate

//

- (void)GMGridView:(GMGridView *)gridView didTapOnItemAtIndex:(NSInteger)position
{
    PTContentType contentType = [self.showcaseView contentTypeForItemAtIndex:position];
    //NSString *uniqueName = [self.showcaseView uniqueNameForItemAtIndex:position];
    //NSString *path = [self.showcaseView pathForItemAtIndex:position];
    //NSString *text = [self.showcaseView textForItemAtIndex:position];
    
    if (gSingleton.showTrace)
        NSLog(@"itemTap (GridViewCell) %d", position);
    
    gSingleton.expandedViewIndex = position;
    
    switch (contentType)
    {
        
        /*
        case PTContentTypeGroup:
        {
            PTGroupDetailViewController *detailViewController = [[PTGroupDetailViewController alloc] initWithUniqueName:uniqueName];
            detailViewController.showcaseView.showcaseDelegate = self.showcaseView.showcaseDelegate;
            detailViewController.showcaseView.showcaseDataSource = self.showcaseView.showcaseDataSource;
            
            detailViewController.title = text;
            detailViewController.view.backgroundColor = self.view.backgroundColor;

            [self.navigationController pushViewController:detailViewController animated:YES];
            
            break;
        }
        */
            
        case PTContentTypeImage:
        {
            
            
            //PTItemOrientation orientation = [self.showcaseView orientationForItemAtIndex:position];
            
            
            //GMGridViewCell *cell = [self GMGridView:gridView cellForItemAtIndex:position];
            
            GMGridViewCell *cell = [gridView cellForItemAtIndex:position];
            [cell toggleSel];
            
            
            
            
            /*
            
            PTImageDetailViewController *detailViewController = [[PTImageDetailViewController alloc] initWithImageAtIndex:g_relativeIndex];
            detailViewController.data = self.showcaseView.imageItems;
            detailViewController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
            
            [detailViewController.navigationItem setLeftBarButtonItem:
             [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                           target:self
                                                           action:@selector(dismissImageDetailViewController)]];
            
            UINavigationController *navCtrl = [[UINavigationController alloc] initWithRootViewController:detailViewController];
            
            
             
            // TODO zoom in/out (just like in Photos.app in the iPad)
            [self presentViewController:navCtrl animated:YES completion:NULL];
             
            */
            
            break;
        }
        
        /*
        case PTContentTypeVideo:
        {
            // TODO remove duplicate
            // >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
            NSURL *url = nil;

            // Check for file URLs.
            if ([path hasPrefix:@"/"]) {
                // If the url starts with / then it's likely a file URL, so treat it accordingly.
                url = [NSURL fileURLWithPath:path];
            }
            else {
                // Otherwise we assume it's a regular URL.
                url = [NSURL URLWithString:path];
            }
            // <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

            MPMoviePlayerViewController *detailViewController = [[MPMoviePlayerViewController alloc] initWithContentURL:url];
            detailViewController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;

            detailViewController.title = text;

            // TODO zoom in/out (just like in Photos.app in the iPad)
            [self presentMoviePlayerViewControllerAnimated:detailViewController];
            
            break;
        }
            
        case PTContentTypePdf:
        {
            // TODO remove duplicate
            // >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
            NSURL *url = nil;
            
            // Check for file URLs.
            if ([path hasPrefix:@"/"]) {
                // If the url starts with / then it's likely a file URL, so treat it accordingly.
                url = [NSURL fileURLWithPath:path];
            }
            else {
                // Otherwise we assume it's a regular URL.
                url = [NSURL URLWithString:path];
            }
            // <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
            
            PSPDFDocument *document = [PSPDFDocument PDFDocumentWithUrl:url];
            PSPDFViewController *detailViewController = [[PSPDFViewController alloc] initWithDocument:document];
            detailViewController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;

            
            detailViewController.title = text;
            detailViewController.view.backgroundColor = self.view.backgroundColor;
            
            UINavigationController *navCtrl = [[UINavigationController alloc] initWithRootViewController:detailViewController];

            // TODO zoom in/out (just like in Photos.app in the iPad)
            [self presentViewController:navCtrl animated:YES completion:NULL];
            
            break;
        }
        */
            
        default: NSAssert(NO, @"Unknown content-type.");
    }
}

#pragma mark - PTShowcaseViewDelegate

- (PTItemOrientation)showcaseView:(PTShowcaseView *)showcaseView orientationForItemAtIndex:(NSInteger)index
{
    return PTItemOrientationPortrait;
}

#pragma mark - PTShowcaseViewDataSource

- (NSInteger)numberOfItemsInShowcaseView:(PTShowcaseView *)showcaseView
{
    NSAssert(NO, @"missing required method implementation 'numberOfItemsInShowcaseView:'");
    return -1;
}

- (PTContentType)showcaseView:(PTShowcaseView *)showcaseView contentTypeForItemAtIndex:(NSInteger)index
{
    NSAssert(NO, @"missing required method implementation 'showcaseView:contentTypeForItemAtIndex:'");
    return -1;
}

- (NSString *)showcaseView:(PTShowcaseView *)showcaseView pathForItemAtIndex:(NSInteger)index
{
    NSAssert(NO, @"missing required method implementation 'showcaseView:pathForItemAtIndex:'");
    return nil;
}

- (NSString *)showcaseView:(PTShowcaseView *)showcaseView uniqueNameForItemAtIndex:(NSInteger)index;
{
    return nil;
}

- (NSString *)showcaseView:(PTShowcaseView *)showcaseView sourceForThumbnailImageOfItemAtIndex:(NSInteger)index
{
    return nil;
}

- (NSString *)showcaseView:(PTShowcaseView *)showcaseView textForItemAtIndex:(NSInteger)index
{
    return nil;
}

@end
