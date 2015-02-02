//
//  GTPreviewView.h
//  Thorrson
//
//  Created by Mijo Kaliger on 22/01/15.
//  Copyright (c) 2015 Grandson. All rights reserved.
//

#import <UIKit/UIKit.h>

@class GTPreviewView;

@protocol GTPreviewViewDelegate <NSObject>
@optional
- (void)previewViewMotionShakeDetected;

@end

@interface GTPreviewView : UIImageView

@property (nonatomic,weak) IBOutlet id<GTPreviewViewDelegate>delegate;

@end
