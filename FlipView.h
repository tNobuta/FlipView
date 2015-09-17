//
//  FlipView.h
//  ImageLoaderDemo
//
//  Created by tmy on 12-3-18.
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>

typedef enum 
{
    FlipDirectionDown=-1,  //从上往下翻
    FlipDirectionUp=1,    //从下往上翻
    FlipDirectionNone=0
}FlipDirection;


@interface FlipLayer : CATransformLayer

@property (nonatomic) int flipIndex;
@property (nonatomic) BOOL isFlipped;
@property (nonatomic,assign) CALayer *front;
@property (nonatomic,assign) CALayer *back;
@property (nonatomic,assign) CALayer *frontShadow;
@property (nonatomic,assign) CALayer *backShadow;
@end


@protocol FlipViewDelegate;

@interface FlipView : UIView
{
    id<FlipViewDelegate> _delegate;
    NSMutableArray      *_flipLayers;
    NSMutableArray      *_flipLayersQueue;
    NSMutableArray      *_flipingLayers;
    UIImage             *_defaultImage;
    CALayer             *_containerLayer;
    CALayer             *_contentLayer;
    CALayer             *_backgroundLayer;
    NSTimeInterval      _flipTime;
    NSTimeInterval      _bounceTime;
    BOOL                _isBounce;
    BOOL                _isShadowEnable;
    BOOL                _needRecycle;
    int                 _recycleCount;
    int                 _pageCount;
    int                 _currentPage;
    int                 _prePage;
    float               _bounceAngle;
    float               _restrictAngle;
    FlipDirection       _flipDirection;
    CGSize              _transformSize;
    BOOL                _isTouchedDown;
    NSTimeInterval      _touchTime;
    CGPoint             _touchStartingPoint;
    CGPoint             _preTouchPoint;
    float               _lastTouchDistance;
    NSTimeInterval      _startTouchTime;
    FlipLayer           *_touchedLayer;
    FlipLayer           *_preLayer;
    FlipLayer           *_nextLayer;
    float               _maxShadowAlpha;
    float               _angleToAlpha;
    float               _pixelToAngle;
    float               _maxAngle;
    float               _minAngle;
    float               _perspective;
    CGRect              _frontClipRect;
    CGRect              _backClipRect;
    float               _rotateFactor;
    BOOL                _isContentLoaded;
    BOOL                _isTouchStart;
    BOOL                _isFlipAvalible;
}

@property (nonatomic,assign) id<FlipViewDelegate> delegate;
@property (nonatomic)  NSTimeInterval flipTime;   //default 0.5
@property (nonatomic)  BOOL isBounce;
@property (nonatomic)  BOOL isShadowEnable;
@property (nonatomic)  int  currentPage;
@property (nonatomic)   float perspective;
@property (nonatomic,retain) UIImage *defaultImage;
@property (nonatomic,retain) UIColor *maskColor;
@property (nonatomic,readonly) CALayer *backgroundLayer;
@property (nonatomic) BOOL isFlipEnabled;
@property (nonatomic) BOOL isContinuousFlipEnabled;

- (id)initWithFrame:(CGRect)frame direction:(FlipDirection)direction;

- (void)reloadPages;
- (void)appendPages:(int)toAppendCount;
- (void)removePages;
- (void)updateContents;
- (void)removeContents;
- (void)showFlip;
- (void)hideFlip;
- (void)flipToNextPageWithAnimation:(BOOL)isAnimation;
- (void)flipToPrePageWithAnimation:(BOOL)isAnimation;   
- (void)flipToLastPageWithAnimation:(BOOL)isAnimation;
- (void)flipToFirstPageWithAnimation:(BOOL)isAnimation;
- (void)flipToPage:(int)pageIndex isAnimation:(BOOL)isAnimation;

@end



@protocol FlipViewDelegate <NSObject>

@optional
- (void)flipView:(FlipView *)flipView didStartFlipWithDirection:(FlipDirection)direction;
- (void)flipView:(FlipView *)flipView didFinishFlipWithDirection:(FlipDirection) direction;
- (void)flipView:(FlipView *)flipView didFlipToPage:(int)pageIndex direction:(FlipDirection)direction;
- (void)flipViewDidBeginDrag:(FlipView *)flipView;
- (void)flipViewDidEndDrag:(FlipView *)flipView;
- (void)flipView:(FlipView *)flipView didFlipWithAngle:(float)angle;
@required

- (NSInteger)numberOfFlipPagesInFlipView:(FlipView *)flipView;
- (UIImage *)flipView:(FlipView *)flipView contentForFlipAtPageIndex:(int)pageIndex;
@end



