//
//  FlipContainerView.m
//  FlipPaper
//
//  Created by tmy on 12-4-18.
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//

#import "FlipContainerView.h"


@implementation FlipContainerView
@synthesize contentViews=_contentViews,currentContentView=_currentContentView;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame direction:FlipDirectionUp];
    if (self) {
        self.backgroundColor=[UIColor whiteColor];
        self.maskColor=[UIColor viewFlipsideBackgroundColor];
        self.perspective=1300;
        self.delegate=self;
        self.flipTime=0.5f;
        self.isContinuousFlipEnabled=NO;
        _maxContentViewCount=9;
        _contentViews=[[NSMutableArray alloc] init];
    }
    return self;  
}

- (void)dealloc
{
    [_contentViews release];
    [_backgroundImage release];
    [super dealloc];
}

- (void)removeCurrentContents
{
    if(_currentContentView)
        [_currentContentView removeContent];
}

- (void)loadCurrentContents
{
    if(_currentContentView)
        [_currentContentView loadContent];
}

- (void)generateBackgroundImage
{
    [_backgroundImage release];
    UIGraphicsBeginImageContext(self.bounds.size);
    [self.layer renderInContext:UIGraphicsGetCurrentContext()]; 
    _backgroundImage=[UIGraphicsGetImageFromCurrentImageContext() retain]; 
    UIGraphicsEndImageContext();   
}

- (void)refreshContentViews
{
    _currentContentView=nil;
    [_contentViews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [_contentViews removeAllObjects];
    [self generateBackgroundImage];
    [self generateContentViews];
    if([_contentViews count]>0)
    {
        int index=[_contentViews indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
            return ((FlipContentView *)obj).pageIndex==_currentPage;
        }];
        
        if(index!=NSNotFound)
        {
            FlipContentView *contentView=[_contentViews objectAtIndex:index];
            [self insertSubview:contentView atIndex:0];
            _currentContentView=contentView;
        }

    }
    
    [self reloadPages];
}

- (void)loadMoreContentViews
{
    self.userInteractionEnabled=NO;
    [self generateMoreContentViews]; //change the _totalFlipPageCount
    [self reloadPages];
    [self performSelector:@selector(showMore) withObject:nil afterDelay:0.7f];
}

- (void)showMore
{
    [self updateContents];
    [self showFlip];
    [self flipToNextPageWithAnimation:YES];
    self.userInteractionEnabled=YES;
}

- (void)removeContentViews
{
    _currentContentView=nil;
    [_contentViews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [_contentViews removeAllObjects];
    self.currentPage=0;
}

- (void)generateContentViews
{
    
}

- (void)generateMoreContentViews
{
     
}

- (UIImage *)getContentViewSnapshot:(FlipContentView *)view
{
    return view.currentSnapshot;
}

- (NSInteger)numberOfFlipPagesInFlipView:(FlipView *)flipView
{
    return _totalFlipPageCount;
}

- (UIImage *)flipView:(FlipView *)flipView contentForFlipAtPageIndex:(int)pageIndex
{  
    int index=[_contentViews indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
        return ((FlipContentView *)obj).pageIndex==pageIndex;
    }];
    
    if(index!=NSNotFound)
        return  [self getContentViewSnapshot:[_contentViews objectAtIndex:index]];
    else 
        return nil;
}

- (void)flipView:(FlipView *)flipView didFlipToPage:(int)pageIndex direction:(FlipDirection)direction
{
 
}

- (void)flipView:(FlipView *)flipView didStartFlipWithDirection:(FlipDirection)direction
{ 
    [self updateContents];
}

- (void)flipView:(FlipView *)flipView didFinishFlipWithDirection:(FlipDirection)direction
{    
    int index=[_contentViews indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
        return ((FlipContentView *)obj).pageIndex==flipView.currentPage;
    }];
    
    if(index!=NSNotFound)
    {
        FlipContentView *contentView=[_contentViews objectAtIndex:index];
        
        if(contentView!=_currentContentView)
        {
            [_currentContentView removeContent];
            [_currentContentView removeFromSuperview];
            [contentView loadContent];
            [self insertSubview:contentView atIndex:0];
            _currentContentView=contentView;
        }
    }
  
    [self hideFlip];
    [self removeContents];
 
}

- (void)flipViewDidBeginDrag:(FlipView *)flipView
{
   
}

- (void)flipViewDidEndDrag:(FlipView *)flipView
{

}

@end
