#import "AudioProcessor.h"
#include "../../../native/include/UltraTimeStretch.h"
#include "../../../native/include/UltraTimeStretch_V2_Enhancements.h"

using namespace UltraTimeStretch;
using namespace UltraTimeStretch::V2;

@interface AudioProcessor() {
    EngineV2* engine;
}
@end

@implementation AudioProcessor

- (instancetype)initWithSampleRate:(int)sampleRate channels:(int)channels {
    self = [super init];
    if (self) {
        engine = new EngineV2();
        Options options;
        options.quality = Quality::HighQuality;
        options.preserveTransients = true;
        
        if (!engine->initialize(sampleRate, channels, options)) {
            delete engine;
            engine = nullptr;
            return nil;
        }
    }
    return self;
}

- (void)setSpeed:(float)speed {
    if (engine) {
        engine->setSpeed(speed);
    }
}

- (int)processWithInput:(float *)input
            inputFrames:(int)inputFrames
                 output:(float *)output
         maxOutputFrames:(int)maxOutputFrames {
    if (!engine) return 0;
    return engine->processV2(input, inputFrames, output, maxOutputFrames);
}

- (void)shutdown {
    if (engine) {
        engine->shutdown();
        delete engine;
        engine = nullptr;
    }
}

- (void)dealloc {
    [self shutdown];
}

@end