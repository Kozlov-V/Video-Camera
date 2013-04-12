//
//  ViewController.h
//  camera
//
//  Created by wld on 23.03.2013.
//  Copyright (c) 2013 Vlad Burlaciuc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreMedia/CMBufferQueue.h>
#import <MediaPlayer/MediaPlayer.h>

#define CAPTURE_FRAMES_PER_SECOND		50
#define BYTES_PER_PIXEL 4

@interface ViewController : UIViewController<AVCaptureAudioDataOutputSampleBufferDelegate, AVCaptureVideoDataOutputSampleBufferDelegate>{
    
    CMVideoDimensions videoDimensions;
	CMVideoCodecType videoType;
    
    AVCaptureDeviceInput *videoIn;
	AVCaptureSession *CaptureSession;
	AVCaptureConnection *audioConnection;
	AVCaptureConnection *videoConnection;
    AVCaptureConnection *videoConnectionPhoto;
	CMBufferQueueRef previewBufferQueue;
    AVCaptureStillImageOutput *stillImageOutput;
    MPMoviePlayerController *player;
    AVPlayer *playerAV;
    
    NSURL *movieURL;
    int numberOfSubMovie;
    AVCaptureVideoDataOutput *videoOut;
	AVAssetWriter *assetWriter;
	AVAssetWriterInput *assetWriterAudioIn;
	AVAssetWriterInput *assetWriterVideoIn;
	dispatch_queue_t movieWritingQueue;
    
	AVCaptureVideoOrientation referenceOrientation;
	AVCaptureVideoOrientation videoOrientation;

    IBOutlet UIButton *flashButton;
    BOOL readyToRecordAudio;
    BOOL readyToRecordVideo;
	BOOL recordingWillBeStarted;
	BOOL recordingWillBeStopped;
    BOOL recording;
    BOOL flashLight;
    IBOutlet UIView *viewPlayer;
    IBOutlet UIImageView *back;
    int nrOfFrame;
    BOOL inregistreaza;
    
}
@property (retain) AVCaptureVideoPreviewLayer *PreviewLayer;

- (IBAction)startDown:(id)sender;
- (IBAction)startUp:(id)sender;
- (IBAction)switchCamera:(id)sender;
- (IBAction)FlashLight:(id)sender;
- (IBAction)captureNow:(id)sender;
- (IBAction)play:(id)sender;
@end
