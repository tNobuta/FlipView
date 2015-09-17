//
//  FlipContainerView.h
//  FlipPaper
//
//  Created by tmy on 12-4-18.
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "FlipView.h"
#import "FlipContentView.h"

@interface FlipContainerView : FlipView<FlipViewDelegate>
{
    NSMutableArray      *_contentViews;
    UIImage             *_backgroundImage;    
    FlipContentView     *_currentContentView;
    int                 _maxContentViewCount;
    int                 _totalFlipPageCount;
}

@property (nonatomic,retain) NSArray *contentViews;
@property (nonatomic,retain) FlipContentView *currentContentView;

- (void)generateBackgroundImage;
- (UIImage *)getContentViewSnapshot:(FlipContentView *)view;
- (void)refreshContentViews;
- (void)loadMoreContentViews;
- (void)removeContentViews;
- (void)generateContentViews;
- (void)generateMoreContentViews;
- (void)removeCurrentContents;
- (void)loadCurrentContents;
- (void)showMore;
@end
