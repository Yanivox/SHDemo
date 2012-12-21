//
//  ViewController.m
//  SHDemo
//
//  Created by Yaniv Marshaly on 12/21/12.
//  Copyright (c) 2012 Yaniv Marshaly. All rights reserved.
//

#import "ViewController.h"
#import <MediaPlayer/MediaPlayer.h>
@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
#pragma mark - Orientation Methods

//iOS 6 and above

-(BOOL)shouldAutorotate
{
    return NO;
}
-(UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
    return UIInterfaceOrientationPortrait;
}
-(NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

//iOS 5 and below

-(BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return (toInterfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - IBActions

- (IBAction)didPressStartStopRecord:(UIButton*)sender {
    if (![self.recordingView recording]) {
        
        [self.recordingView startRecording];
        
    }else{
        [self.recordingView stopRecordingWithCompleteBlock:^(NSURL *outputURL) {
            
            
        }];
    }
}

- (void)viewDidUnload {
    [self setRecordingView:nil];
    [super viewDidUnload];
}
@end
