//
//  ViewController.m
//  camera
//
//  Created by wld on 23.03.2013.
//  Copyright (c) 2013 Vlad Burlaciuc. All rights reserved.
//      rtmp://code932.dyndns.org/live
//      http://code932.dyndns.org:9998/publisher/

#import "ViewController.h"

@interface ViewController ()
@property (readwrite, getter=isRecording) BOOL recording;
@end

@implementation ViewController
@synthesize recording;
@synthesize PreviewLayer;

- (void)viewDidLoad{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}
-(void)viewWillAppear:(BOOL)animated{
    [self setupAndStartCaptureSession];
    numberOfSubMovie=0;
    flashLight=NO;
    nrOfFrame=0;
    inregistreaza=NO;
}
- (void)didReceiveMemoryWarning{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
- (void)showError:(NSError *)error{ NSLog(@"show error");
    CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopCommonModes, ^(void) {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[error localizedDescription]
                                                            message:[error localizedFailureReason]
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
        [alertView show];
        
    });
}
- (void)removeFile:(NSURL *)fileURL{ NSLog(@"removeFile");
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *filePath = [fileURL path];
    if ([fileManager fileExistsAtPath:filePath]) {
        NSError *error;
       [fileManager removeItemAtPath:filePath error:&error];
    }
}
- (CVPixelBufferRef) pixelBufferFromCGImage: (CGImageRef) image{
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey,
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey,
                             nil];
    CVPixelBufferRef pxbuffer = NULL;
    CVPixelBufferCreate(kCFAllocatorDefault, CGImageGetWidth(image),
                        CGImageGetHeight(image), kCVPixelFormatType_32ARGB, (CFDictionaryRef) CFBridgingRetain(options),
                        &pxbuffer);
    CVPixelBufferLockBaseAddress(pxbuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pxdata, CGImageGetWidth(image),
                                                 CGImageGetHeight(image), 8, 4*CGImageGetWidth(image), rgbColorSpace,
                                                 kCGImageAlphaNoneSkipFirst);
    
    CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(image), CGImageGetHeight(image)), image);
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
    return pxbuffer;
}

- (void)rotatePixelBuffer: (CVImageBufferRef)pixelBuffer{
    
    CVPixelBufferLockBaseAddress(pixelBuffer,0);
    
	int bufferWidth = CVPixelBufferGetWidth(pixelBuffer);
	int bufferHeight = CVPixelBufferGetHeight(pixelBuffer);
	unsigned char *pixel = (unsigned char *)CVPixelBufferGetBaseAddress(pixelBuffer);
    
    
    for (int i=0; i<bufferHeight/2;i++) {
        unsigned char *pixelSus=pixel;
        pixelSus +=i*bufferWidth*BYTES_PER_PIXEL;
        unsigned char *pixelJos=pixel;
        pixelJos +=(bufferHeight-i-1)*bufferWidth*BYTES_PER_PIXEL;
        for (int j=0; j<bufferWidth; j++) {
            int sw0=pixelSus[0];
            int sw1=pixelSus[1];
            int sw2=pixelSus[2];
            int sw3=pixelSus[3];
            
            pixelSus[0]=pixelJos[0];
            pixelSus[1]=pixelJos[1];
            pixelSus[2]=pixelJos[2];
            pixelSus[3]=pixelJos[3];
            
            pixelJos[0]=sw0;
            pixelJos[1]=sw1;
            pixelJos[2]=sw2;
            pixelJos[3]=sw3;
            
            pixelSus+=BYTES_PER_PIXEL;
            pixelJos+=BYTES_PER_PIXEL;
            
        }
    }
	CVPixelBufferUnlockBaseAddress( pixelBuffer, 0 );
}
- (void) writeSampleBuffer:(CMSampleBufferRef)sampleBuffer ofType:(NSString *)mediaType{
	if ( assetWriter.status == AVAssetWriterStatusUnknown ) {
		
        if ([assetWriter startWriting]) {
			[assetWriter startSessionAtSourceTime:CMSampleBufferGetPresentationTimeStamp(sampleBuffer)];
		}
		else {
			[self showError:[assetWriter error]];
		}
	}
	
	if ( assetWriter.status == AVAssetWriterStatusWriting ) {
		if (mediaType == AVMediaTypeVideo) {
			if (assetWriterVideoIn.readyForMoreMediaData) {
                CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
                if (flashButton.enabled==false) {
                    [self rotatePixelBuffer:pixelBuffer];
                }
                
                //[self addOverlay:pixelBuffer ];
				if (![assetWriterVideoIn appendSampleBuffer:sampleBuffer]) {
					[self showError:[assetWriter error]];
				}
			}
		}
		else if (mediaType == AVMediaTypeAudio) {
			if (assetWriterAudioIn.readyForMoreMediaData) {
				if (![assetWriterAudioIn appendSampleBuffer:sampleBuffer]) {
					[self showError:[assetWriter error]];
				}
			}
		}
	}
}
- (BOOL) setupAssetWriterAudioInput:(CMFormatDescriptionRef)currentFormatDescription{
	const AudioStreamBasicDescription *currentASBD = CMAudioFormatDescriptionGetStreamBasicDescription(currentFormatDescription);
    
	size_t aclSize = 0;
	const AudioChannelLayout *currentChannelLayout = CMAudioFormatDescriptionGetChannelLayout(currentFormatDescription, &aclSize);
	NSData *currentChannelLayoutData = nil;
	
	// AVChannelLayoutKey must be specified, but if we don't know any better give an empty data and let AVAssetWriter decide.
	if ( currentChannelLayout && aclSize > 0 )
		currentChannelLayoutData = [NSData dataWithBytes:currentChannelLayout length:aclSize];
	else
		currentChannelLayoutData = [NSData data];
	
	NSDictionary *audioCompressionSettings = [NSDictionary dictionaryWithObjectsAndKeys:
											  [NSNumber numberWithInteger:kAudioFormatMPEG4AAC], AVFormatIDKey,
											  [NSNumber numberWithFloat:currentASBD->mSampleRate], AVSampleRateKey,
											  [NSNumber numberWithInt:64000], AVEncoderBitRatePerChannelKey,
											  [NSNumber numberWithInteger:currentASBD->mChannelsPerFrame], AVNumberOfChannelsKey,
											  currentChannelLayoutData, AVChannelLayoutKey,
											  nil];
	if ([assetWriter canApplyOutputSettings:audioCompressionSettings forMediaType:AVMediaTypeAudio]) {
		assetWriterAudioIn = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio outputSettings:audioCompressionSettings];
		assetWriterAudioIn.expectsMediaDataInRealTime = YES;
		if ([assetWriter canAddInput:assetWriterAudioIn])
			[assetWriter addInput:assetWriterAudioIn];
		else {
			NSLog(@"Couldn't add asset writer audio input.");
            return NO;
		}
	}
	else {
		NSLog(@"Couldn't apply audio output settings.");
        return NO;
	}
    
    return YES;
}
- (BOOL) setupAssetWriterVideoInput:(CMFormatDescriptionRef)currentFormatDescription{
	float bitsPerPixel;
	CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(currentFormatDescription);
	int numPixels = dimensions.width * dimensions.height;
    
	
	// Assume that lower-than-SD resolutions are intended for streaming, and use a lower bitrate
	//if ( numPixels < (640 * 480) )
    bitsPerPixel = 3.0; // This bitrate matches the quality produced by AVCaptureSessionPresetMedium or Low.
    //	else
    //		bitsPerPixel = 11.4; // This bitrate matches the quality produced by AVCaptureSessionPresetHigh.
	
	int bitsPerSecond = numPixels * bitsPerPixel;
	NSLog(@"compresie facuta %d",bitsPerSecond);
	NSDictionary *videoCompressionSettings = [NSDictionary dictionaryWithObjectsAndKeys:
											  AVVideoCodecH264, AVVideoCodecKey,
											  [NSNumber numberWithInteger:dimensions.width], AVVideoWidthKey,
											  [NSNumber numberWithInteger:dimensions.height], AVVideoHeightKey,
											  [NSDictionary dictionaryWithObjectsAndKeys:
											   [NSNumber numberWithInteger:bitsPerSecond], AVVideoAverageBitRateKey,
											   [NSNumber numberWithInteger:30], AVVideoMaxKeyFrameIntervalKey,
											   nil], AVVideoCompressionPropertiesKey,
											  nil];
	if ([assetWriter canApplyOutputSettings:videoCompressionSettings forMediaType:AVMediaTypeVideo]) {
		assetWriterVideoIn = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:videoCompressionSettings];
		assetWriterVideoIn.expectsMediaDataInRealTime = YES;
		if ([assetWriter canAddInput:assetWriterVideoIn])
			[assetWriter addInput:assetWriterVideoIn];
		else {
			NSLog(@"Couldn't add asset writer video input.");
            return NO;
		}
	}
	else {
		NSLog(@"Couldn't apply video output settings.");
        return NO;
	}
    
    return YES;
}

- (void) startRecording{
	dispatch_async(movieWritingQueue, ^{
        
		if ( recordingWillBeStarted || recording )
			return;
        
		recordingWillBeStarted = YES;
        NSString *outputPath=[NSString stringWithFormat:@"%@%d.mp4",NSTemporaryDirectory(),numberOfSubMovie];
        movieURL=[[NSURL alloc] initFileURLWithPath:outputPath];
        [self removeFile:movieURL];
        
		// Create an asset writer
		NSError *error;
        
		assetWriter = [[AVAssetWriter alloc] initWithURL:movieURL fileType:AVFileTypeMPEG4 error:&error];
		if (error)
			[self showError:error];
	});
}
- (void) stopRecording{
    dispatch_async(movieWritingQueue, ^{
		
		if ( recordingWillBeStopped || (recording == NO) )
			return;
        NSLog(@"%@",[movieURL path]);
        
		recordingWillBeStopped = YES;
		
        
		if ([assetWriter finishWriting]) {
            
			assetWriter = nil;
            numberOfSubMovie++;
            readyToRecordVideo = NO;
			readyToRecordAudio = NO;
            recordingWillBeStopped = NO;
            recording = NO;
		}
		else {
			[self showError:[assetWriter error]];
		}
	});
}


- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{
 	CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
  	CFRetain(sampleBuffer);
	CFRetain(formatDescription);
	dispatch_async(movieWritingQueue, ^{
        
		if ( assetWriter ) {
            
			BOOL wasReadyToRecord = (readyToRecordAudio && readyToRecordVideo);
			
			if (connection == videoConnection) {
				// Initialize the video input if this is not done yet
				if (!readyToRecordVideo)
					readyToRecordVideo = [self setupAssetWriterVideoInput:formatDescription];
				
				// Write video data to file
				if (readyToRecordVideo && readyToRecordAudio)
					[self writeSampleBuffer:sampleBuffer ofType:AVMediaTypeVideo];
			}
			else if (connection == audioConnection) {
				// Initialize the audio input if this is not done yet
				if (!readyToRecordAudio)
					readyToRecordAudio = [self setupAssetWriterAudioInput:formatDescription];
				// Write audio data to file
				if (readyToRecordAudio && readyToRecordVideo)
					[self writeSampleBuffer:sampleBuffer ofType:AVMediaTypeAudio];
			}
			BOOL isReadyToRecord = (readyToRecordAudio && readyToRecordVideo);
			if ( !wasReadyToRecord && isReadyToRecord ) {
				recordingWillBeStarted = NO;
				recording = YES;
			}
		}
		CFRelease(sampleBuffer);
		CFRelease(formatDescription);
 
        });
}
- (AVCaptureDevice *)videoDeviceWithPosition:(AVCaptureDevicePosition)position{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices)
        if ([device position] == position)
            return device;
    
    return nil;
}
- (AVCaptureDevice *)audioDevice{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio];
    if ([devices count] > 0)
        return [devices objectAtIndex:0];
    
    return nil;
}
- (BOOL) setupCaptureSession{
    
    CaptureSession = [[AVCaptureSession alloc] init];
    
    
    videoIn = [[AVCaptureDeviceInput alloc] initWithDevice:[self videoDeviceWithPosition:AVCaptureDevicePositionBack] error:nil];
    flashButton.enabled=true;
    if ([CaptureSession canAddInput:videoIn])
        [CaptureSession addInput:videoIn];
    
    
    AVCaptureDeviceInput *audioIn = [[AVCaptureDeviceInput alloc] initWithDevice:[self audioDevice] error:nil];
    if ([CaptureSession canAddInput:audioIn])
        [CaptureSession addInput:audioIn];
    
    [self setPreviewLayer:[[AVCaptureVideoPreviewLayer alloc] initWithSession:CaptureSession]];
	[[self PreviewLayer] setVideoGravity:AVLayerVideoGravityResizeAspect];
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   
    
	AVCaptureAudioDataOutput *audioOut = [[AVCaptureAudioDataOutput alloc] init];
	dispatch_queue_t audioCaptureQueue = dispatch_queue_create("Audio Capture Queue", DISPATCH_QUEUE_SERIAL);
	[audioOut setSampleBufferDelegate:self queue:audioCaptureQueue];
	dispatch_release(audioCaptureQueue);
	if ([CaptureSession canAddOutput:audioOut])
		[CaptureSession addOutput:audioOut];
	audioConnection = [audioOut connectionWithMediaType:AVMediaTypeAudio];
    
    
  
    
    
	videoOut = [[AVCaptureVideoDataOutput alloc] init];
	[videoOut setAlwaysDiscardsLateVideoFrames:YES];
	[videoOut setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
	dispatch_queue_t videoCaptureQueue = dispatch_queue_create("Video Capture Queue", DISPATCH_QUEUE_SERIAL);
	[videoOut setSampleBufferDelegate:self queue:videoCaptureQueue];
	dispatch_release(videoCaptureQueue);
	if ([CaptureSession canAddOutput:videoOut])
		[CaptureSession addOutput:videoOut];
	videoConnection = [videoOut connectionWithMediaType:AVMediaTypeVideo];
	videoOrientation = AVCaptureVideoOrientationLandscapeRight;
	[CaptureSession setSessionPreset:AVCaptureSessionPreset352x288];
    
    
    stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
    NSDictionary *outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys: AVVideoCodecJPEG, AVVideoCodecKey, nil];
    [stillImageOutput setOutputSettings:outputSettings];
    
    [CaptureSession addOutput:stillImageOutput];
    
    
    CGRect layerRect;
    layerRect=layerRect =CGRectMake(0, 0, self.view.frame.size.height, self.view.frame.size.width);
    [PreviewLayer setBounds:layerRect];
    [PreviewLayer setPosition:CGPointMake(CGRectGetMidX(layerRect), CGRectGetMidY(layerRect))];
    
    if ([PreviewLayer respondsToSelector:@selector(connection)])
    {
        if ([PreviewLayer.connection isVideoOrientationSupported])
        {
            [PreviewLayer.connection setVideoOrientation:AVCaptureVideoOrientationLandscapeRight];
            
            layerRect=layerRect =CGRectMake(0, 0, self.view.frame.size.height, self.view.frame.size.width);
            [PreviewLayer setBounds:layerRect];
            [PreviewLayer setPosition:CGPointMake(CGRectGetMidX(layerRect), CGRectGetMidY(layerRect))];
            
        }
    }
    else
    {
        // Deprecated in 6.0; here for backward compatibility
        if ([PreviewLayer isOrientationSupported])
        {
            [PreviewLayer setOrientation:AVCaptureVideoOrientationLandscapeRight];
            layerRect=layerRect =CGRectMake(0, 0, self.view.frame.size.height, self.view.frame.size.width);
            [PreviewLayer setBounds:layerRect];
            [PreviewLayer setPosition:CGPointMake(CGRectGetMidX(layerRect), CGRectGetMidY(layerRect))];
            
        }
    }

    UIView *CameraView = [[UIView alloc] init];
	[[self view] addSubview:CameraView];
	[self.view sendSubviewToBack:CameraView];
	[[CameraView layer] addSublayer:PreviewLayer];
   
	return YES;
}
- (void) setupAndStartCaptureSession{
	// Create a shallow queue for buffers going to the display for preview.
	OSStatus err = CMBufferQueueCreate(kCFAllocatorDefault, 1, CMBufferQueueGetCallbacksForUnsortedSampleBuffers(), &previewBufferQueue);
	if (err)
		[self showError:[NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil]];
	
	// Create serial queue for movie writing
	movieWritingQueue = dispatch_queue_create("Movie Writing Queue", DISPATCH_QUEUE_SERIAL);
	
    if ( !CaptureSession )
		[self setupCaptureSession];
	
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(captureSessionStoppedRunningNotification:) name:AVCaptureSessionDidStopRunningNotification object:CaptureSession];
	
	if ( !CaptureSession.isRunning )
		[CaptureSession startRunning];
}
- (void)captureSessionStoppedRunningNotification:(NSNotification *)notification{
	dispatch_async(movieWritingQueue, ^{
		if ( [self isRecording] ) {
			[self stopRecording];
		}
	});
}
- (void) stopAndTearDownCaptureSession{
    [CaptureSession stopRunning];
	if (CaptureSession)
		[[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureSessionDidStopRunningNotification object:CaptureSession];
	CaptureSession = nil;
	if (previewBufferQueue) {
		CFRelease(previewBufferQueue);
		previewBufferQueue = NULL;
	}
	if (movieWritingQueue) {
		//dispatch_release(movieWritingQueue);
		movieWritingQueue = NULL;
	}
}
- (void)viewDidUnload {
    flashButton = nil;
    viewPlayer = nil;
    back = nil;
    [super viewDidUnload];
}

- (IBAction)switchCamera:(id)sender
{ NSLog(@"switchCamera");
    if ([[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo] count] > 1)		//Only do if device has multiple cameras
    {
        NSLog(@"Toggle camera");
        NSError *error;
        AVCaptureDeviceInput *newPosition;
        AVCaptureDevicePosition position = [[videoIn device] position];
        if (position == AVCaptureDevicePositionBack)
        {
            flashButton.enabled=false;
            newPosition = [[AVCaptureDeviceInput alloc] initWithDevice:[self videoDeviceWithPosition:AVCaptureDevicePositionFront] error:&error];
        }
        else if (position == AVCaptureDevicePositionFront)
        {
            flashButton.enabled=true;
            newPosition = [[AVCaptureDeviceInput alloc] initWithDevice:[self videoDeviceWithPosition:AVCaptureDevicePositionBack] error:&error];
        }
        
        
        
        if (newPosition != nil)
        {
            [CaptureSession beginConfiguration];		//We can now change the inputs and output configuration.  Use commitConfiguration to end
            [CaptureSession removeInput:videoIn];
            if ([CaptureSession canAddInput:newPosition])
            {
                [CaptureSession addInput:newPosition];
                videoIn = newPosition;
            }
            else
            {
                [CaptureSession addInput:videoIn];
            }
            
            [CaptureSession commitConfiguration];
            videoConnection = [videoOut connectionWithMediaType:AVMediaTypeVideo];
            
        }
    }
    
}


- (IBAction)FlashLight:(id)sender {
    NSLog(@"FlashLight");
    AVCaptureDevice * captDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if ([captDevice hasFlash]&&[captDevice hasTorch]) {
        if (captDevice.torchMode == AVCaptureTorchModeOff) {
            flashLight=YES;
            [captDevice lockForConfiguration:nil];
            [captDevice setTorchMode:AVCaptureTorchModeOn];
            [captDevice unlockForConfiguration];
        }else {
            flashLight=NO;
            [captDevice lockForConfiguration:nil];
            [captDevice setTorchMode:AVCaptureTorchModeOff];
            [captDevice unlockForConfiguration];
        }
    }
}
- (IBAction)startDown:(id)sender {
    [UIView animateWithDuration:1.0 animations:^{
        [viewPlayer setAlpha:0.0];
    }];
    [player stop];
    [CaptureSession startRunning];
    [self startRecording];
    inregistreaza=YES;
}

- (IBAction)startUp:(id)sender {
    [self stopRecording];
    inregistreaza=NO;
}
-(IBAction)captureNow:(id)sender{
    videoConnectionPhoto = nil;
	for (AVCaptureConnection *connection in stillImageOutput.connections)
	{
		for (AVCaptureInputPort *port in [connection inputPorts])
		{
			if ([[port mediaType] isEqual:AVMediaTypeVideo] )
			{
				videoConnectionPhoto = connection;
				break;
			}
		}
		if (videoConnectionPhoto) { break; }
	}

    
	NSLog(@"about to request a capture from: %@", stillImageOutput);
    
	[stillImageOutput captureStillImageAsynchronouslyFromConnection:videoConnectionPhoto completionHandler: ^(CMSampleBufferRef imageSampleBuffer, NSError *error)
     {
         NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageSampleBuffer];
         UIImage *image = [[UIImage alloc] initWithData:imageData];
        
	 }];
}


-(IBAction)play:(id)sender {
    UIButton *but=sender;
    NSLog(@"merge");
    AVMutableComposition *_composition = [AVMutableComposition composition];
    
    for (int y=0;y<numberOfSubMovie;y++){
        NSString *inputPath=[NSString stringWithFormat:@"%@%d.mp4",NSTemporaryDirectory(),y];
        
        AVURLAsset* sourceAsset = nil;
        
        NSURL* moveURL = [NSURL fileURLWithPath:inputPath];
        sourceAsset = [AVURLAsset URLAssetWithURL:moveURL options:nil];
        
        // calculate time
        CMTimeRange editRange = CMTimeRangeMake(CMTimeMake(0, 600), sourceAsset.duration);
        
        NSError *editError;
        [_composition insertTimeRange:editRange ofAsset:sourceAsset atTime:_composition.duration error:&editError];
        
    }
    NSString *outputPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"mergeVideo.mp4"]];
    NSURL *outputURL = [[NSURL alloc] initFileURLWithPath:outputPath];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:outputPath]){
        NSError *error;
        if ([fileManager removeItemAtPath:outputPath error:&error] == NO){
            //Error - handle if requried
        }
    }
    AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:_composition presetName:AVAssetExportPresetPassthrough];
    exporter.outputFileType = AVFileTypeMPEG4;
    exporter.outputURL=outputURL;
    exporter.shouldOptimizeForNetworkUse = YES;
    [exporter exportAsynchronouslyWithCompletionHandler:^(void){
        dispatch_async(dispatch_get_main_queue(), ^{
            if (exporter.status==3) {
                if ([but.titleLabel.text isEqualToString: @"play"]) {
                    
                    NSLog(@"Export Complete %d %@", exporter.status, exporter.error);
                    player = [[MPMoviePlayerController alloc] initWithContentURL:outputURL];
                    [player setControlStyle:MPMovieControlStyleNone];
                    [player setRepeatMode:YES];
                    // derulare rapida
                    [player setInitialPlaybackTime:-1.0];
                    // [player setCurrentPlaybackRate:-1.0];
                    [player setShouldAutoplay:YES];
                    [[player view] setFrame:[viewPlayer bounds]];
                    [UIView animateWithDuration:1.0 animations:^{
                        [viewPlayer setAlpha:1.0];
                    }];
                    [CaptureSession stopRunning];
                    [viewPlayer addSubview:[player view]];
                    [player prepareToPlay];
                    [player play];
                    
                }
                else{
                    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
                    [library writeVideoAtPathToSavedPhotosAlbum:outputURL
                                                completionBlock:^(NSURL *assetURL, NSError *error) {
                                                    if (error)
                                                        [self showError:error];
                                                    else
                                                        [self removeFile:movieURL];
                                                    
                                                }];

                }
            }
        });
    }];
}


@end
