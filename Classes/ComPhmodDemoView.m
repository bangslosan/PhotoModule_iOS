/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2009-2011 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */

#import "ComPhmodDemoView.h"

#import "TiUtils.h"

@implementation ComPhmodDemoView

-(void)dealloc
{
    if (mSingleton.showTrace)
        NSLog(@"[VIEW LIFECYCLE EVENT] dealloc");
	
	// Release objects and memory allocated by the view
    [[self subviews] enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL *stop)
    {
          [(UIView *)obj removeFromSuperview];
    }];
    square = nil;
}

-(void)willMoveToSuperview:(UIView *)newSuperview
{
    if (mSingleton.showTrace)
        NSLog(@"[VIEW LIFECYCLE EVENT] willMoveToSuperview");
}

-(void)initializeState
{
	// This method is called right after allocating the view and
	// is useful for initializing anything specific to the view
	
	[super initializeState];
	
    if (mSingleton.showTrace)
        NSLog(@"[VIEW LIFECYCLE EVENT] initializeState");
}

-(void)configurationSet
{
	// This method is called right after all view properties have
	// been initialized from the view proxy. If the view is dependent
	// upon any properties being initialized then this is the method
	// to implement the dependent functionality.
	
	[super configurationSet];
	
    if (mSingleton.showTrace)
        NSLog(@"[VIEW LIFECYCLE EVENT] configurationSet");
}


-(UIView*)square
{
	// Return the square view. If this is the first time then allocate and
	// initialize it.
    
    if (square == nil)
    {
        if (mSingleton.showTrace)
            NSLog(@"[VIEW LIFECYCLE EVENT] square");
		
		//square = [[UIView alloc] initWithFrame:[self frame]];
        //[square addSubview:mSingleton.myPhotoHubLib.mainViewController.view];
		
        square = mSingleton.myPhotoHubLib.mainViewController.view;
        
        self.backgroundColor = [UIColor blackColor];
        square.backgroundColor = [UIColor blackColor];
        
        [self addSubview:square];
	}
	return square;
}

-(void)frameSizeChanged:(CGRect)frame bounds:(CGRect)bounds
{
	// You must implement this method for your view to be sized correctly.
	// This method is called each time the frame / bounds / center changes
	// within Titanium. 
	
    if (square != nil)
    {
        if (mSingleton.showTrace)
            NSLog(@"[VIEW LIFECYCLE EVENT] frameSizeChanged");

        // You must call the special method 'setView:positionRect' against
        // the TiUtils helper class. This method will correctly layout your
        // child view within the correct layout boundaries of the new bounds
        // of your view.
		
        [TiUtils setView:square positionRect:bounds];
        
        [mSingleton.myPhotoHubLib.mainViewController setBoundsAndLayout:bounds];
    }
}

-(void)setColor_:(id)color
{
	// This method is a property 'setter' for the 'color' property of the
	// view. View property methods are named using a special, required
	// convention (the underscore suffix).
	
    if (mSingleton.showTrace)
        NSLog(@"[VIEW LIFECYCLE EVENT] Property Set: setColor_");
	
    // Use the TiUtils methods to get the values from the arguments
    TiColor *newColor = [TiUtils colorValue:color];
    UIColor *clr = [newColor _color];
    UIView *sq = [self square];
    sq.backgroundColor = clr;
}

@end