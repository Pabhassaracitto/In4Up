#import <Foundation/Foundation.h>

@interface AudioProcessor : NSObject

- (instancetype)initWithSampleRate:(int)sampleRate channels:(int)channels;
- (void)setSpeed:(float)speed;
- (int)processWithInput:(float *)input
            inputFrames:(int)inputFrames
                 output:(float *)output
        maxOutputFrames:(int)maxOutputFrames;
- (void)shutdown;

@end