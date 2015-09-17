//
//  FlipContentView.h
//  WallpaperFlip
//
//  Created by tmy on 12-5-28.
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface FlipContentView : UIView
{
    BOOL        _isContentRemoved;
}

@property (nonatomic) int pageIndex;
@property (nonatomic,assign) UIImage *containerImage;
@property (nonatomic,retain) UIImage *currentSnapshot;

- (void)generateContent;
- (void)loadContent;
- (void)removeContent;
- (void)generateSnapshot;
- (void)updateSnapshot;
@end
