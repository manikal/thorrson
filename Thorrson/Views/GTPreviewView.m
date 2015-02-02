//
//  GTPreviewView.m
//  Thorrson
//
//  Created by Mijo Kaliger on 22/01/15.
//  Copyright (c) 2015 Grandson. All rights reserved.
//

#import "GTPreviewView.h"
#import <AVFoundation/AVFoundation.h>


@implementation GTPreviewView

- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event
{
    if (event.subtype == UIEventSubtypeMotionShake)
    {
        if ([self.delegate respondsToSelector:@selector(previewViewMotionShakeDetected)])
        {
            [self.delegate previewViewMotionShakeDetected];
        }
    }

    if ([super respondsToSelector:@selector(motionEnded:withEvent:)])
        [super motionEnded:motion withEvent:event];
}

- (BOOL)canBecomeFirstResponder
{
    return YES;
}

@end
