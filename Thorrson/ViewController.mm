//
//  ViewController.m
//  Thorrson
//
//  Created by Mijo Kaliger on 14/01/15.
//  Copyright (c) 2015 Grandson. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "GTPreviewView.h"
#import <opencv2/opencv.hpp>
#import "GTCaptureOutputUtils.h"

const int MAX_POINTS_COUNT = 10;
const int32_t MAX_FPS = 30;
const CGSize resolutionSize = CGSizeMake(1280, 720);

@interface ViewController () <AVCaptureVideoDataOutputSampleBufferDelegate,GTPreviewViewDelegate>
{
    AVCaptureSession                *_session;
    AVCaptureDevice                 *_device;
    IBOutlet GTPreviewView          *_previewView;
    IBOutlet UITapGestureRecognizer *_tapGestureRecognizer;
    IBOutlet UITapGestureRecognizer *_doubleTapGestureRecognizer;

    cv::Mat                     _currentFrame;
    cv::Mat                     _previousFrame;
    cv::Point2f                 _touchPoint;
    bool                        _addRemovePt;

    cv::vector<cv::Point2f>     _points[2];
    cv::Mat                     _image;
    cv::Size                    _winSize;
    cv::TermCriteria            _termcrit;
}
@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self setupCaptureSession];

    [self configureDevice:_device frameRate:MAX_FPS];

    _winSize = cv::Size(31,31);
    _termcrit = cv::TermCriteria(cv::TermCriteria::COUNT|cv::TermCriteria::EPS,20,0.03);

    [_tapGestureRecognizer requireGestureRecognizerToFail:_doubleTapGestureRecognizer];

    [self autoFocusAtPoint:self.view.center];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    [_previewView becomeFirstResponder];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    [_previewView resignFirstResponder];
}

- (BOOL)shouldAutorotate
{
    return NO;
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (void)dealloc
{
    [_session stopRunning];
}

// Create and configure a capture session and start it running
- (void)setupCaptureSession
{
    NSError *error = nil;

    // Create the session
    _session = [[AVCaptureSession alloc] init];

    // Configure the session to produce lower resolution video frames, if your
    // processing algorithm can cope. We'll specify medium quality for the
    // chosen device.
    _session.sessionPreset = AVCaptureSessionPreset1280x720;

    // Find a suitable AVCaptureDevice
    _device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];

    // Create a device input with the device and add it to the session.
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:_device
                                                                        error:&error];
    if (!input) {
        // Handling the error appropriately.
    }
    [_session addInput:input];

    AVCaptureVideoDataOutput *videoDataOutput = [AVCaptureVideoDataOutput new];
    NSDictionary *newSettings =
    @{ (NSString *)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange) };
    videoDataOutput.videoSettings = newSettings;

    // create a serial dispatch queue used for the sample buffer delegate as well as when a still image is captured
    // a serial dispatch queue must be used to guarantee that video frames will be delivered in order
    dispatch_queue_t videoDataOutputQueue = dispatch_queue_create("black.grandson.videodataoutputqueue", DISPATCH_QUEUE_SERIAL);
    [videoDataOutput setSampleBufferDelegate:self queue:videoDataOutputQueue];

    if ([_session canAddOutput:videoDataOutput])
    {
        [_session addOutput:videoDataOutput];
    }

    [self updateCaptureOrientation];

    // Start the session running to start the flow of data
    [_session startRunning];
}

// Delegate routine that is called when a sample buffer was written
- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    [GTCaptureOutputUtils convertYUVSampleBuffer:sampleBuffer toGrayscaleMat:_currentFrame];

    _currentFrame.copyTo(_image);

    [self opticalFlow];

    UIImage *imageToDisplay = [GTCaptureOutputUtils imageFromCvMat:&_image];

    dispatch_async(dispatch_get_main_queue(), ^{
        _previewView.image = imageToDisplay;
    });
}

- (void)opticalFlow
{
    if (!_points[0].empty())
    {
        cv::vector<uchar> status;
        cv::vector<float> err;

        if(_previousFrame.empty())
        {
            _currentFrame.copyTo(_previousFrame);
        }

        calcOpticalFlowPyrLK(_previousFrame, _currentFrame, _points[0],_points[1], status, err, _winSize, 3, _termcrit, 0, 0.001);

        size_t i, k;
        for(i = k = 0; i < _points[1].size(); i++)
        {
            if(_addRemovePt)
            {
                if(norm(_touchPoint - _points[1][i]) <= 5)
                {
                    _addRemovePt = false;
                    continue;
                }
            }

            if(!status[i])
                continue;

            _points[1][k++] = _points[1][i];
            circle(_image, _points[1][i], 10, cv::Scalar(0,255,0), -1, 8);

        }
        _points[1].resize(k);
    }

    if(_addRemovePt && _points[1].size() < (size_t)MAX_POINTS_COUNT)
    {
        cv::vector<cv::Point2f> tmp;
        tmp.push_back(_touchPoint);
        cornerSubPix( _currentFrame, tmp, _winSize, cv::Size(-1,-1), _termcrit);
        _points[1].push_back(tmp[0]);
        _addRemovePt = false;
    }

    std::swap(_points[1], _points[0]);
    cv::swap(_previousFrame, _currentFrame);
}

- (void)configureDevice:(AVCaptureDevice *)device frameRate:(int32_t)frameRate
{
    if ([device lockForConfiguration:NULL] == YES)
    {
        device.activeVideoMinFrameDuration = CMTimeMake(1, frameRate);
        device.activeVideoMaxFrameDuration = CMTimeMake(1, frameRate);
        [device unlockForConfiguration];
    }
}

- (void)updateCaptureOrientation
{
    AVCaptureConnection *captureConnection = [[[[_session outputs] firstObject] connections] firstObject];

    if ([captureConnection isVideoOrientationSupported])
    {
        UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
        [captureConnection setVideoOrientation:(AVCaptureVideoOrientation)orientation];
    }
}

- (void)autoFocusAtPoint:(CGPoint)point
{
    double focus_x = point.x/_previewView.bounds.size.width;
    double focus_y = point.y/_previewView.bounds.size.height;

    if([_device isFocusPointOfInterestSupported] && [_device isFocusModeSupported:AVCaptureFocusModeAutoFocus])
    {
        if([_device lockForConfiguration:NULL] == YES)
        {
            [_device setFocusPointOfInterest:CGPointMake(focus_x, focus_y)];
            [_device setFocusMode:AVCaptureFocusModeAutoFocus];
            [_device unlockForConfiguration];
        }
    }
}

- (void)cleanCirclesOfInterest
{
    _addRemovePt = false;
    
    _points[0].clear();
    _points[1].clear();
}

#pragma mark - Gesture recongnizer

- (IBAction)tap:(UITapGestureRecognizer *)sender
{
    CGPoint locationInView = [sender locationInView:_previewView];

    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];

    CGFloat scale = 0;

    if (UIInterfaceOrientationIsLandscape(orientation)) {
        scale = resolutionSize.width / _previewView.bounds.size.width;
    }
    else
    {
        scale = resolutionSize.height / _previewView.bounds.size.width;
    }

    _touchPoint = cv::Point2f(locationInView.x * scale,locationInView.y * scale);
    _addRemovePt = true;
}

- (IBAction)doubleTap:(UITapGestureRecognizer *)sender
{
    CGPoint locationInView = [sender locationInView:_previewView];

    [self autoFocusAtPoint:locationInView];
}

#pragma mark - GTPreviewViewDelegate

-(void)previewViewMotionShakeDetected
{
    [self cleanCirclesOfInterest];
}

@end
