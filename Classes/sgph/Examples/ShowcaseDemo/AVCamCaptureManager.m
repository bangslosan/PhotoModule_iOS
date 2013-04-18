/*
     File: AVCamCaptureManager.m
 Abstract: Code that calls the AVCapture classes to implement the camera-specific features in the app such as recording, still image, camera exposure, white balance and so on.
  Version: 1.0
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 Copyright (C) 2010 Apple Inc. All Rights Reserved.
 
 */

#import "AVCamCaptureManager.h"
#import "AVCamUtilities.h"
#import <MobileCoreServices/UTCoreTypes.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <ImageIO/CGImageProperties.h>
#import <CoreLocation/CoreLocation.h>
#import "Photo.h"

@interface AVCamCaptureManager (AVCaptureFileOutputRecordingDelegate) <AVCaptureFileOutputRecordingDelegate>
@end

@interface AVCamCaptureManager ()

@property (nonatomic,strong) AVCaptureSession *session;
@property (nonatomic,strong) AVCaptureDeviceInput *videoInput;
@property (nonatomic,strong) AVCaptureDeviceInput *audioInput;
@property (nonatomic,strong) AVCaptureMovieFileOutput *movieFileOutput;
@property (nonatomic,strong) AVCaptureStillImageOutput *stillImageOutput;
@property (nonatomic,strong) id deviceConnectedObserver;
@property (nonatomic,strong) id deviceDisconnectedObserver;
@property (nonatomic,assign) UIBackgroundTaskIdentifier backgroundRecordingID;
@property (nonatomic,strong) CLLocationManager *locationManager;

@end

@interface AVCamCaptureManager (Internal)

- (AVCaptureDevice *) cameraWithPosition:(AVCaptureDevicePosition)position;
- (AVCaptureDevice *) frontFacingCamera;
- (AVCaptureDevice *) backFacingCamera;
- (AVCaptureDevice *) audioDevice;
- (NSURL *) tempFileURL;

@end

@implementation AVCamCaptureManager

@synthesize session = _session;
@synthesize orientation = _orientation;
@dynamic audioChannel;
@dynamic sessionPreset;
@synthesize mirroringMode = _mirroringMode;
@synthesize videoInput = _videoInput;
@synthesize audioInput = _audioInput;
@dynamic flashMode;
@dynamic torchMode;
@dynamic focusMode;
@dynamic exposureMode;
@dynamic whiteBalanceMode;
@synthesize cameraZoom = _cameraZoom;
@synthesize viewportSize = _viewportSize;
@synthesize movieFileOutput = _movieFileOutput;
@synthesize stillImageOutput = _stillImageOutput;
@synthesize deviceConnectedObserver = _deviceConnectedObserver;
@synthesize deviceDisconnectedObserver = _deviceDisconnectedObserver;
@synthesize backgroundRecordingID = _backgroundRecordingID;
@synthesize delegate = _delegate;
@dynamic recording;
@synthesize filename = _filename;
@synthesize locationManager = _locationManager;

- (id) init
{
    self = [super init];
    if (self != nil)
    {
        __weak AVCamCaptureManager *weakSelf = self;

        void (^deviceConnectedBlock)(NSNotification *) = ^(NSNotification *notification) {
            AVCaptureSession *session = [weakSelf session];
            AVCaptureDeviceInput *newAudioInput = [[AVCaptureDeviceInput alloc] initWithDevice:[weakSelf audioDevice] error:nil];
            AVCaptureDeviceInput *newVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:[weakSelf backFacingCamera] error:nil];
            
            [session beginConfiguration];
            [session removeInput:[weakSelf audioInput]];
            if ([session canAddInput:newAudioInput]) {                
                [session addInput:newAudioInput];
            }
            [session removeInput:[weakSelf videoInput]];
            if ([session canAddInput:newVideoInput]) {
                [session addInput:newVideoInput];
            }
            [session commitConfiguration];
            
            [weakSelf setAudioInput:newAudioInput];
            //[newAudioInput release];
            newAudioInput = nil;
            [weakSelf setVideoInput:newVideoInput];
            //[newVideoInput release];
            newVideoInput = nil;
            
            id delegate = [weakSelf delegate];
            if ([delegate respondsToSelector:@selector(captureManagerDeviceConfigurationChanged)]) {
                [delegate captureManagerDeviceConfigurationChanged];
            }
            
            if (![session isRunning])
                [session startRunning];
        };
        void (^deviceDisconnectedBlock)(NSNotification *) = ^(NSNotification *notification) {
            AVCaptureSession *session = [weakSelf session];
            
            [session beginConfiguration];
            
            if (![[[weakSelf audioInput] device] isConnected])
                [session removeInput:[weakSelf audioInput]];
            if (![[[weakSelf videoInput] device] isConnected])
                [session removeInput:[weakSelf videoInput]];
                
            [session commitConfiguration];
            
            [weakSelf setAudioInput:nil];
            
            id delegate = [weakSelf delegate];
            if ([delegate respondsToSelector:@selector(captureManagerDeviceConfigurationChanged)]) {
                [delegate captureManagerDeviceConfigurationChanged];
            }
            
            if (![session isRunning])
                [session startRunning];
        };
        // start up location services
        if ([CLLocationManager locationServicesEnabled])
        {
            locationManager = [[CLLocationManager alloc] init];
            locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation;
        }
        else
        {
            NSLog(@"[AVCamCaptureManager] Location services are disabled!");
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Photo Hub Error"
                                                                message:@"Location services are disabled. Please enable location services and restart the photo hub."
                                                               delegate:nil
                                                      cancelButtonTitle:@"OK"
                                                      otherButtonTitles:nil];
            [alertView show];
        }
        NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
        [weakSelf setDeviceConnectedObserver:[notificationCenter addObserverForName:AVCaptureDeviceWasConnectedNotification object:nil queue:nil usingBlock:deviceConnectedBlock]];
        [weakSelf setDeviceDisconnectedObserver:[notificationCenter addObserverForName:AVCaptureDeviceWasDisconnectedNotification object:nil queue:nil usingBlock:deviceDisconnectedBlock]];
        
        [[NSNotificationCenter defaultCenter]
         addObserver:weakSelf
         selector:@selector(startLocationUpdating:)
         name:@"startGPSEvent"
         object:nil ];

        [[NSNotificationCenter defaultCenter]
         addObserver:weakSelf
         selector:@selector(stopLocationUpdating:)
         name:@"stopGPSEvent"
         object:nil ];

    }
    return self;
}

-(void)startLocationUpdating: (NSNotification *) notification
{
    if (locationManager)
    {
        NSLog(@"[AVCamCaptureManager] Starting location updating");
        [locationManager startUpdatingLocation];
    }
}

-(void)stopLocationUpdating: (NSNotification *) notification
{
    if (locationManager)
    {
        NSLog(@"[AVCamCaptureManager] Stopping location updating");
        [locationManager stopUpdatingLocation];
    }
}

-(void)removeObservers
{
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter removeObserver:[self deviceConnectedObserver]];
    [notificationCenter removeObserver:[self deviceDisconnectedObserver]];
    [notificationCenter removeObserver:self name:@"startGPSEvent" object:nil];
    [notificationCenter removeObserver:self name:@"stopGPSEvent" object:nil];

    [[self session] stopRunning];    
    self.delegate = nil;
}

- (void) dealloc
{
    NSLog(@"[AVCamCaptureManager] dealloc");
}

- (BOOL) setupSessionWithPreset:(NSString *)sessionPreset error:(NSError **)error
{
    BOOL success = NO;
    
    // Init the device inputs
    AVCaptureDeviceInput *videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:[self backFacingCamera] error:error];
    [self setVideoInput:videoInput];
    
    //AVCaptureDeviceInput *audioInput = [[AVCaptureDeviceInput alloc] initWithDevice:[self audioDevice] error:error];
    //[self setAudioInput:audioInput];
    
    // Setup the default file outputs
    AVCaptureStillImageOutput *stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
    NSDictionary *outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys:
                                    AVVideoCodecJPEG, AVVideoCodecKey,
                                    nil];
    [stillImageOutput setOutputSettings:outputSettings];
    outputSettings = nil;
    [self setStillImageOutput:stillImageOutput];
    
    //AVCaptureMovieFileOutput *movieFileOutput = [[AVCaptureMovieFileOutput alloc] init];
    //[self setMovieFileOutput:movieFileOutput];
    //[movieFileOutput release];
    
    // Add inputs and output to the capture session, set the preset, and start it running
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    
    if ([session canAddInput:videoInput]) {
        [session addInput:videoInput];
    }
    //if ([session canAddInput:audioInput]) {
    //    [session addInput:audioInput];
    //}
    //if ([session canAddOutput:movieFileOutput]) {
    //    [session addOutput:movieFileOutput];
    //    [self setMirroringMode:AVCamMirroringAuto];
    //}
    if ([session canAddOutput:stillImageOutput]) {
        [session addOutput:stillImageOutput];
    }
    
    [self setSessionPreset:sessionPreset];
    
    [self setSession:session];
    
    //[session release];
    
    success = YES;
    
    __unsafe_unretained AVCamCaptureManager *weakSelf = self;
    id delegate = [weakSelf delegate];
    if ([delegate respondsToSelector:@selector(captureManagerDeviceConfigurationChanged)]) {
        [delegate captureManagerDeviceConfigurationChanged];
    }
    
    return success;
}

- (BOOL) isRecording
{
    return [[self movieFileOutput] isRecording];
}

- (void) startRecording
{
    __unsafe_unretained AVCamCaptureManager *weakSelf = self;
    if ([[UIDevice currentDevice] isMultitaskingSupported]) {
        [weakSelf setBackgroundRecordingID:[[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{}]];
    }
    
    AVCaptureConnection *videoConnection = [AVCamCaptureManager connectionWithMediaType:AVMediaTypeVideo fromConnections:[[weakSelf movieFileOutput] connections]];
    if ([videoConnection isVideoOrientationSupported]) {
        [videoConnection setVideoOrientation:[weakSelf orientation]];
    }
    
    [[self movieFileOutput] startRecordingToOutputFileURL:[weakSelf tempFileURL]
                                        recordingDelegate:weakSelf];
}

- (void) stopRecording
{
    [[self movieFileOutput] stopRecording];
}

#pragma mark -
#pragma mark Private helper methods

// Returns a copy of the image that has been transformed using the given affine transform and scaled to the new size
// The new image's orientation will be UIImageOrientationUp, regardless of the current image's orientation
// If the new size is not integral, it will be rounded up
- (UIImage *)resizedImage:(UIImage *)original sizedTo:(CGSize)newSize
                transform:(CGAffineTransform)transform
           drawTransposed:(BOOL)transpose
     interpolationQuality:(CGInterpolationQuality)quality
{
    CGRect newRect = CGRectIntegral(CGRectMake(0, 0, newSize.width, newSize.height));
    CGRect transposedRect = CGRectMake(0, 0, newRect.size.height, newRect.size.width);
    CGImageRef imageRef = original.CGImage;
    
    // Fix for a colorspace / transparency issue that affects some types of 
    // images. See here: http://vocaro.com/trevor/blog/2009/10/12/resize-a-uiimage-the-right-way/comment-page-2/#comment-39951
    
    CGContextRef bitmap =CGBitmapContextCreate( NULL,
                                               newRect.size.width,
                                               newRect.size.height,
                                               8,
                                               0,
                                               CGImageGetColorSpace( imageRef ),
                                               kCGImageAlphaNoneSkipLast );
    
    // Rotate and/or flip the image if required by its orientation
    CGContextConcatCTM(bitmap, transform);
    
    // Set the quality level to use when rescaling
    CGContextSetInterpolationQuality(bitmap, quality);
    
    // Draw into the context; this scales the image
    CGContextDrawImage(bitmap, transpose ? transposedRect : newRect, imageRef);
    
    // Get the resized image from the context and a UIImage
    CGImageRef newImageRef = CGBitmapContextCreateImage(bitmap);
    UIImage *newImage = [UIImage imageWithCGImage:newImageRef];
    
    // Clean up
    CGContextRelease(bitmap);
    CGImageRelease(newImageRef);
    
    return newImage;
}

// Returns a rescaled copy of the image, taking into account its orientation
// The image will be scaled disproportionately if necessary to fit the bounds specified by the parameter
- (UIImage *)resizedImage:(UIImage *)original sizedTo:(CGSize)newSize interpolationQuality:(CGInterpolationQuality)quality
{
    BOOL drawTransposed;
    CGAffineTransform transform = CGAffineTransformIdentity;
    
    // In iOS 5 the image is already correctly rotated. See Eran Sandler's
    // addition here: http://eran.sandler.co.il/2011/11/07/uiimage-in-ios-5-orientation-and-resize/
    
    if ( [[[UIDevice currentDevice] systemVersion] floatValue] >= 5.0 ) 
    {
        drawTransposed = NO;  
    } 
    else 
    {    
        switch ( original.imageOrientation ) 
        {
            case UIImageOrientationLeft:
            case UIImageOrientationLeftMirrored:
            case UIImageOrientationRight:
            case UIImageOrientationRightMirrored:
                drawTransposed = YES;
                break;
            default:
                drawTransposed = NO;
        }
        
        transform = [self transformForOrientation:original sizedTo:newSize];
    }    
    return [self resizedImage:original sizedTo:newSize transform:transform drawTransposed:drawTransposed interpolationQuality:quality];
}

// Resizes the image according to the given content mode, taking into account the image's orientation
- (UIImage *)resizedImageWithContentMode:(UIImage *)original withContentMode:(UIViewContentMode)contentMode
                                  bounds:(CGSize)bounds
                    interpolationQuality:(CGInterpolationQuality)quality
{
    CGFloat horizontalRatio = bounds.width / original.size.width;
    CGFloat verticalRatio = bounds.height / original.size.height;
    CGFloat ratio;
    
    switch (contentMode)
    {
        case UIViewContentModeScaleAspectFill:
            ratio = MAX(horizontalRatio, verticalRatio);
            break;
            
        case UIViewContentModeScaleAspectFit:
            ratio = MIN(horizontalRatio, verticalRatio);
            break;
            
        default:
            [NSException raise:NSInvalidArgumentException format:@"Unsupported content mode: %d", contentMode];
    }
    
    CGSize newSize = CGSizeMake(original.size.width * ratio, original.size.height * ratio);
    
    return [self resizedImage:original sizedTo:newSize interpolationQuality:quality];
}

// Returns an affine transform that takes into account the image orientation when drawing a scaled image
- (CGAffineTransform)transformForOrientation:(UIImage *)original sizedTo:(CGSize)newSize
{
    CGAffineTransform transform = CGAffineTransformIdentity;
    
    switch (original.imageOrientation)
    {
        case UIImageOrientationDown:           // EXIF = 3
        case UIImageOrientationDownMirrored:   // EXIF = 4
            transform = CGAffineTransformTranslate(transform, newSize.width, newSize.height);
            transform = CGAffineTransformRotate(transform, M_PI);
            break;
            
        case UIImageOrientationLeft:           // EXIF = 6
        case UIImageOrientationLeftMirrored:   // EXIF = 5
            transform = CGAffineTransformTranslate(transform, newSize.width, 0);
            transform = CGAffineTransformRotate(transform, M_PI_2);
            break;
            
        case UIImageOrientationRight:          // EXIF = 8
        case UIImageOrientationRightMirrored:  // EXIF = 7
            transform = CGAffineTransformTranslate(transform, 0, newSize.height);
            transform = CGAffineTransformRotate(transform, -M_PI_2);
            break;
        default:
            break;
    }
    
    switch (original.imageOrientation) {
        case UIImageOrientationUpMirrored:     // EXIF = 2
        case UIImageOrientationDownMirrored:   // EXIF = 4
            transform = CGAffineTransformTranslate(transform, newSize.width, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
            
        case UIImageOrientationLeftMirrored:   // EXIF = 5
        case UIImageOrientationRightMirrored:  // EXIF = 7
            transform = CGAffineTransformTranslate(transform, newSize.height, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
        default:
            break;
    }
    
    return transform;
}

- (UIImage *)croppedImage:(UIImage *)original croppedTo:(CGRect)cropRect
{
    UIGraphicsBeginImageContext(cropRect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    // translated rectangle for drawing sub image 
    CGRect drawRect = CGRectMake(-cropRect.origin.x, -cropRect.origin.y, original.size.width, original.size.height);
    
    // clip to the bounds of the image context
    // not strictly necessary as it will get clipped anyway?
    CGContextClipToRect(context, CGRectMake(0, 0, cropRect.size.width, cropRect.size.height));
    
    // draw image
    [original drawInRect:drawRect];
    
    // grab image
    UIImage* croppedImage = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    return croppedImage;
}

- (UIImage *)fixOrientation:(UIImage*)imgToRotate
{   
    if (gSingleton.showTrace)
        NSLog(@"Image orientation: %d", imgToRotate.imageOrientation);
    
    CGFloat degreesToRotate;

    /*
    typedef enum {
        UIImageOrientationUp,
        UIImageOrientationDown,   // 180 deg rotation
        UIImageOrientationLeft,   // 90 deg CCW
        UIImageOrientationRight,   // 90 deg CW
        UIImageOrientationUpMirrored,    // as above but image mirrored along
        // other axis. horizontal flip
        UIImageOrientationDownMirrored,  // horizontal flip
        UIImageOrientationLeftMirrored,  // vertical flip
        UIImageOrientationRightMirrored, // vertical flip
    } UIImageOrientation;
    */
    
    switch (imgToRotate.imageOrientation)
    {
        case UIImageOrientationUp:
        case UIImageOrientationUpMirrored:
            return imgToRotate;
        
        case UIImageOrientationDown:
        case UIImageOrientationDownMirrored:
            degreesToRotate = 180.0f;
            break;

        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
            degreesToRotate = 270.0f;
            break;

        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            degreesToRotate = 90.0f;
            break;
    }
    return [AVCamUtilities imageRotatedByDegrees:imgToRotate degreesToRotate:degreesToRotate];
}

- (void) finishCapture
{
    [[NSNotificationCenter defaultCenter]
     postNotificationName:@"clearEvent"
     object:nil ];
    
    [[NSNotificationCenter defaultCenter]
     postNotificationName:@"cameraReadyEvent"
     object:nil ];
}

- (NSString *)getUTCFormattedDate:(NSDate *)localDate
{
    static NSDateFormatter *dateFormatter;
    if (dateFormatter == nil)
    {
        dateFormatter = [[NSDateFormatter alloc] init];
        NSTimeZone *timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
        [dateFormatter setTimeZone:timeZone];
        [dateFormatter setDateFormat:@"yyyy:MM:dd HH:mm:ss"];
    }
    NSString *dateString = [dateFormatter stringFromDate:localDate];
    return dateString;
}

- (void)setLocation:(CLLocation *)location fromMetaData:(NSMutableDictionary *)metadata
{
    NSLog(@"setLocation(%@)", location);
    
    if (location && location.horizontalAccuracy >= 0)
    {
        CLLocationDegrees exifLatitude  = location.coordinate.latitude;
        CLLocationDegrees exifLongitude = location.coordinate.longitude;
        
        NSString *latRef;
        NSString *lngRef;
        if (exifLatitude < 0.0)
        {
            exifLatitude = exifLatitude * -1.0f;
            latRef = @"S";
        }
        else
        {
            latRef = @"N";
        }
        
        if (exifLongitude < 0.0)
        {
            exifLongitude = exifLongitude * -1.0f;
            lngRef = @"W";
        }
        else
        {
            lngRef = @"E";
        }
        
        NSMutableDictionary *locDict = [[NSMutableDictionary alloc] init];
        if ([metadata objectForKey:(NSString*)kCGImagePropertyGPSDictionary])
        {
            [locDict addEntriesFromDictionary:[metadata objectForKey:(NSString*)kCGImagePropertyGPSDictionary]];
        }
        [locDict setObject:[self getUTCFormattedDate:location.timestamp] forKey:(NSString*)kCGImagePropertyGPSTimeStamp];
        [locDict setObject:latRef forKey:(NSString*)kCGImagePropertyGPSLatitudeRef];
        [locDict setObject:[NSNumber numberWithFloat:exifLatitude] forKey:(NSString*)kCGImagePropertyGPSLatitude];
        [locDict setObject:lngRef forKey:(NSString*)kCGImagePropertyGPSLongitudeRef];
        [locDict setObject:[NSNumber numberWithFloat:exifLongitude] forKey:(NSString*)kCGImagePropertyGPSLongitude];
        [locDict setObject:[NSNumber numberWithFloat:location.horizontalAccuracy] forKey:(NSString*)kCGImagePropertyGPSDOP];
        [locDict setObject:[NSNumber numberWithFloat:location.altitude] forKey:(NSString*)kCGImagePropertyGPSAltitude];
        
        [metadata setObject:locDict forKey:(NSString*)kCGImagePropertyGPSDictionary];
    }
}

- (void) captureStillImage
{
    if (gSingleton.showTrace)
        NSLog(@"captureStillImage()");
        
    BOOL emu = NO;
        
    NSString *model = [[UIDevice currentDevice] model];
    if ([model isEqualToString:@"iPhone Simulator"] || [model isEqualToString:@"iPad Simulator"])
    {
        emu = YES;
    }
        
    unsigned int timestamp = [[NSDate date] timeIntervalSince1970];
        
    self.filename = [NSString stringWithFormat:@"%@/p%i.jpg", gSingleton.todaysPhotoFolder, timestamp];
    // change this when the key is refactored
    //curLS = [NSMutableString stringWithFormat:@"%@_%i.jpg", gSingleton.currentLabelString, timestamp];  
    
    //ShowcaseDemo.bundle/
        
    if (emu)
    {
        NSString *modStr;
            
        if (gSingleton.isModule)
        {
            modStr = @"";
        }
        else
        {
            modStr = @"ShowcaseDemo.bundle/";
        }
            
        NSString *source = [NSString stringWithFormat:@"%@modules/com.phmod/0%d.jpg", modStr, (gSingleton.photoCount%4) + 1];
        //NSString *fakeImageStr = 
        //NIPathForBundleResource(nil, [NSString stringWithFormat:@"ShowcaseDemo.bundle/%@", source]);
        UIImage *fakeImage = [UIImage imageNamed:source];
        float scale = [self cameraZoom];
        if (scale > 1.0) 
        {
            // save the images original size
            CGSize origSize = [fakeImage size];  
            CGPoint center = CGPointMake(origSize.width / 2, origSize.height / 2);

            // now calculate the offset x and offset y
            CGFloat offsetX = center.x - (origSize.width / scale / 2);
            CGFloat offsetY = center.y - (origSize.height / scale / 2);
            
            // crop the image from the offset position to the original width and height
            fakeImage = [self croppedImage:fakeImage croppedTo:CGRectMake(offsetX, offsetY, origSize.width / scale, origSize.height / scale)];
        }
            
        [gSingleton saveImage:fakeImage withName:self.filename andMetaData:nil];
        
        /*
        id delegate = [self delegate];
        if ([delegate respondsToSelector:@selector(captureManagerStillImageCaptured:)])
        {
            [delegate captureManagerStillImageCaptured];
        }
        */
        [self finishCapture];
    }
    else
    {
        AVCaptureConnection *stillImageConnection = [AVCamUtilities connectionWithMediaType:AVMediaTypeVideo fromConnections:[[self stillImageOutput] connections]];
        if ([stillImageConnection isVideoOrientationSupported])
        {
            [stillImageConnection setVideoOrientation:_orientation];
        }
        [[self stillImageOutput] captureStillImageAsynchronouslyFromConnection:stillImageConnection
                                completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error)
        {
                                                                     
                                __unsafe_unretained AVCamCaptureManager *weakSelf = self;
                                ALAssetsLibraryWriteImageCompletionBlock completionBlock = ^(NSURL *assetURL, NSError *error)
                                {
                                    if (error)
                                    {
                                        id delegate = [weakSelf delegate];
                                        if ([delegate respondsToSelector:@selector(captureStillImageFailedWithError:didFailWithError:)])
                                        {
                                            [delegate captureStillImageFailedWithError:error];
                                        }
                                    }
                                };
            
                                if (imageDataSampleBuffer != NULL)
                                {
                                    NSMutableDictionary *metadata = nil;
                                    if (locationManager)
                                    {
                                        CFDictionaryRef exifAttachments = CMGetAttachment(imageDataSampleBuffer, kCGImagePropertyExifDictionary, NULL);
                                        metadata = (__bridge NSMutableDictionary*)exifAttachments;
                                        if(!metadata)
                                        {
                                            //if the image does not have an EXIF dictionary (not all images do), then create one for us to use
                                            metadata = [NSMutableDictionary dictionary];
                                        }
                                        [weakSelf setLocation:locationManager.location fromMetaData:metadata];
                                        NSLog(@"%@",metadata);
                                    }
                                    NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
                                    UIImage *image = [[UIImage alloc] initWithData:imageData];
                                    NSLog(@"Image Size: %.f x %.f", image.size.width, image.size.height);
                                    
                                    float scale = [weakSelf cameraZoom];
                                    
                                    if (scale > 1.0) 
                                    {
                                        // save the images original size
                                        CGSize origSize = [image size];  
                                        CGPoint center = CGPointMake(origSize.width / 2, origSize.height / 2);
                                        
                                        // now calculate the new height, width, offset x and offset y
                                        CGFloat cropWidth = origSize.width / scale;
                                        CGFloat cropHeight = origSize.height / scale;
                                        CGFloat offsetX = center.x - (cropWidth / 2);
                                        CGFloat offsetY = center.y - (cropHeight / 2);
                                        
                                        NSLog(@"cropRect: (%.f,%.f) %.f x %.f", offsetX, offsetY, cropWidth, cropHeight);
                                        
                                        // crop the image from the offset position to the original width and height
                                        image = [weakSelf croppedImage:image croppedTo:CGRectMake(offsetX, offsetY, cropWidth, cropHeight)];
                                    }
                                    //UIImage *newImage = [self fixOrientation:image];
                                    [gSingleton saveImage:image withName:weakSelf.filename andMetaData:metadata];
                                    
                                    //ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
                                    /*
                                        [library writeImageToSavedPhotosAlbum:[image CGImage]
                                                orientation:(ALAssetOrientation)[image imageOrientation]
                                                completionBlock:completionBlock];0
                                    */
                                }
                                else
                                {
                                    completionBlock(nil, error);
                                }
                                //id delegate = [self delegate];
                                //if ([delegate respondsToSelector:@selector(captureManagerStillImageCaptured:)])
                                //{
                                //   [delegate captureManagerStillImageCaptured];
                                //}
            [self finishCapture];
        }];
    }
}

- (BOOL) cameraToggle
{
    BOOL success = NO;

    __unsafe_unretained AVCamCaptureManager *weakSelf = self;
    if ([weakSelf cameraCount] > 1) {
        NSError *error;
        AVCaptureDeviceInput *videoInput = [weakSelf videoInput];
        AVCaptureDeviceInput *newVideoInput;
        AVCaptureDevicePosition position = [[videoInput device] position];
        BOOL mirror;
        if (position == AVCaptureDevicePositionBack) {
            newVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:[weakSelf frontFacingCamera] error:&error];
            switch ([weakSelf mirroringMode]) {
                case AVCamMirroringOff:
                    mirror = NO;
                    break;
                case AVCamMirroringOn:
                    mirror = YES;
                    break;
                case AVCamMirroringAuto:
                default:
                    mirror = NO;
                    break;
            }
        } else if (position == AVCaptureDevicePositionFront) {
            newVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:[weakSelf backFacingCamera] error:&error];
            switch ([weakSelf mirroringMode]) {
                case AVCamMirroringOff:
                    mirror = NO;
                    break;
                case AVCamMirroringOn:
                    mirror = YES;
                    break;
                case AVCamMirroringAuto:
                default:
                    mirror = YES;
                    break;
            }
        } else {
            goto bail;
        }
        
        AVCaptureSession *session = [weakSelf session];
        if (newVideoInput != nil) {
            [session beginConfiguration];
            [session removeInput:videoInput];
            NSString *currentPreset = [session sessionPreset];
            if (![[newVideoInput device] supportsAVCaptureSessionPreset:currentPreset]) {
                [session setSessionPreset:AVCaptureSessionPresetHigh]; // default back to high, since this will always work regardless of the camera
            }
            if ([session canAddInput:newVideoInput]) {
                [session addInput:newVideoInput];
                AVCaptureConnection *connection = [AVCamCaptureManager connectionWithMediaType:AVMediaTypeVideo fromConnections:[[self movieFileOutput] connections]];
                if ([connection isVideoMirroringSupported]) {
                    [connection setVideoMirrored:mirror];
                }
                [weakSelf setVideoInput:newVideoInput];
            } else {
                [session setSessionPreset:currentPreset];
                [session addInput:videoInput];
            }
            [session commitConfiguration];
            success = YES;
            //[newVideoInput release];
        } else if (error) {
            id delegate = [weakSelf delegate];
            if ([delegate respondsToSelector:@selector(someOtherError:)]) {
                [delegate someOtherError:error];
            }
        }
    }
    
bail:
    return success;
}

- (NSUInteger) cameraCount
{
    return [[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo] count];
}

- (NSUInteger) micCount
{
    return [[AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio] count];
}

- (BOOL) hasFlash
{
    return [[[self videoInput] device] hasFlash];
}

- (AVCaptureFlashMode) flashMode
{
    return [[[self videoInput] device] flashMode];
}

- (void) setFlashMode:(AVCaptureFlashMode)flashMode
{
    __unsafe_unretained AVCamCaptureManager *weakSelf = self;
    AVCaptureDevice *device = [[weakSelf videoInput] device];
    if ([device isFlashModeSupported:flashMode] && [device flashMode] != flashMode) {
        NSError *error;
        if ([device lockForConfiguration:&error]) {
            [device setFlashMode:flashMode];
            [device unlockForConfiguration];
        } else {
            id delegate = [weakSelf delegate];
            if ([delegate respondsToSelector:@selector(acquiringDeviceLockFailedWithError:)]) {
                [delegate acquiringDeviceLockFailedWithError:error];
            }
        }    
    }
}

- (BOOL) hasTorch
{
    return [[[self videoInput] device] hasTorch];
}

- (AVCaptureTorchMode) torchMode
{
    return [[[self videoInput] device] torchMode];
}

- (void) setTorchMode:(AVCaptureTorchMode)torchMode
{
    __unsafe_unretained AVCamCaptureManager *weakSelf = self;
    AVCaptureDevice *device = [[weakSelf videoInput] device];
    if ([device isTorchModeSupported:torchMode] && [device torchMode] != torchMode) {
        NSError *error;
        if ([device lockForConfiguration:&error]) {
            [device setTorchMode:torchMode];
            [device unlockForConfiguration];
        } else {
            id delegate = [weakSelf delegate];
            if ([delegate respondsToSelector:@selector(acquiringDeviceLockFailedWithError:)]) {
                [delegate acquiringDeviceLockFailedWithError:error];
            }
        }
    }
}

- (BOOL) hasFocus
{
    AVCaptureDevice *device = [[self videoInput] device];
    
    return  [device isFocusModeSupported:AVCaptureFocusModeLocked] ||
            [device isFocusModeSupported:AVCaptureFocusModeAutoFocus] ||
            [device isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus];
}

- (AVCaptureFocusMode) focusMode
{
    return [[[self videoInput] device] focusMode];
}

- (void) setFocusMode:(AVCaptureFocusMode)focusMode
{
    __unsafe_unretained AVCamCaptureManager *weakSelf = self;
    AVCaptureDevice *device = [[weakSelf videoInput] device];
    if ([device isFocusModeSupported:focusMode] && [device focusMode] != focusMode) {
        NSError *error;
        if ([device lockForConfiguration:&error]) {
            [device setFocusMode:focusMode];
            [device unlockForConfiguration];
        } else {
            id delegate = [weakSelf delegate];
            if ([delegate respondsToSelector:@selector(acquiringDeviceLockFailedWithError:)]) {
                [delegate acquiringDeviceLockFailedWithError:error];
            }
        }    
    }
}

- (BOOL) hasExposure
{
    AVCaptureDevice *device = [[self videoInput] device];
    
    return  [device isExposureModeSupported:AVCaptureExposureModeLocked] ||
            [device isExposureModeSupported:AVCaptureExposureModeAutoExpose] ||
            [device isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure];
}

- (AVCaptureExposureMode) exposureMode
{
    return [[[self videoInput] device] exposureMode];
}

- (void) setExposureMode:(AVCaptureExposureMode)exposureMode
{
    if (exposureMode == 1) {
        exposureMode = 2;
    }
    __unsafe_unretained AVCamCaptureManager *weakSelf = self;
    AVCaptureDevice *device = [[weakSelf videoInput] device];
    if ([device isExposureModeSupported:exposureMode] && [device exposureMode] != exposureMode) {
        NSError *error;
        if ([device lockForConfiguration:&error]) {
            [device setExposureMode:exposureMode];
            [device unlockForConfiguration];
        } else {
            id delegate = [weakSelf delegate];
            if ([delegate respondsToSelector:@selector(acquiringDeviceLockFailedWithError:)]) {
                [delegate acquiringDeviceLockFailedWithError:error];
            }
        }
    }
}

- (BOOL) hasWhiteBalance
{
    AVCaptureDevice *device = [[self videoInput] device];
    
    return  [device isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeLocked] ||
            [device isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeAutoWhiteBalance];
}

- (AVCaptureWhiteBalanceMode) whiteBalanceMode
{
    return [[[self videoInput] device] whiteBalanceMode];
}

- (void) setWhiteBalanceMode:(AVCaptureWhiteBalanceMode)whiteBalanceMode
{
    if (whiteBalanceMode == 1) {
        whiteBalanceMode = 2;
    }    
    __unsafe_unretained AVCamCaptureManager *weakSelf = self;
    AVCaptureDevice *device = [[weakSelf videoInput] device];
    if ([device isWhiteBalanceModeSupported:whiteBalanceMode] && [device whiteBalanceMode] != whiteBalanceMode) {
        NSError *error;
        if ([device lockForConfiguration:&error]) {
            [device setWhiteBalanceMode:whiteBalanceMode];
            [device unlockForConfiguration];
        } else {
            id delegate = [weakSelf delegate];
            if ([delegate respondsToSelector:@selector(acquiringDeviceLockFailedWithError:)]) {
                [delegate acquiringDeviceLockFailedWithError:error];
            }
        }
    }
}

- (void) focusAtPoint:(CGPoint)point
{
    __unsafe_unretained AVCamCaptureManager *weakSelf = self;
    AVCaptureDevice *device = [[weakSelf videoInput] device];
    if ([device isFocusPointOfInterestSupported] && [device isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
        NSError *error;
        if ([device lockForConfiguration:&error]) {
            [device setFocusPointOfInterest:point];
            [device setFocusMode:AVCaptureFocusModeAutoFocus];
            [device unlockForConfiguration];
        } else {
            id delegate = [weakSelf delegate];
            if ([delegate respondsToSelector:@selector(acquiringDeviceLockFailedWithError:)]) {
                [delegate acquiringDeviceLockFailedWithError:error];
            }
        }        
    }
}

- (void) continuousFocusAtPoint:(CGPoint)point
{
    __unsafe_unretained AVCamCaptureManager *weakSelf = self;
    AVCaptureDevice *device = [[weakSelf videoInput] device];
    if ([device isFocusPointOfInterestSupported] && [device isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
        NSError *error;
        if ([device lockForConfiguration:&error]) {
            [device setFocusPointOfInterest:point];
            [device setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
            [device unlockForConfiguration];
        } else {
            id delegate = [weakSelf delegate];
            if ([delegate respondsToSelector:@selector(acquiringDeviceLockFailedWithError:)]) {
                [delegate acquiringDeviceLockFailedWithError:error];
            }
        }        
    }
}

- (void) exposureAtPoint:(CGPoint)point
{
    __unsafe_unretained AVCamCaptureManager *weakSelf = self;
    AVCaptureDevice *device = [[weakSelf videoInput] device];
    if ([device isExposurePointOfInterestSupported] && [device isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) {
        NSError *error;
        if ([device lockForConfiguration:&error]) {
            [device setExposurePointOfInterest:point];
            [device setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
            [device unlockForConfiguration];
        } else {
            id delegate = [weakSelf delegate];
            if ([delegate respondsToSelector:@selector(acquiringDeviceLockFailedWithError:)]) {
                [delegate acquiringDeviceLockFailedWithError:error];
            }
        }
    }    
}

- (NSString *) sessionPreset
{
    return [[self session] sessionPreset];
}

- (void) setSessionPreset:(NSString *)sessionPreset
{
    __unsafe_unretained AVCamCaptureManager *weakSelf = self;
    AVCaptureSession *session = [weakSelf session];
    if (![sessionPreset isEqualToString:[weakSelf sessionPreset]] && [session canSetSessionPreset:sessionPreset]) {
        [session beginConfiguration];
        [session setSessionPreset:sessionPreset];
        [session commitConfiguration];
    }
}

- (void) setConnectionWithMediaType:(NSString *)mediaType enabled:(BOOL)enabled;
{
    [[AVCamCaptureManager connectionWithMediaType:AVMediaTypeVideo fromConnections:[[self movieFileOutput] connections]] setEnabled:enabled];
}

- (void) setMirroringMode:(AVCamMirroringMode)mirroringMode
{
    AVCaptureSession *session = [self session];
    _mirroringMode = mirroringMode;
    AVCaptureConnection *fileConnection = [AVCamCaptureManager connectionWithMediaType:AVMediaTypeVideo fromConnections:[[self movieFileOutput] connections]];
    AVCaptureConnection *stillConnection = [AVCamCaptureManager connectionWithMediaType:AVMediaTypeVideo fromConnections:[[self stillImageOutput] connections]];
    [session beginConfiguration];
    switch (mirroringMode) {
        case AVCamMirroringOff:
            if ([fileConnection isVideoMirroringSupported]) {
                [fileConnection setVideoMirrored:NO];
            }
            if ([stillConnection isVideoMirroringSupported]) {
                [stillConnection setVideoMirrored:NO];
            }
            break;
        case AVCamMirroringOn:
            if ([fileConnection isVideoMirroringSupported]) {
                [fileConnection setVideoMirrored:YES];
            }
            if ([stillConnection isVideoMirroringSupported]) {
                [stillConnection setVideoMirrored:YES];
            }
            break;
        case AVCamMirroringAuto:
        {
            BOOL mirror = NO;
            AVCaptureDevicePosition position = [[[self videoInput] device] position];
            if (position == AVCaptureDevicePositionBack) {
                mirror = NO;
            } else if (position == AVCaptureDevicePositionFront) {
                mirror = YES;
            }
            if ([fileConnection isVideoMirroringSupported]) {
                [fileConnection setVideoMirrored:mirror];
            }
            if ([stillConnection isVideoMirroringSupported]) {
                [stillConnection setVideoMirrored:mirror];
            }
        }
            break;
    }
    [session commitConfiguration];
}

- (BOOL) supportsMirroring
{
    return [[AVCamCaptureManager connectionWithMediaType:AVMediaTypeVideo fromConnections:[[self movieFileOutput] connections]] isVideoMirroringSupported] ||
            [[AVCamCaptureManager connectionWithMediaType:AVMediaTypeVideo fromConnections:[[self stillImageOutput] connections]] isVideoMirroringSupported];
}

- (AVCaptureAudioChannel *)audioChannel
{
    return [[[AVCamCaptureManager connectionWithMediaType:AVMediaTypeAudio fromConnections:[[self movieFileOutput] connections]] audioChannels] lastObject];
}

+ (AVCaptureConnection *)connectionWithMediaType:(NSString *)mediaType fromConnections:(NSArray *)connections;
{
	for ( AVCaptureConnection *connection in connections ) {
		for ( AVCaptureInputPort *port in [connection inputPorts] ) {
			if ( [[port mediaType] isEqual:mediaType] ) {
				return connection;
			}
		}
	}
	return nil;
}

@end

@implementation AVCamCaptureManager (Internal)

- (AVCaptureDevice *) cameraWithPosition:(AVCaptureDevicePosition) position
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices) {
        if ([device position] == position) {
            return device;
        }
    }
    return nil;
}

- (AVCaptureDevice *) frontFacingCamera
{
    return [self cameraWithPosition:AVCaptureDevicePositionFront];
}

- (AVCaptureDevice *) backFacingCamera
{
    return [self cameraWithPosition:AVCaptureDevicePositionBack];
}

- (AVCaptureDevice *) audioDevice
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio];
    if ([devices count] > 0) {
        return [devices objectAtIndex:0];
    }
    return nil;
}

- (NSURL *) tempFileURL
{
    NSString *outputPath = [[NSString alloc] initWithFormat:@"%@%@", NSTemporaryDirectory(), @"output.mov"];
    NSURL *outputURL = [[NSURL alloc] initFileURLWithPath:outputPath];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:outputPath]) {
        NSError *error;
        if ([fileManager removeItemAtPath:outputPath error:&error] == NO) {
            __unsafe_unretained AVCamCaptureManager *weakSelf = self;
            id delegate = [weakSelf delegate];
            if ([delegate respondsToSelector:@selector(someOtherError:)]) {
                [delegate someOtherError:error];
            }            
        }
    }
    //[outputPath release];
    return outputURL;
}

@end


@implementation AVCamCaptureManager (AVCaptureFileOutputRecordingDelegate)

- (void)             captureOutput:(AVCaptureFileOutput *)captureOutput
didStartRecordingToOutputFileAtURL:(NSURL *)fileURL
                   fromConnections:(NSArray *)connections
{
    __unsafe_unretained AVCamCaptureManager *weakSelf = self;
    id delegate = [weakSelf delegate];
    if ([delegate respondsToSelector:@selector(captureManagerRecordingBegan)]) {
        [delegate captureManagerRecordingBegan];
    }
}

- (void)              captureOutput:(AVCaptureFileOutput *)captureOutput
didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL
                    fromConnections:(NSArray *)connections
                              error:(NSError *)error
{
    __unsafe_unretained AVCamCaptureManager *weakSelf = self;
    id delegate = [weakSelf delegate];
    if (error && [delegate respondsToSelector:@selector(someOtherError:)]) {
        [delegate someOtherError:error];
    }
    
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    if ([library videoAtPathIsCompatibleWithSavedPhotosAlbum:outputFileURL]) {
        [library writeVideoAtPathToSavedPhotosAlbum:outputFileURL
                                    completionBlock:^(NSURL *assetURL, NSError *error){
                                        if (error && [delegate respondsToSelector:@selector(assetLibraryError:forURL:)]) {
                                            [delegate assetLibraryError:error forURL:assetURL];
                                        }
                                    }];
    } else {
        if ([delegate respondsToSelector:@selector(cannotWriteToAssetLibrary)]) {
            [delegate cannotWriteToAssetLibrary];
        }
    }

    //[library release];    
    
    if ([[UIDevice currentDevice] isMultitaskingSupported]) {
        [[UIApplication sharedApplication] endBackgroundTask:[weakSelf backgroundRecordingID]];
    }
    
    if ([delegate respondsToSelector:@selector(captureManagerRecordingFinished)]) {
        [delegate captureManagerRecordingFinished];
    }
}

@end
