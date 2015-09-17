//
//  FlipContentView.m
//  WallpaperFlip
//
//  Created by tmy on 12-5-28.
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "FlipContentView.h"

@implementation FlipContentView
@synthesize currentSnapshot,containerImage=_containerImage,pageIndex;

- (void)setContainerImage:(UIImage *)containerImage
{
    _containerImage=containerImage;
    self.currentSnapshot=containerImage;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.layer.opaque=YES;
    }
    return self;
}


- (void)dealloc
{
    self.currentSnapshot=nil;
    [super dealloc];
}

- (void)generateContent
{
    
}

- (void)loadContent
{
    _isContentRemoved=NO;
}

- (void)removeContent
{
    _isContentRemoved=YES;
}

- (void)generateSnapshot
{
    UIGraphicsBeginImageContext(CGSizeMake(320, 480));
    if(self.containerImage)
        [self.containerImage drawInRect:CGRectMake(0, 0, 320, 480)];
    
    [self.layer renderInContext:UIGraphicsGetCurrentContext()];
    self.currentSnapshot=UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
}

- (void)updateSnapshot
{
    if(!_isContentRemoved)
       [self performSelectorInBackground:@selector(generateSnapshot) withObject:nil];
}

@end
