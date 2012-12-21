//
//  RecordingView.m
//  SHDemo
//
//  Created by Yaniv Marshaly on 12/21/12.
//  Copyright (c) 2012 Yaniv Marshaly. All rights reserved.
//

static void (^__completeBlock)(NSURL* outputURL);

#import "RecordingView.h"
#import <QuartzCore/QuartzCore.h>
#import <MobileCoreServices/UTCoreTypes.h>
#import <AssetsLibrary/AssetsLibrary.h>

@interface RecordingView ()
{
    void * bitmapData;
    
    //video writing
    AVAssetWriter * videoWriter;
    AVAssetWriterInput * videoWriterInput;
    AVAssetWriterInputPixelBufferAdaptor * avAdaptor;
}
@property(strong,nonatomic) UIImage * currentScreen;

@property (strong,nonatomic) NSDate * startedAt;

@property (nonatomic)  BOOL success;

@property (nonatomic)  BOOL completed;



@end

@implementation RecordingView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self initialize];
        // Initialization code
    }
    return self;
}

-(void)awakeFromNib
{
    [super awakeFromNib];
    [self initialize];
}
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    NSLog(@"Drawing...");
    [self performSelectorOnMainThread:@selector(takeScreenshot) withObject:nil waitUntilDone:NO];
    // Drawing code
}
#pragma mark - Initialize Methods
-(void)initialize
{
    self.clearsContextBeforeDrawing = YES;
    self.frameRate = 10.0f;      // 10 frames per seconds
    _recording = FALSE;
    videoWriter = nil;
    videoWriterInput = nil;
    avAdaptor = nil;
    self.startedAt = nil;
    bitmapData = nil;
    self.outputName = @"output.mp4";
}
-(void)clearUp
{
    
}
#pragma mark - Recording Methods
// start recording of the screen capture video...
- (BOOL)startRecording {
    BOOL result = NO;
    
    @synchronized(self) {
        if (! _recording) {
            result = [self setUpWriter];
            self.startedAt = [NSDate date];
            _recording = YES;
        }
    }
    
    return result;
}
// stop recording of the screen capture video...

-(void)stopRecordingWithCompleteBlock:(void (^)(NSURL *))completeBlock {
    
    __completeBlock = [completeBlock copy];
    
    @synchronized(self) {
        if (_recording) {
            
            
            _recording = NO;
            
            [self completeRecordingSession];
        }
    }
    
}
// take a screenshot of the current screen.
// arg currently isn't used so can be nil
- (void)takeScreenshot {
    
    NSDate * start = [NSDate date];
    CGContextRef context = [self createBitmapContextOfSize:self.frame.size];
    
    //not sure why this is necessary...image renders upside-down and mirrored
    CGAffineTransform flipVertical = CGAffineTransformMake(1, 0, 0, -1, 0, self.frame.size.height);
    CGContextConcatCTM(context, flipVertical);
    
    [[self.layer presentationLayer] renderInContext:context];
    
    CGImageRef cgImage = CGBitmapContextCreateImage(context);
    UIImage* background = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    
    self.currentScreen = background;
    
    
    if (_recording) {
        float millisElapsed = [[NSDate date] timeIntervalSinceDate:self.startedAt] * 1000.0;
        [self writeVideoFrameAtTime:CMTimeMake((int)millisElapsed, 1000)];
    }
    
    float processingSeconds = [[NSDate date] timeIntervalSinceDate:start];
    float delayRemaining = (1.0 / self.frameRate) - processingSeconds;
    
    CGContextRelease(context);
    
    //redraw at the specified framerate
    [self performSelector:@selector(takeScreenshot) withObject:nil afterDelay:delayRemaining > 0.0 ? delayRemaining : 0.01];
}

- (CGContextRef)createBitmapContextOfSize:(CGSize)size {
    CGContextRef    context = NULL;
    CGColorSpaceRef colorSpace;
    int             bitmapByteCount;
    int             bitmapBytesPerRow;
    
    bitmapBytesPerRow   = (size.width * 4);
    bitmapByteCount     = (bitmapBytesPerRow * size.height);
    colorSpace = CGColorSpaceCreateDeviceRGB();
    
    if (bitmapData != NULL) {
        free(bitmapData);
    }
    
    bitmapData = malloc( bitmapByteCount );
    if (bitmapData == NULL) {
        fprintf (stderr, "Memory not allocated!");
        return NULL;
    }
    
    context = CGBitmapContextCreate (bitmapData,
                                     size.width,
                                     size.height,
                                     8,      // bits per component
                                     bitmapBytesPerRow,
                                     colorSpace,
                                     kCGImageAlphaNoneSkipFirst);
    
    CGContextSetAllowsAntialiasing(context, NO);
    if (context== NULL) {
        free (bitmapData);
        fprintf (stderr, "Context not created!");
        return NULL;
    }
    CGColorSpaceRelease( colorSpace );
    
    return context;
}

- (void)writeVideoFrameAtTime:(CMTime)time {
    
    if (![videoWriterInput isReadyForMoreMediaData]) {
        
        NSLog(@"Not ready for video data");
        
    } else {
        @synchronized (self) {
            
            UIImage* newFrame = self.currentScreen;
            CVPixelBufferRef pixelBuffer = NULL;
            CGImageRef cgImage = CGImageCreateCopy([newFrame CGImage]);
            CFDataRef image = CGDataProviderCopyData(CGImageGetDataProvider(cgImage));
            
            int status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, avAdaptor.pixelBufferPool, &pixelBuffer);
            if(status != 0){
                //could not get a buffer from the pool
                    NSLog(@"Error creating pixel buffer:  status=%d", status);
            }
            // set image data into pixel buffer
            CVPixelBufferLockBaseAddress( pixelBuffer, 0 );
            uint8_t* destPixels = CVPixelBufferGetBaseAddress(pixelBuffer);
            CFDataGetBytes(image, CFRangeMake(0, CFDataGetLength(image)), destPixels);  // Note:  will work if the pixel buffer is contiguous and has the same bytesPerRow as the input data
            
            if(status == 0){
                BOOL success = [avAdaptor appendPixelBuffer:pixelBuffer withPresentationTime:time];
                if (!success) {
                    NSLog(@"Warning:  Unable to write buffer to video");
                }
            }
            
            //clean up
            CVPixelBufferUnlockBaseAddress( pixelBuffer, 0 );
            CVPixelBufferRelease( pixelBuffer );
            CFRelease(image);
            CGImageRelease(cgImage);
        }
        
    }
    
}
- (NSURL*)tempFileURL {
    NSString* outputPath = [[NSString alloc] initWithFormat:@"%@/%@", [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0], self.outputName];
    NSURL* outputURL = [[NSURL alloc] initFileURLWithPath:outputPath];
    NSFileManager* fileManager = [NSFileManager defaultManager];
    
    if ([fileManager fileExistsAtPath:outputPath]) {
        NSError* error;
        if ([fileManager removeItemAtPath:outputPath error:&error] == NO) {
       
                NSLog(@"Could not delete old recording file at path:  %@", outputPath);
        }
    }
    

    return outputURL;
}
- (BOOL)setUpWriter {
    
   
    NSLog(@"setup Writer...");
    
    NSError* error = nil;
    videoWriter = [[AVAssetWriter alloc] initWithURL:[self tempFileURL] fileType:AVFileTypeQuickTimeMovie error:&error];
    NSParameterAssert(videoWriter);
    
    //Configure video
    NSDictionary* videoCompressionProps = [NSDictionary dictionaryWithObjectsAndKeys:
                                           [NSNumber numberWithDouble:1024.0*1024.0], AVVideoAverageBitRateKey,
                                           nil ];
    
    NSDictionary* videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                   AVVideoCodecH264, AVVideoCodecKey,
                                   [NSNumber numberWithInt:self.frame.size.width], AVVideoWidthKey,
                                   [NSNumber numberWithInt:self.frame.size.height], AVVideoHeightKey,
                                   videoCompressionProps, AVVideoCompressionPropertiesKey,
                                   nil];
    
    videoWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
    
    NSParameterAssert(videoWriterInput);
    videoWriterInput.expectsMediaDataInRealTime = YES;
    NSDictionary* bufferAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                      [NSNumber numberWithInt:kCVPixelFormatType_32ARGB], kCVPixelBufferPixelFormatTypeKey, nil];
    
    avAdaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:videoWriterInput sourcePixelBufferAttributes:bufferAttributes];
    
    //add input
    [videoWriter addInput:videoWriterInput];
    [videoWriter startWriting];
    [videoWriter startSessionAtSourceTime:CMTimeMake(0, 1000)];
    
    return YES;
}
- (void)completeRecordingSession {

    NSLog(@"completing recording...");
    
    [videoWriterInput markAsFinished];
    
    // Wait for the video
    int status = videoWriter.status;
    while (status == AVAssetWriterStatusUnknown) {
    
            NSLog(@"Waiting...");
        [NSThread sleepForTimeInterval:0.5f];
        status = videoWriter.status;
    }
    
    @synchronized(self) {
        _completed = FALSE;
        _success = FALSE;
        
        // see if iOS6+; use newer AVAssetWriter method
        if ([videoWriter respondsToSelector:@selector(finishWritingWithCompletionHandler:)]) {
            
          
                NSLog(@"runing iOS6 so use new AVAssetWriter completion handler...");
            
            [videoWriter finishWritingWithCompletionHandler:^(){
                
            
                    NSLog(@"finished writing...");
                
                AVAssetWriterStatus status = videoWriter.status;
                _success = FALSE;
                
                if (status == AVAssetWriterStatusCompleted)
                    _success = TRUE;
                
                if (!_success) {
              
                        NSLog(@"finishWriting returned NO");
                }
                
                _completed = TRUE;
            }];
            
            // < iOS6; use older AVAssetWriter method
        } else {
            

                NSLog(@"using before iOS6 so use old AVAssetWriter method...");
            
            _success = [videoWriter finishWriting];
            
            if (!_success) {
               
                    NSLog(@"finishWriting returned NO");
            }
            
            _completed = TRUE;
        }
        
        while (!_completed) {
            [NSThread sleepForTimeInterval:1];
          
                NSLog(@"waiting for completion...");
        }
        
    
            if (_success)
                NSLog(@"completed OK");
            else
                NSLog(@"completed with error!");
      
        
        [self cleanupWriter];
        
    //    id delegateObj = self.delegate;
        NSString *outputPath = [[NSString alloc] initWithFormat:@"%@/%@", [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0], self.outputName];
        NSURL *outputURL = [[NSURL alloc] initFileURLWithPath:outputPath];
        
      
            NSLog(@"Completed recording, file is stored at:  %@", outputURL);
        
        if (__completeBlock) {
            __completeBlock(_success ? outputURL : nil);
        }
        

    }
    
 
}
- (void)cleanupWriter {
   
    avAdaptor = nil;
    
    videoWriterInput = nil;
    
    videoWriter = nil;

    self.startedAt = nil;
    
    if (bitmapData != NULL) {
        free(bitmapData);
        bitmapData = NULL;
    }
}
@end
