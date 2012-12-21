//
//  RecordingView.h
//  SHDemo
//
//  Created by Yaniv Marshaly on 12/21/12.
//  Copyright (c) 2012 Yaniv Marshaly. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MPMediaQuery.h>
#import <MediaPlayer/MPMediaPlaylist.h>
#import <MediaPlayer/MediaPlayer.h>

@interface RecordingView : UIView

@property (nonatomic) BOOL recording;

@property (strong,nonatomic) NSString * outputName;

@property (assign) float frameRate;

-(BOOL)startRecording;

-(void)stopRecordingWithCompleteBlock:(void(^)(NSURL* outputURL))completeBlock;
@end
