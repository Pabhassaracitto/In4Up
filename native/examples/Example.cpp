// Example.cpp - Cách sử dụng UltraTimeStretch
#include "UltraTimeStretch.h"
#include <iostream>
#include <fstream>
#include <vector>

int main() {
    using namespace UltraTimeStretch;
    
    //==========================================================================
    // Initialize Engine
    //==========================================================================
    Engine engine;
    
    Options options;
    options.quality = Quality::HighQuality;
    options.preserveTransients = true;
    options.antiAliasing = true;
    options.transientSensitivity = 0.6f;
    
    int sampleRate = 44100;
    int channels = 2;
    
    if (!engine.initialize(sampleRate, channels, options)) {
        std::cerr << "Failed to initialize engine!" << std::endl;
        return -1;
    }
    
    std::cout << "UltraTimeStretch Engine initialized" << std::endl;
    std::cout << "Sample Rate: " << sampleRate << std::endl;
    std::cout << "Channels: " << channels << std::endl;
    std::cout << "Latency: " << engine.getLatency() << " samples" << std::endl;
    
    //==========================================================================
    // Test with different speeds
    //==========================================================================
    std::vector<float> testSpeeds = {0.1f, 0.25f, 0.5f, 1.0f, 1.5f, 2.0f};
    
    // Generate test audio (sine wave)
    int testDuration = 44100;  // 1 second
    std::vector<float> testInput(testDuration * channels);
    
    for (int i = 0; i < testDuration; ++i) {
        float t = (float)i / sampleRate;
        // 440 Hz sine wave
        float sample = 0.5f * std::sin(2.0f * 3.14159f * 440.0f * t);
        
        // Add some harmonics for richness
        sample += 0.25f * std::sin(2.0f * 3.14159f * 880.0f * t);
        sample += 0.125f * std::sin(2.0f * 3.14159f * 1320.0f * t);
        
        // Stereo
        for (int ch = 0; ch < channels; ++ch) {
            testInput[i * channels + ch] = sample;
        }
    }
    
    for (float speed : testSpeeds) {
        std::cout << "\n=== Testing speed: " << speed << "x ===" << std::endl;
        
        engine.reset();
        engine.setSpeed(speed);
        
        // Calculate expected output size
        int expectedOutputFrames = static_cast<int>(testDuration / speed);
        int maxOutputSize = engine.getRequiredOutputBufferSize(testDuration * channels);
        std::vector<float> output(maxOutputSize);
        
        // Process
        int outputFrames = engine.processInterleaved(
            testInput.data(), testDuration,
            output.data(), maxOutputSize / channels
        );
        
        std::cout << "Input frames: " << testDuration << std::endl;
        std::cout << "Output frames: " << outputFrames << std::endl;
        std::cout << "Expected: ~" << expectedOutputFrames << std::endl;
        std::cout << "Actual ratio: " << (float)outputFrames / testDuration << std::endl;
        
        // Calculate output statistics
        float maxSample = 0.0f;
        float rms = 0.0f;
        for (int i = 0; i < outputFrames * channels; ++i) {
            maxSample = std::max(maxSample, std::abs(output[i]));
            rms += output[i] * output[i];
        }
        rms = std::sqrt(rms / (outputFrames * channels));
        
        std::cout << "Max sample: " << maxSample << std::endl;
        std::cout << "RMS level: " << rms << std::endl;
    }
    
    //==========================================================================
    // Real-time simulation
    //==========================================================================
    std::cout << "\n=== Real-time simulation ===" << std::endl;
    
    engine.reset();
    engine.setSpeed(0.5f);  // Half speed
    
    int blockSize = 512;  // Typical audio buffer size
    std::vector<float> inputBlock(blockSize * channels);
    std::vector<float> outputBlock(blockSize * 4 * channels);  // Extra space for stretching
    
    int totalInputProcessed = 0;
    int totalOutputGenerated = 0;
    
    for (int block = 0; block < 100; ++block) {
        // Fill input block (simulating audio input)
        for (int i = 0; i < blockSize * channels; ++i) {
            int sampleIdx = totalInputProcessed * channels + i;
            if (sampleIdx < (int)testInput.size()) {
                inputBlock[i] = testInput[sampleIdx];
            } else {
                inputBlock[i] = 0.0f;
            }
        }
        
        // Process block
        int outputFrames = engine.processInterleaved(
            inputBlock.data(), blockSize,
            outputBlock.data(), blockSize * 4
        );
        
        totalInputProcessed += blockSize;
        totalOutputGenerated += outputFrames;
    }
    
    std::cout << "Total input processed: " << totalInputProcessed << " frames" << std::endl;
    std::cout << "Total output generated: " << totalOutputGenerated << " frames" << std::endl;
    std::cout << "Effective ratio: " << (float)totalOutputGenerated / totalInputProcessed << std::endl;
    
    engine.shutdown();
    std::cout << "\nEngine shutdown complete." << std::endl;
    
    return 0;
}