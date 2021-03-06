//
//  PSPDFAnnotationTestController.m
//  EmbeddedExample
//
//  Copyright (c) 2011-2012 Peter Steinberger. All rights reserved.
//

#import "PSPDFAnnotationTestController.h"
#import <MapKit/MapKit.h>
#import <MediaPlayer/MediaPlayer.h>

@implementation PSPDFAnnotationTestController

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject

- (id)initWithDocument:(PSPDFDocument *)document {
    if ((self = [super initWithDocument:document])) {
        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Annotations" image:[UIImage imageNamed:@"45-movie-1"] tag:4];
        self.delegate = self; // set PSPDFViewControllerDelegate to self
        self.pageCurlEnabled = YES;
        self.tintColor = [UIColor orangeColor];
        self.printEnabled = YES;
    }
    return self;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - PSPDFViewController

// disable back button
- (UIBarButtonItem *)toolbarBackButton {
    return nil;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - PSPDFViewControllerDelegate

/// time to adjust PSPDFViewController before a PSPDFDocument is displayed
- (void)pdfViewController:(PSPDFViewController *)pdfController willDisplayDocument:(PSPDFDocument *)document {
    NSLog(@"willDisplayDocument: %@", document);    
}

/// delegate to be notified when pdfController finished loading
- (void)pdfViewController:(PSPDFViewController *)pdfController didDisplayDocument:(PSPDFDocument *)document {
    NSLog(@"didDisplayDocument: %@", document);
}

/// controller did show/scrolled to a new page (at least 51% of it is visible)
- (void)pdfViewController:(PSPDFViewController *)pdfController didShowPageView:(PSPDFPageView *)pageView {
    NSLog(@"didShowPageView: page:%d", pageView.page);
}

/// page was fully rendered at zoomlevel = 1
- (void)pdfViewController:(PSPDFViewController *)pdfController didRenderPageView:(PSPDFPageView *)pageView {
    NSLog(@"didRenderPageView: page:%d", pageView.page);    
}

/// will be called when viewMode changes
- (void)pdfViewController:(PSPDFViewController *)pdfController didChangeViewMode:(PSPDFViewMode)viewMode {
    NSLog(@"didChangeViewMode: %d", viewMode);        
}

/// called after pdf page has been loaded and added to the pagingScrollView.
- (void)pdfViewController:(PSPDFViewController *)pdfController didLoadPageView:(PSPDFPageView *)pageView; {
    NSLog(@"didLoadPageView: page:%d", pageView.page);
}

/// called before a pdf page will be unloaded and removed from the pagingScrollView.
- (void)pdfViewController:(PSPDFViewController *)pdfController willUnloadPageView:(PSPDFPageView *)pageView; {
    NSLog(@"willUnloadPageView: page:%d", pageView.page);
}

/// if user tapped within page bounds, this will notify you.
/// return YES if this touch was processed by you and need no further checking by PSPDFKit.
/// Note that PSPDFPageInfo may has only page=1 if the optimization isAspectRatioEqual is enabled.
- (BOOL)pdfViewController:(PSPDFViewController *)pdfController didTapOnPageView:(PSPDFPageView *)pageView info:(PSPDFPageInfo *)pageInfo coordinates:(PSPDFPageCoordinates *)pageCoordinates {
    NSLog(@"didTapOnPageView: page:%d", pageView.page);
    return NO;
}

- (UIView *)pdfViewController:(PSPDFViewController *)pdfController viewForAnnotation:(PSPDFAnnotation *)annotation onPageView:(PSPDFPageView *)pageView {
    
    // example how to add a MapView with the url protocol map://lat,long,latspan,longspan
    if (annotation.type == PSPDFAnnotationTypeCustom && [annotation.siteLinkTarget hasPrefix:@"map://"]) {
        // parse annotation data
        NSString *mapData = [annotation.siteLinkTarget stringByReplacingOccurrencesOfString:@"map://" withString:@""];
        NSArray *token = [mapData componentsSeparatedByString:@","];

        // ensure we have token count of 4 (latitude, longitude, span la, span lo)
        if ([token count] == 4) {
            CLLocationCoordinate2D location = CLLocationCoordinate2DMake([[token objectAtIndex:0] doubleValue],
                                                                         [[token objectAtIndex:1] doubleValue]);
            
            MKCoordinateSpan span = MKCoordinateSpanMake([[token objectAtIndex:2] doubleValue],
                                                         [[token objectAtIndex:3] doubleValue]);
            
            // frame is set in PSPDFViewController, but MKMapView needs the position before setting the region.
            CGRect frame = [annotation rectForPageRect:pageView.bounds];
            
            MKMapView *mapView = [[MKMapView alloc] initWithFrame:frame];
            [mapView setRegion:MKCoordinateRegionMake(location, span) animated:NO];
            return mapView;
        }
    }
    return nil;
}

/// Invoked prior to the presentation of the annotation view: use this to configure actions etc
- (void)pdfViewController:(PSPDFViewController *)pdfController willShowAnnotationView:(UIView <PSPDFAnnotationView> *)annotationView onPageView:(PSPDFPageView *)pageView {
    NSLog(@"willShowAnnotationView: %@ page:%d", annotationView, pageView.page);
}

/// Invoked after animation used to present the annotation view
- (void)pdfViewController:(PSPDFViewController *)pdfController didShowAnnotationView:(UIView <PSPDFAnnotationView> *)annotationView onPageView:(PSPDFPageView *)pageView {
    NSLog(@"didShowAnnotationView: %@ page:%d", annotationView, pageView.page);    
}

@end
