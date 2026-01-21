// WSOLAProcessor.cpp
#include "UltraTimeStretch.h"

namespace UltraTimeStretch {

WSOLAProcessor::WSOLAProcessor(int frameSize, int sampleRate)
    : frameSize_(frameSize)
    , overlapSize_(frameSize / 2)
    , sampleRate_(sampleRate)
    , ratio_(1.0f)
    , inputPosition_(0.0f)
{
    previousFrame_.resize(frameSize_, 0.0f);
    overlapBuffer_.resize(overlapSize_, 0.0f);
    window_.resize(frameSize_);
    
    // Hann window
    for (int i = 0; i < frameSize_; ++i) {
        window_[i] = 0.5f * (1.0f - std::cos(TWO_PI * i / frameSize_));
    }
    
    // Search range based on tempo
    searchRange_ = frameSize_ / 4;
}

WSOLAProcessor::~WSOLAProcessor() = default;

void WSOLAProcessor::setTimeStretchRatio(float ratio) {
    ratio_ = std::clamp(ratio, 0.05f, 10.0f);
}

float WSOLAProcessor::computeCorrelation(const float* a, const float* b, int length) {
    float sum = 0.0f;
    float sumA2 = 0.0f;
    float sumB2 = 0.0f;
    
#if UTS_USE_NEON
    // NEON optimized correlation
    float32x4_t vSum = vdupq_n_f32(0.0f);
    float32x4_t vSumA2 = vdupq_n_f32(0.0f);
    float32x4_t vSumB2 = vdupq_n_f32(0.0f);
    
    int i = 0;
    for (; i + 4 <= length; i += 4) {
        float32x4_t vA = vld1q_f32(a + i);
        float32x4_t vB = vld1q_f32(b + i);
        
        vSum = vmlaq_f32(vSum, vA, vB);
        vSumA2 = vmlaq_f32(vSumA2, vA, vA);
        vSumB2 = vmlaq_f32(vSumB2, vB, vB);
    }
    
    float temp[4];
    vst1q_f32(temp, vSum);
    sum = temp[0] + temp[1] + temp[2] + temp[3];
    
    vst1q_f32(temp, vSumA2);
    sumA2 = temp[0] + temp[1] + temp[2] + temp[3];
    
    vst1q_f32(temp, vSumB2);
    sumB2 = temp[0] + temp[1] + temp[2] + temp[3];
    
    // Handle remaining samples
    for (; i < length; ++i) {
        sum += a[i] * b[i];
        sumA2 += a[i] * a[i];
        sumB2 += b[i] * b[i];
    }
#else
    // Scalar fallback
    for (int i = 0; i < length; ++i) {
        sum += a[i] * b[i];
        sumA2 += a[i] * a[i];
        sumB2 += b[i] * b[i];
    }
#endif
    
    float denom = std::sqrt(sumA2 * sumB2);
    if (denom < 1e-10f) return 0.0f;
    
    return sum / denom;
}

int WSOLAProcessor::findBestOffset(const float* current, const float* previous, int searchRange) {
    float bestCorrelation = -2.0f;
    int bestOffset = 0;
    
    // Use overlap region for correlation
    int correlationLength = overlapSize_;
    
    for (int offset = -searchRange; offset <= searchRange; ++offset) {
        // Bounds check
        float correlation = computeCorrelation(
            previous + overlapSize_ + offset,
            current,
            correlationLength
        );
        
        if (correlation > bestCorrelation) {
            bestCorrelation = correlation;
            bestOffset = offset;
        }
    }
    
    return bestOffset;
}

void WSOLAProcessor::processBlock(const float* input, int inputSamples,
                                   float* output, int& outputSamples) {
    if (inputSamples < frameSize_) {
        outputSamples = 0;
        return;
    }
    
    outputSamples = 0;
    float outputPosition = 0.0f;
    int synthesisHop = static_cast<int>(frameSize_ * 0.25f * ratio_);
    synthesisHop = std::max(1, synthesisHop);
    
    // Analysis hop for input advancement
    float analysisHop = synthesisHop / ratio_;
    
    while (inputPosition_ + frameSize_ <= inputSamples) {
        int inputIdx = static_cast<int>(inputPosition_);
        
        // Find best matching position
        int offset = 0;
        if (outputSamples > 0) {
            // Only search after first frame
            int searchStart = std::max(0, inputIdx - searchRange_);
            int searchEnd = std::min(inputSamples - frameSize_, inputIdx + searchRange_);
            
            if (searchEnd > searchStart) {
                offset = findBestOffset(input + inputIdx, previousFrame_.data(), 
                                        std::min(searchRange_, searchEnd - inputIdx));
            }
        }
        
        int adjustedIdx = std::clamp(inputIdx + offset, 0, inputSamples - frameSize_);
        
        // Crossfade with previous frame
        for (int i = 0; i < overlapSize_; ++i) {
            float fadeOut = 1.0f - (float)i / overlapSize_;
            float fadeIn = (float)i / overlapSize_;
            
            float outSample = overlapBuffer_[i] * fadeOut + 
                             input[adjustedIdx + i] * window_[i] * fadeIn;
            
            if (outputSamples + i < inputSamples * 10) {  // Safety bound
                output[outputSamples + i] = outSample;
            }
        }
        
        // Copy non-overlapping part
        for (int i = overlapSize_; i < frameSize_ - overlapSize_; ++i) {
            if (outputSamples + i < inputSamples * 10) {
                output[outputSamples + i] = input[adjustedIdx + i] * window_[i];
            }
        }
        
        // Store overlap for next frame
        for (int i = 0; i < overlapSize_; ++i) {
            overlapBuffer_[i] = input[adjustedIdx + frameSize_ - overlapSize_ + i] * 
                               window_[frameSize_ - overlapSize_ + i];
        }
        
        // Store previous frame for correlation
        std::copy(input + adjustedIdx, input + adjustedIdx + frameSize_, previousFrame_.begin());
        
        outputSamples += synthesisHop;
        inputPosition_ += analysisHop;
    }
    
    // Adjust input position for next call
    inputPosition_ -= inputSamples;
    if (inputPosition_ < 0) inputPosition_ = 0;
}

void WSOLAProcessor::reset() {
    std::fill(previousFrame_.begin(), previousFrame_.end(), 0.0f);
    std::fill(overlapBuffer_.begin(), overlapBuffer_.end(), 0.0f);
    inputPosition_ = 0.0f;
}

} // namespace UltraTimeStretch