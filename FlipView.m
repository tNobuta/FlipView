//
//  FlipView.m
//  ImageLoaderDemo
//
//  Created by tmy on 12-3-18.
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//


#import "FlipView.h"


#define ANIMATION_LEY @"flip"
#define SHADOW_ANIMATION @"shadow"

@implementation FlipLayer

@synthesize flipIndex,isFlipped,front,back,frontShadow,backShadow;

- (void)dealloc
{
    [super dealloc];
}

@end

@interface FlipView ()

- (void)initFlipLayers;
- (FlipLayer *)generateTransformLayer;
- (void)generateContentForLayer:(FlipLayer *)layer;
- (void)resetFlipLayer:(FlipLayer *)layer;
- (void)recycleFlipLayersWithDirection:(FlipDirection)direction;
- (void)flipLayer:(CALayer *)layer toDirection:(FlipDirection)direction animation:(BOOL)isAnimation;
- (void)flipToNextWithAnimation:(NSNumber *)isAnimation;
- (void)flipToPreWithAnimation:(NSNumber *)isAnimation;
@end

@implementation FlipView
@synthesize delegate=_delegate,flipTime=_flipTime,isBounce=_isBounce,currentPage=_currentPage,isShadowEnable=_isShadowEnable,perspective=_perspective,defaultImage=_defaultImage,maskColor,backgroundLayer=_backgroundLayer,isFlipEnabled,isContinuousFlipEnabled;

- (void)setMaskColor:(UIColor *)value
{
    _backgroundLayer.backgroundColor=value.CGColor;
}

- (id)initWithFrame:(CGRect)frame direction:(FlipDirection)direction
{
    if(self=[super initWithFrame:frame])
    {
        _containerLayer=[[CALayer alloc] init];
        _containerLayer.frame=self.bounds;
        _containerLayer.hidden=YES;
        [self.layer addSublayer:_containerLayer];
        
        _backgroundLayer=[[CALayer alloc] init];
        _backgroundLayer.frame=self.bounds;
        [_containerLayer addSublayer:_backgroundLayer];
        
        _contentLayer=[[CALayer alloc] init];
        _contentLayer.frame=self.bounds;
        [_containerLayer addSublayer:_contentLayer];
        
        self.isFlipEnabled=YES;
        self.isContinuousFlipEnabled=YES;
        _flipTime=0.5f;
        _bounceTime=0.3f;
        _bounceAngle=23.0f*M_PI/180;
        _maxAngle=M_PI*0.99999f;
        _minAngle=0;
        _restrictAngle=70*M_PI/180;
        _maxShadowAlpha=0.9f;
        _angleToAlpha=_maxShadowAlpha/(_maxAngle/2);
        _pixelToAngle=_maxAngle/(frame.size.height*0.5f);
        _rotateFactor=0.000003f;
        _perspective=500;
        _isShadowEnable=YES;
        _flipDirection=direction;
        _recycleCount=6;
        _flipLayers=[[NSMutableArray alloc] init];
        _flipLayersQueue=[[NSMutableArray alloc] initWithCapacity:10];
        _flipingLayers=[[NSMutableArray alloc] init];
        _transformSize=CGSizeMake(frame.size.width, frame.size.height/2);
        
        _frontClipRect=_flipDirection==FlipDirectionUp?CGRectMake(0, _transformSize.height, _transformSize.width, _transformSize.height): CGRectMake(0, 0, _transformSize.width, _transformSize.height);
        
        _backClipRect=_flipDirection==FlipDirectionUp?CGRectMake(0, 0,_transformSize.width, _transformSize.height):CGRectMake(0, _transformSize.height, _transformSize.width, _transformSize.height);

        
        UIGraphicsBeginImageContext(_transformSize);
        CGContextSetFillColorWithColor(UIGraphicsGetCurrentContext(), [UIColor colorWithRed:0.9f green:0.9f blue:0.9f alpha:1].CGColor);
        CGContextFillRect(UIGraphicsGetCurrentContext(), CGRectMake(0, 0, _transformSize.width, _transformSize.height));
        CGImageRef image=CGBitmapContextCreateImage(UIGraphicsGetCurrentContext());
        _defaultImage=[[UIImage imageWithCGImage:image] retain];
        UIGraphicsEndImageContext();
        CGImageRelease(image);
        
        _backgroundLayer.backgroundColor=[UIColor colorWithRed:0.6f green:0.6f blue:0.6f alpha:1].CGColor;
    }
    
    return self;
}

- (void)dealloc
{
    [_flipingLayers makeObjectsPerformSelector:@selector(removeAllAnimations)];
    [_flipingLayers release];
    [_flipLayers release];
    [_flipLayersQueue release];
    [_defaultImage release];
    [_containerLayer release];
    [_backgroundLayer release];
    [_contentLayer release];
    [super dealloc];
}


- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    if(!self.isFlipEnabled || [_flipLayers count]==0)
        return;
    
    if([touches count]==1)
    {
        UITouch *touch=[touches anyObject];
        if(touch.tapCount==1)
        {
            _isTouchedDown=YES;
            _touchStartingPoint=[touch locationInView:touch.view];
            _preTouchPoint=_touchStartingPoint;
            _startTouchTime=[NSDate timeIntervalSinceReferenceDate];
            _isTouchStart=YES;
            
            if( _delegate && [_delegate respondsToSelector:@selector(flipViewDidBeginDrag:)])
                [_delegate flipViewDidBeginDrag:self];

        }
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    if(!self.isFlipEnabled || [_flipLayers count]==0)
        return;
    
    if([touches count]==1)
    {
        UITouch *touch=[touches anyObject];
        CGPoint currentPoint=[touch locationInView:touch.view];
        
        _lastTouchDistance=currentPoint.y-_preTouchPoint.y;
        NSTimeInterval endTouchTime=[NSDate timeIntervalSinceReferenceDate];
        _touchTime=endTouchTime-_startTouchTime;
        
        if(_lastTouchDistance==0)
            return;
        
        if([_flipingLayers count]==0 )
        {
            [self showFlip];
            
            if(_delegate && [_delegate respondsToSelector:@selector(flipView:didStartFlipWithDirection:)])
                [_delegate flipView:self didStartFlipWithDirection:_lastTouchDistance>0?FlipDirectionDown:FlipDirectionUp];
        }
        
        if(!_touchedLayer)
        {
            int flipIndex,flipLayerIndex;
            
            if( _lastTouchDistance>0)
            {
                 flipIndex=_flipDirection==FlipDirectionUp?(_currentPage!=-1?_currentPage:0):_currentPage+1;
            }
            else if(_lastTouchDistance<0)
            {
                flipIndex=_flipDirection==FlipDirectionUp?(_currentPage+1>=_pageCount?_pageCount:_currentPage+1):_currentPage;
                      
            }
        
            
            flipLayerIndex=[_flipLayers indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
                return [obj flipIndex]==flipIndex;
            }]; 
            
            _touchedLayer=[_flipLayers objectAtIndex:flipLayerIndex];
            
            if(!self.isContinuousFlipEnabled &&[_flipingLayers count]>0 && _touchedLayer!=[_flipingLayers lastObject])
            {
                _touchedLayer=nil;
                return;
            }
            
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            
            if([_touchedLayer animationForKey:ANIMATION_LEY])
            {
                _touchedLayer.transform=((CALayer *)_touchedLayer.presentationLayer).transform;
                [_touchedLayer removeAllAnimations];
            }
            
            if([_touchedLayer.frontShadow animationForKey:SHADOW_ANIMATION])
            {
                _touchedLayer.frontShadow.opacity=0;
                [_touchedLayer.frontShadow removeAllAnimations];
            }
        
            if([_touchedLayer.backShadow animationForKey:SHADOW_ANIMATION])
            {
                _touchedLayer.backShadow.opacity=0;
                [_touchedLayer.backShadow removeAllAnimations];
            }
            
            if(flipLayerIndex+1<=[_flipLayers count]-1)
            {
                _nextLayer=[_flipLayers objectAtIndex:flipLayerIndex+1];
                _nextLayer.frontShadow.opacity=0;
                _nextLayer.backShadow.opacity=0;
                [_nextLayer.frontShadow removeAllAnimations];
                [_nextLayer.backShadow removeAllAnimations];
            }
            
            if(flipLayerIndex-1>=0)
            {
                _preLayer=[_flipLayers objectAtIndex:flipLayerIndex-1];
                _preLayer.frontShadow.opacity=0;
                _preLayer.backShadow.opacity=0;
                [_preLayer.frontShadow removeAllAnimations];
                [_preLayer.backShadow removeAllAnimations];
            }
            
            [CATransaction commit];
        }
        
        if(![_flipingLayers containsObject:_touchedLayer])
           [_flipingLayers addObject:_touchedLayer];
                
        if(_touchTime>0.13f)
        {  
            float diffAngle=-_pixelToAngle*_lastTouchDistance;
            float targetAngle=[[_touchedLayer valueForKeyPath:@"transform.rotation.x"] floatValue]+diffAngle;
                
            if((_touchedLayer.flipIndex==0 && targetAngle<_maxAngle-_restrictAngle) || (_touchedLayer.flipIndex==_pageCount && targetAngle>_restrictAngle))
                return;
            
            if(targetAngle>_maxAngle-_touchedLayer.flipIndex*_rotateFactor)
                targetAngle=_maxAngle-_touchedLayer.flipIndex*_rotateFactor;
            else if(targetAngle<0)
                targetAngle=_minAngle;
            
            CATransform3D transform=CATransform3DIdentity;
            transform.m34=-1.0f/_perspective;  
            
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            _touchedLayer.transform=CATransform3DRotate(transform,targetAngle, 1, 0, 0);  
            
            if(_isShadowEnable && targetAngle<=_maxAngle/2)
            {
                if(_nextLayer)
                {
                    float shadowAlpha=_maxShadowAlpha-targetAngle*_angleToAlpha;

                    [_nextLayer.frontShadow removeAllAnimations];
                    _nextLayer.frontShadow.opacity=shadowAlpha;
                }
        
                _preLayer.backShadow.opacity=0;
            }
            else if(_isShadowEnable && targetAngle>_maxAngle/2)
            {
                if(_preLayer)
                {
                    float shadowAlpha=(targetAngle-_maxAngle/2)*_angleToAlpha;
                    [_preLayer.backShadow removeAllAnimations];
                    _preLayer.backShadow.opacity=shadowAlpha;
                }
                _nextLayer.frontShadow.opacity=0;
            }
            
            [CATransaction commit];
            
            if(_delegate && [_delegate respondsToSelector:@selector(flipView:didFlipWithAngle:)])
                [_delegate flipView:self didFlipWithAngle:targetAngle];
        }
        
        _preTouchPoint=currentPoint;
    }
}


- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{    
    if(!self.isFlipEnabled || [_flipLayers count]==0 || !_touchedLayer)
        return;
    
    if([touches count]==1  && _touchedLayer)
    {
        UITouch *touch=[touches anyObject];
        CGPoint currentPoint=[touch locationInView:touch.view]; 

        float touchDistance=currentPoint.y-_touchStartingPoint.y;
        NSTimeInterval endTouchTime=[NSDate timeIntervalSinceReferenceDate];
        _touchTime=endTouchTime-_startTouchTime;
        _prePage=_currentPage;
        
        if(_touchTime>0.2f)
        {
     
            if([[_touchedLayer valueForKeyPath:@"transform.rotation.x"] floatValue]>=_maxAngle/2)
            {
                [self flipLayer:_touchedLayer toDirection:_flipDirection animation:YES];
                _currentPage=_touchedLayer.flipIndex;
            }
            else 
            {
                [self flipLayer:_touchedLayer toDirection:-_flipDirection animation:YES];
                _currentPage=_touchedLayer.flipIndex-1;
            }
        }
        else
        {
            
            if(touchDistance>0 && _touchedLayer)  //drag down
            {
                [self flipLayer:_touchedLayer toDirection:_flipDirection==FlipDirectionUp?-_flipDirection:_flipDirection animation:YES];
                
                if(_flipDirection==FlipDirectionUp && _touchedLayer.flipIndex>0)
                    _currentPage=_touchedLayer.flipIndex-1;
                else if(_flipDirection==FlipDirectionDown)
                    _currentPage=_touchedLayer.flipIndex;
            }
            else if(touchDistance<0 && _touchedLayer)  //drag up
            {
                [self flipLayer:_touchedLayer toDirection:_flipDirection==FlipDirectionUp?_flipDirection:-_flipDirection animation:YES];
                
                if(_flipDirection==FlipDirectionUp && _touchedLayer.flipIndex<_pageCount)
                   _currentPage=_touchedLayer.flipIndex;
                else if(_flipDirection==FlipDirectionDown)
                    _currentPage=_touchedLayer.flipIndex-1;
            }
        }
        
        if(_needRecycle)
        {
            if(_currentPage-_prePage>0 && _currentPage>_recycleCount/2-1 && _currentPage<_pageCount-(_recycleCount/2-1))
            {
                 [self recycleFlipLayersWithDirection:_flipDirection];
            }
            else if(_currentPage-_prePage<0 && _currentPage>=_recycleCount/2-1 && _currentPage<_pageCount-(_recycleCount/2))
            {
                [self recycleFlipLayersWithDirection:-_flipDirection];
            }
        }
        
        if(_delegate && [_delegate respondsToSelector:@selector(flipViewDidEndDrag:)])
            [_delegate flipViewDidEndDrag:self];
        
        if(_delegate && [_delegate respondsToSelector:@selector(flipView:didFlipToPage:direction:)] && _currentPage!=_prePage)
            [_delegate flipView:self didFlipToPage:_currentPage direction:(_currentPage>_prePage?_flipDirection:-_flipDirection)];
          
        _touchedLayer=nil; 
        _nextLayer=nil;
        _preLayer=nil;
        _touchTime=0;  
    }
    _isTouchedDown=NO;
    _lastTouchDistance=0;
}


- (void)initFlipLayers
{
    [_flipingLayers makeObjectsPerformSelector:@selector(removeAllAnimations)];
    [_flipingLayers removeAllObjects];
    [_flipLayers removeAllObjects];
    [_contentLayer.sublayers makeObjectsPerformSelector:@selector(removeFromSuperlayer)];
    [_flipLayersQueue removeAllObjects];
    
    if(_delegate)
       _pageCount=[_delegate numberOfFlipPagesInFlipView:self];
    
    if(_pageCount==0)
        return;
    
    int toGenerateCount=_pageCount>_recycleCount-1?_recycleCount:(_pageCount+1);
    int startIndex,endIndex;
    if(_currentPage<2)
    {
        startIndex=0;
    }
    else if(_currentPage>_pageCount-3)
    {
       startIndex=_pageCount-toGenerateCount+1;
    }
    else 
    {
        startIndex=_currentPage-(_recycleCount/2-1);
    }
    
    endIndex=startIndex+toGenerateCount-1;
    _needRecycle=_pageCount>_recycleCount-1;
    
    for(int i=startIndex;i<=endIndex;i++)
    {
        FlipLayer *newLayer=[self generateTransformLayer]; 
        newLayer.flipIndex=i;
        [_flipLayers addObject:newLayer];   
        
        if(i<=_currentPage)
        {
            [self flipLayer:newLayer toDirection:_flipDirection animation:NO];
        }
    }
    
    for (int j=0; j<8; j++) {
        [_flipLayersQueue addObject:[self generateTransformLayer]];
    }
    
    for (int i=[_flipLayers count]-1; i>=0; i--) {
        [_contentLayer addSublayer:[_flipLayers objectAtIndex:i]];
    }

}

- (void)reloadPages
{
    [self initFlipLayers];
}

- (void)appendPages:(int)toAppendCount
{
    if(_pageCount==0)
        return;
    
    if(_currentPage>_pageCount-3)
    {
        int toAddFlipLayerCount= _recycleCount/2-1-(_pageCount-_currentPage-1);
        for(int i=0;i<toAddFlipLayerCount;i++)
        {
            [self recycleFlipLayersWithDirection:_flipDirection];
        }
        _pageCount+=toAppendCount;
    }
    
}

- (void)removePages
{
    [_flipingLayers makeObjectsPerformSelector:@selector(removeAllAnimations)];
    [_flipingLayers removeAllObjects];
    [_flipLayers makeObjectsPerformSelector:@selector(removeFromSuperlayer)];
    [_flipLayers removeAllObjects];

}

- (void)updateContents
{
    for (int i=0; i<[_flipLayers count]; i++) {
        [self generateContentForLayer:[_flipLayers objectAtIndex:i]];
    }
}

- (void)removeContents
{
    for (int i=0; i<[_flipLayers count]; i++) {
        FlipLayer *layer=[_flipLayers objectAtIndex:i];
        layer.front.contents=nil;
        layer.back.contents=nil;
    }
}

- (void)showFlip
{
    [self.layer addSublayer:_containerLayer];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _containerLayer.hidden=NO;
    [CATransaction commit];
}

- (void)hideFlip
{
    [_containerLayer removeFromSuperlayer];
    
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _containerLayer.hidden=YES;
    [CATransaction commit];
}


- (void)resetFlipLayer:(FlipLayer *)layer
{
    [layer removeAllAnimations]; 
    [layer.frontShadow removeAllAnimations];
    [layer.backShadow removeAllAnimations];
    layer.front.contents=nil;
    layer.back.contents=nil;
    
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    layer.frontShadow.opacity=0;
    layer.backShadow.opacity=0;
    layer.transform=CATransform3DIdentity;
    [CATransaction commit];
}

- (FlipLayer *)generateTransformLayer
{
    FlipLayer *layer=[FlipLayer layer];
    layer.frame=CGRectMake(0, _transformSize.height/2, _transformSize.width, _transformSize.height);
    layer.anchorPoint=_flipDirection==FlipDirectionUp?CGPointMake(0.5f, 0):CGPointMake(0.5f, 1);
    
    CALayer *frontLayer=[CALayer layer]; 
    frontLayer.opaque=YES;
    frontLayer.frame=CGRectMake(0, 0,_transformSize.width, _transformSize.height);
    frontLayer.doubleSided=NO;
    
    CALayer *backLayer=[CALayer layer];
    backLayer.opaque=YES;
    backLayer.frame=CGRectMake(0, 0,_transformSize.width, _transformSize.height);
    backLayer.transform=CATransform3DMakeScale(1, -1, 1);
    
    CALayer *frontShadow=[CALayer layer]; 
    frontShadow.frame=CGRectMake(0, 0,_transformSize.width, _transformSize.height);
    frontShadow.doubleSided=NO;
    frontShadow.backgroundColor=[UIColor blackColor].CGColor;
    frontShadow.opacity=0;
    
    CALayer *backShadow=[CALayer layer];
    backShadow.frame=CGRectMake(0, 0,_transformSize.width, _transformSize.height);
    backShadow.backgroundColor=[UIColor blackColor].CGColor;
    backShadow.opacity=0;
    backShadow.transform=CATransform3DMakeScale(1, -1, 1);
    
    layer.front=frontLayer;
    layer.back=backLayer;
    layer.frontShadow=frontShadow;
    layer.backShadow=backShadow;
    
    [layer addSublayer:backLayer];
    [layer addSublayer:backShadow];
    [layer addSublayer:frontLayer];
    [layer addSublayer:frontShadow];
    return layer;
}


- (void)generateContentForLayer:(FlipLayer *)layer
{
    int index=layer.flipIndex;
    int contentIndex,nextContentIndex;
    contentIndex=index-1;
    nextContentIndex=contentIndex+1;
    
    UIImage *content, *nextContent;
    if(contentIndex>=0)
        content=[_delegate flipView:self contentForFlipAtPageIndex:contentIndex];
    
    if(nextContentIndex<_pageCount)
        nextContent=[_delegate flipView:self contentForFlipAtPageIndex:nextContentIndex];
    
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    
    if(index>0)
    {
        CGImageRef frontImage=CGImageCreateWithImageInRect(content?content.CGImage:_defaultImage.CGImage,_frontClipRect);
        layer.front.contents=(id)frontImage;
        CGImageRelease(frontImage);
        
        if (nextContentIndex<_pageCount) {
            CGImageRef backImage=CGImageCreateWithImageInRect(nextContent?nextContent.CGImage:_defaultImage.CGImage, _backClipRect);
            layer.back.contents=(id)backImage;
            CGImageRelease(backImage);
        }
        else {
            layer.back.contents=(id)_defaultImage.CGImage;
        }
        
    }
    else
    {
        layer.front.contents=(id)_defaultImage.CGImage;
        CGImageRef backImage=CGImageCreateWithImageInRect(nextContent?nextContent.CGImage:_defaultImage.CGImage, _backClipRect);
        layer.back.contents=(id)backImage;
        CGImageRelease(backImage);
    }
    
    [CATransaction commit];

}

- (void)recycleFlipLayersWithDirection:(FlipDirection)direction
{
    if(direction==_flipDirection)
    {
        FlipLayer *newLayer=[_flipLayersQueue objectAtIndex:0];
        newLayer.flipIndex=_currentPage+_recycleCount/2; 
        
        [_flipLayers addObject:newLayer];
        [_flipLayersQueue removeObjectAtIndex:0];
        [self generateContentForLayer:newLayer];
        
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        [_contentLayer insertSublayer:newLayer atIndex:0];

        FlipLayer *toRemoveLayer=[_flipLayers objectAtIndex:0];
        [toRemoveLayer removeFromSuperlayer];
        [CATransaction commit];
        
        [self resetFlipLayer:toRemoveLayer];          
        [_flipLayersQueue addObject:toRemoveLayer];
        [_flipLayers removeObjectAtIndex:0];
    }
    else
    {
        FlipLayer *newLayer=[_flipLayersQueue objectAtIndex:0];
        newLayer.flipIndex=_currentPage-(_recycleCount/2-1); 
        [_flipLayers insertObject:newLayer atIndex:0];
        [_flipLayersQueue removeObjectAtIndex:0];
        [self generateContentForLayer:newLayer];
        
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        [_contentLayer addSublayer:newLayer];
        [self flipLayer:newLayer toDirection:_flipDirection animation:NO];
        
        FlipLayer *toRemoveLayer=[_flipLayers lastObject];
        [toRemoveLayer removeFromSuperlayer];
        [CATransaction commit];
        
        [self resetFlipLayer:toRemoveLayer];          
        [_flipLayersQueue addObject:toRemoveLayer];
        [_flipLayers removeLastObject];
    }

}

- (void)flipLayer:(FlipLayer *)layer toDirection:(FlipDirection)direction animation:(BOOL)isAnimation
{       
    if(!layer)
        return;
    
    if(direction==_flipDirection)
        layer.isFlipped=YES;
    else 
        layer.isFlipped=NO;
    
    float angle;
    if(direction==_flipDirection)
        angle=_maxAngle-layer.flipIndex*_rotateFactor;
    else 
        angle=_minAngle;
    
    CATransform3D transform=CATransform3DIdentity;
    transform.m34=-1.0f/_perspective;   
    
    float currentAngle=[[layer valueForKeyPath:@"transform.rotation.x"] floatValue];
    
    if(isAnimation)
    {
        float duration;
        if(fabs(currentAngle-angle)<=_maxAngle/2)
            duration=_flipTime;
        else
            duration=direction==_flipDirection?_flipTime*(1-currentAngle/_maxAngle):_flipTime*currentAngle/_maxAngle;
        
        if((layer.flipIndex==0 && angle==_minAngle) || (layer.flipIndex==_pageCount && angle!=_minAngle))
        {
            float backAngle=layer.flipIndex==0?_maxAngle-layer.flipIndex*_rotateFactor:_minAngle;
            
            CAKeyframeAnimation *flipAnimation=[CAKeyframeAnimation animationWithKeyPath:@"transform"];
            float totalDuration=0.5f;
            flipAnimation.duration=totalDuration;
            flipAnimation.removedOnCompletion=NO;
            flipAnimation.fillMode=kCAFillModeForwards;
            flipAnimation.delegate=self;
             angle=direction==_flipDirection?_restrictAngle*0.5f:_maxAngle-_restrictAngle*0.5f;
            
            flipAnimation.keyTimes=[NSArray arrayWithObjects:[NSNumber numberWithFloat:0],[NSNumber numberWithFloat:0.35f],[NSNumber numberWithFloat:1], nil];
            
            flipAnimation.timingFunctions=[NSArray arrayWithObjects:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut],[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn], nil];
            
            flipAnimation.values=[NSArray arrayWithObjects:[NSValue valueWithCATransform3D:CATransform3DRotate(transform, currentAngle, 1, 0, 0)],[NSValue valueWithCATransform3D:CATransform3DRotate(transform, angle , 1, 0, 0)],[NSValue valueWithCATransform3D:CATransform3DRotate(transform,backAngle , 1, 0, 0)], nil];
            
            [layer addAnimation:flipAnimation forKey:ANIMATION_LEY];
            return;
        }
        else if(!_isBounce)
        {
            CABasicAnimation *flipAnimation=[CABasicAnimation animationWithKeyPath:@"transform"]; 
            flipAnimation.duration=duration;
            flipAnimation.timingFunction=[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
            flipAnimation.removedOnCompletion=NO;
            flipAnimation.toValue=[NSValue valueWithCATransform3D:CATransform3DRotate(transform, angle , 1, 0, 0)];
            flipAnimation.fillMode=kCAFillModeForwards;
            flipAnimation.delegate=self;
            [layer addAnimation:flipAnimation forKey:ANIMATION_LEY];
        }
        else
        {
            CAKeyframeAnimation *flipAnimation=[CAKeyframeAnimation animationWithKeyPath:@"transform"];
            float totalDuration=duration+_bounceTime*1.7f;
            flipAnimation.duration=totalDuration;
            flipAnimation.removedOnCompletion=NO;
            flipAnimation.fillMode=kCAFillModeForwards;
            flipAnimation.delegate=self;
            
            flipAnimation.keyTimes=[NSArray arrayWithObjects:[NSNumber numberWithFloat:0],[NSNumber numberWithFloat:duration/totalDuration],[NSNumber numberWithFloat:(duration+_bounceTime)/totalDuration],[NSNumber numberWithFloat:1], nil];
            
            flipAnimation.timingFunctions=[NSArray arrayWithObjects:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn],[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut],[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn], nil];
            
            flipAnimation.values=[NSArray arrayWithObjects:[NSValue valueWithCATransform3D:CATransform3DRotate(transform, currentAngle, 1, 0, 0)],[NSValue valueWithCATransform3D:CATransform3DRotate(transform, angle , 1, 0, 0)],[NSValue valueWithCATransform3D:CATransform3DRotate(transform,angle==0?_bounceAngle:angle-_bounceAngle , 1, 0, 0)],[NSValue valueWithCATransform3D:CATransform3DRotate(transform, angle , 1, 0, 0)], nil];
            [layer addAnimation:flipAnimation forKey:ANIMATION_LEY];
        }
        
        if(_isShadowEnable)
        {
            int currentIndex=[_flipLayers indexOfObject:layer];
            
            if(direction==_flipDirection)
            {
                if(currentAngle<_maxAngle/2)
                {
                    if(currentIndex+1<=[_flipLayers count]-1)
                    {
                        FlipLayer *nextLayer=[_flipLayers objectAtIndex:currentIndex+1];
                        
                        CABasicAnimation *shadowAnimation=[CABasicAnimation animationWithKeyPath:@"opacity"]; 
                        shadowAnimation.duration=_flipTime/2;
                        shadowAnimation.toValue=[NSNumber numberWithFloat:0];
                        shadowAnimation.fillMode=kCAFillModeForwards;
                        shadowAnimation.removedOnCompletion=NO;
                        [nextLayer.frontShadow addAnimation:shadowAnimation forKey:SHADOW_ANIMATION];
                    }
                }
                
                if(currentIndex-1>=0)
                {
                    FlipLayer *preLayer=[_flipLayers objectAtIndex:currentIndex-1];
                    
                    CABasicAnimation *shadowAnimation=[CABasicAnimation animationWithKeyPath:@"opacity"]; 
                    shadowAnimation.duration=_flipTime;
                    if(currentAngle<_maxAngle/2)
                        shadowAnimation.beginTime=CACurrentMediaTime()+_flipTime/2;
                    shadowAnimation.toValue=[NSNumber numberWithFloat:_maxShadowAlpha];
                    shadowAnimation.fillMode=kCAFillModeForwards;
                    shadowAnimation.removedOnCompletion=NO;
                    [preLayer.backShadow addAnimation:shadowAnimation forKey:SHADOW_ANIMATION];
                    
                }
            }
            else 
            {
                if(currentAngle>_maxAngle/2)
                {
                    if(currentIndex-1>=0)
                    {
                        FlipLayer *preLayer=[_flipLayers objectAtIndex:currentIndex-1];
                        
                        CABasicAnimation *shadowAnimation=[CABasicAnimation animationWithKeyPath:@"opacity"]; 
                        shadowAnimation.duration=_flipTime/2;
                        shadowAnimation.toValue=[NSNumber numberWithFloat:0];
                        shadowAnimation.fillMode=kCAFillModeForwards;
                        shadowAnimation.removedOnCompletion=NO;
                        [preLayer.backShadow addAnimation:shadowAnimation forKey:SHADOW_ANIMATION];
                    }
                }
                
                if(currentIndex+1<=[_flipLayers count]-1)
                {
                    FlipLayer *nextLayer=[_flipLayers objectAtIndex:currentIndex+1];
                    
                    CABasicAnimation *shadowAnimation=[CABasicAnimation animationWithKeyPath:@"opacity"]; 
                    shadowAnimation.duration=_flipTime;
                    if(currentAngle>_maxAngle/2)
                        shadowAnimation.beginTime=CACurrentMediaTime()+_flipTime/2;
                    shadowAnimation.toValue=[NSNumber numberWithFloat:_maxShadowAlpha];
                    shadowAnimation.fillMode=kCAFillModeForwards;
                    shadowAnimation.removedOnCompletion=NO;
                    [nextLayer.frontShadow addAnimation:shadowAnimation forKey:SHADOW_ANIMATION];
                    
                }
            }
        }
       
    }
    else {
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        layer.transform=CATransform3DRotate(transform, angle , 1, 0, 0);
        layer.frontShadow.opacity=0;
        layer.backShadow.opacity=0;
        [CATransaction commit];
        [_flipingLayers removeObject:layer];
        
    }
}

- (void)flipToNextPageWithAnimation:(BOOL)isAnimation
{
    if(_currentPage==_pageCount-1)
        return;
    
    int  flipIndex=_currentPage+1;
    int flipLayerIndex=[_flipLayers indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
        return [obj flipIndex]==flipIndex;
    }]; 
    
    CALayer *layer=[_flipLayers objectAtIndex:flipLayerIndex];
    [_flipingLayers addObject:layer];
    [self flipLayer:layer toDirection:_flipDirection animation:isAnimation];
    _prePage=_currentPage;
    _currentPage++;
    if(_needRecycle && _currentPage>_recycleCount/2-1 && _currentPage<_pageCount-(_recycleCount/2-1))
        [self recycleFlipLayersWithDirection:_flipDirection];
    
    if(_delegate && [_delegate respondsToSelector:@selector(flipView:didFlipToPage:direction:)] && _currentPage!=_prePage)
        [_delegate flipView:self didFlipToPage:_currentPage direction:(_currentPage>_prePage?_flipDirection:-_flipDirection)];
}

- (void)flipToNextWithAnimation:(NSNumber *)isAnimation
{
    [self flipToNextPageWithAnimation:[isAnimation boolValue]];
}


- (void)flipToPrePageWithAnimation:(BOOL)isAnimation
{
    if(_currentPage==0)
        return;
    
    int  flipIndex=_currentPage;
    int flipLayerIndex=[_flipLayers indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
        return [obj flipIndex]==flipIndex;
    }]; 
    
    CALayer *layer=[_flipLayers objectAtIndex:flipLayerIndex];
    [_flipingLayers addObject:layer];
    [self flipLayer:layer toDirection:-_flipDirection animation:isAnimation];
    _prePage=_currentPage;
    _currentPage--;
    if(_needRecycle && _currentPage>=_recycleCount/2-1 && _currentPage<_pageCount-(_recycleCount/2))
        [self recycleFlipLayersWithDirection:-_flipDirection];
    
    if(_delegate && [_delegate respondsToSelector:@selector(flipView:didFlipToPage:direction:)] && _currentPage!=_prePage)
        [_delegate flipView:self didFlipToPage:_currentPage direction:(_currentPage>_prePage?_flipDirection:-_flipDirection)];

}

- (void)flipToPreWithAnimation:(NSNumber *)isAnimation
{
    [self flipToPrePageWithAnimation:[isAnimation boolValue]];
}

- (void)flipToLastPageWithAnimation:(BOOL)isAnimation
{
    [self flipToPage:_pageCount-1 isAnimation:isAnimation];
}

- (void)flipToFirstPageWithAnimation:(BOOL)isAnimation
{
    [self flipToPage:0 isAnimation:YES];
}

- (void)flipToPage:(int)pageIndex isAnimation:(BOOL)isAnimation
{
    if(pageIndex==_currentPage)
        return;
    
    int count =abs(pageIndex-_currentPage);
    
    if(pageIndex>_currentPage)
    {
        for (int i=0; i<count; i++) {
            [self performSelector:@selector(flipToNextWithAnimation:) withObject:[NSNumber numberWithBool:isAnimation] afterDelay:i*0.165f];
        }
    }
    else {
        for (int i=0; i<count; i++) {
            [self performSelector:@selector(flipToPreWithAnimation:) withObject:[NSNumber numberWithBool:isAnimation] afterDelay:i*0.165f];
        }
    }
}


//Animation Delegate
- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag
{      
   if(flag)
   {
       FlipLayer *layer=[_flipingLayers objectAtIndex:0];
       [CATransaction setDisableActions:YES];
       layer.transform=((CALayer *)layer.presentationLayer).transform;
       layer.frontShadow.opacity=0;
       layer.backShadow.opacity=0;
       [CATransaction commit];
       [layer removeAllAnimations];
      
       [_flipingLayers removeObjectAtIndex:0];
       
       if([_flipingLayers count]>0)
           return;
       
       if(_delegate && [_delegate respondsToSelector:@selector(flipView:didFinishFlipWithDirection:)])
           [_delegate flipView:self didFinishFlipWithDirection:_currentPage==_prePage?FlipDirectionNone:(_currentPage>_prePage?_flipDirection:-_flipDirection)];
   }
}

@end
