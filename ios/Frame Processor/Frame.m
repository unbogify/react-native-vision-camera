//
//  Frame.m
//  VisionCamera
//
//  Created by Marc Rousavy on 08.06.21.
//  Copyright © 2021 mrousavy. All rights reserved.
//

#import "Frame.h"
#import <Foundation/Foundation.h>
#import <CoreMedia/CMSampleBuffer.h>

@implementation Frame {
  CMSampleBufferRef buffer;
  UIImageOrientation orientation;
  double timestamp;
}

- (instancetype) initWithBuffer:(CMSampleBufferRef)buffer orientation:(UIImageOrientation)orientation timestamp:(double)timestamp {
  self = [super init];
  if (self) {
    _buffer = buffer;
    _orientation = orientation;
    _timestamp = timestamp;
  }
  return self;
}

@synthesize buffer = _buffer;
@synthesize orientation = _orientation;
@synthesize timestamp = _timestamp;

@end
