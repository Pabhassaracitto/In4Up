// Example_V2.cpp - Demonstration of V2 Enhanced Features
#include "UltraTimeStretch.h"
#include "UltraTimeStretch_V2_Enhancements.h"
#include <iostream>
#include <fstream>
#include <vector>
#include <iomanip>

using namespace UltraTimeStretch;
using namespace UltraTimeStretch::V2;

// Helper function to generate test audio
void generateTestAudio(std::vector<float>& audio, int sampleRate, int duration) {
    audio.resize(duration * 2);  // Stereo
    
    for (int i = 0; i < duration; ++i) {
        float t = (float)i / sampleRate;
        
        // Complex test signal with multiple components:
        // 1. Fundamental tone (440 Hz)
        float fundamental = 0.3f * std::sin(2.0f * PI * 440.0f * t);
        
        // 2. Harmonics
        float harmonics = 0.15f * std::sin(2.0f * PI * 880.0f * t) +
                         0.1f * std::sin(2.0f * PI * 1320.0f * t);
        
        // 3. Transient events (percussive)
        float transient = 0.0f;
        if ((int)(t * 2) % 2 == 0 && std::fmod(t, 0.5f) < 0.01f) {
            transient = 0.8f * std::exp(-100.0f * std::fmod(t, 0.5f));
        }
        
        float sample = fundamental + harmonics + transient;
        
        // Stereo
        audio[i * 2] = sample;
        audio[i * 2 + 1] = sample * 0.9f;  // Slight difference for stereo
    }
}

// Calculate audio statistics
void analyzeAudio(const float* audio, int numSamples, const char* label) {
    float maxSample = 0.0f;
    float rms = 0.0f;
    
    for (int i = 0; i < numSamples; ++i) {
        maxSample = std::max(maxSample, std::abs(audio[i]));
        rms += audio[i] * audio[i];
    }
    rms = std::sqrt(rms / numSamples);
    
    std::cout << label << " - Max: " << maxSample << ", RMS: " << rms << std::endl;
}

int main() {
    std::cout << "╔════════════════════════════════════════════════════════════╗\n";
    std::cout << "║      UltraTimeStretch V2 - Enhanced Features Demo         ║\n";
    std::cout << "╚════════════════════════════════════════════════════════════╝\n\n";
    
    int sampleRate = 44100;
    int channels = 2;
    int testDuration = 44100 * 2;  // 2 seconds
    
    // ═══════════════════════════════════════════════════════════════
    // TEST 1: V2 Engine with UltraQuality at Extreme Slow Speed
    // ═══════════════════════════════════════════════════════════════
    std::cout << "\n┌─────────────────────────────────────────────────────────┐\n";
    std::cout << "│  TEST 1: V2 UltraQuality @ 0.1x (10x slower)           │\n";
    std::cout << "└─────────────────────────────────────────────────────────┘\n";
    
    {
        EngineV2 engine;
        Options options;
        options.quality = Quality::UltraQuality;
        options.preserveTransients = true;
        options.preserveFormants = true;
        options.antiAliasing = true;
        
        if (!engine.initialize(sampleRate, channels, options)) {
            std::cerr << "Failed to initialize V2 engine!\n";
            return -1;
        }
        
        engine.setSpeed(0.1f);
        
        std::cout << "  ✓ Engine initialized with Multi-Resolution PV\n";
        std::cout << "  ✓ Speed: 0.1x (extreme slow)\n";
        std::cout << "  ✓ Latency: " << engine.getLatency() << " samples\n";
        
        // Generate test audio
        std::vector<float> input;
        generateTestAudio(input, sampleRate, testDuration);
        
        // Process
        int maxOutputSize = engine.getRequiredOutputBufferSize(testDuration * channels);
        std::vector<float> output(maxOutputSize);
        
        int outputFrames = engine.processV2(
            input.data(), testDuration,
            output.data(), maxOutputSize / channels
        );
        
        std::cout << "  Input:  " << testDuration << " frames\n";
        std::cout << "  Output: " << outputFrames << " frames\n";
        std::cout << "  Ratio:  " << (float)outputFrames / testDuration << "x\n";
        
        analyzeAudio(input.data(), testDuration * channels, "  Input stats ");
        analyzeAudio(output.data(), outputFrames * channels, "  Output stats");
        
        engine.shutdown();
    }
    
    // ═══════════════════════════════════════════════════════════════
    // TEST 2: Multi-Resolution Phase Vocoder Standalone
    // ═══════════════════════════════════════════════════════════════
    std::cout << "\n┌─────────────────────────────────────────────────────────┐\n";
    std::cout << "│  TEST 2: Multi-Resolution PV Standalone                │\n";
    std::cout << "└─────────────────────────────────────────────────────────┘\n";
    
    {
        float testSpeed = 0.1f;
        MultiResolutionPV multiResPV(sampleRate, testSpeed);
        
        std::cout << multiResPV.getInfo() << std::endl;
        
        // Generate mono test
        std::vector<float> monoInput(testDuration);
        for (int i = 0; i < testDuration; ++i) {
            float t = (float)i / sampleRate;
            monoInput[i] = 0.5f * std::sin(2.0f * PI * 440.0f * t);
        }
        
        std::vector<float> output(testDuration * 20);
        int outputSamples = 0;
        
        multiResPV.process(monoInput.data(), testDuration, output.data(), outputSamples);
        
        std::cout << "  Processed: " << testDuration << " → " << outputSamples << " samples\n";
    }
    
    // ═══════════════════════════════════════════════════════════════
    // TEST 3: Harmonic-Percussive Separation
    // ═══════════════════════════════════════════════════════════════
    std::cout << "\n┌─────────────────────────────────────────────────────────┐\n";
    std::cout << "│  TEST 3: Harmonic-Percussive Separation                │\n";
    std::cout << "└─────────────────────────────────────────────────────────┘\n";
    
    {
        int fftSize = 2048;
        HarmonicPercussiveSeparator hps(fftSize, sampleRate);
        
        // Generate test with both harmonic and percussive
        std::vector<float> mixedSignal(fftSize);
        for (int i = 0; i < fftSize; ++i) {
            float t = (float)i / sampleRate;
            
            // Harmonic component
            float harmonic = 0.5f * std::sin(2.0f * PI * 440.0f * t);
            
            // Percussive component (sharp attack)
            float percussive = (i < 100) ? 0.8f * std::exp(-i / 10.0f) : 0.0f;
            
            mixedSignal[i] = harmonic + percussive;
        }
        
        std::vector<float> harmonicOut(fftSize);
        std::vector<float> percussiveOut(fftSize);
        
        hps.separate(mixedSignal.data(), fftSize, 
                     harmonicOut.data(), percussiveOut.data());
        
        analyzeAudio(mixedSignal.data(), fftSize, "  Mixed     ");
        analyzeAudio(harmonicOut.data(), fftSize, "  Harmonic  ");
        analyzeAudio(percussiveOut.data(), fftSize, "  Percussive");
    }
    
    // ═══════════════════════════════════════════════════════════════
    // TEST 4: Spectral Peak Interpolation
    // ═══════════════════════════════════════════════════════════════
    std::cout << "\n┌─────────────────────────────────────────────────────────┐\n";
    std::cout << "│  TEST 4: Spectral Peak Interpolation                   │\n";
    std::cout << "└─────────────────────────────────────────────────────────┘\n";
    
    {
        int fftSize = 1024;
        SpectralPeakInterpolator interpolator(fftSize);
        
        // Create test spectrum with known peaks
        std::vector<float> magnitudes(fftSize / 2 + 1, 0.0f);
        std::vector<float> phases(fftSize / 2 + 1, 0.0f);
        
        // Add some peaks
        magnitudes[50] = 0.5f;
        magnitudes[100] = 0.8f;
        magnitudes[200] = 0.3f;
        
        // Add parabolic shape around peaks
        for (int k = 48; k <= 52; ++k) {
            magnitudes[k] = 0.5f - 0.1f * std::abs(k - 50);
        }
        
        std::vector<float> interpMag, interpPhase;
        interpolator.interpolatePeaks(magnitudes, phases, interpMag, interpPhase);
        
        auto peaks = interpolator.getPeakIndices();
        std::cout << "  Detected " << peaks.size() << " peaks:\n";
        
        for (int peakIdx : peaks) {
            float freq = interpolator.getPeakFrequency(peakIdx);
            float mag = interpolator.getPeakMagnitude(peakIdx);
            std::cout << "    Bin " << peakIdx 
                      << " → Freq " << std::fixed << std::setprecision(2) << freq 
                      << ", Mag " << mag << "\n";
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // TEST 5: Formant Preservation
    // ═══════════════════════════════════════════════════════════════
    std::cout << "\n┌─────────────────────────────────────────────────────────┐\n";
    std::cout << "│  TEST 5: Formant Preservation                           │\n";
    std::cout << "└─────────────────────────────────────────────────────────┘\n";
    
    {
        int fftSize = 2048;
        FormantPreserver formantPreserver(fftSize, sampleRate);
        
        // Create spectrum with formant structure
        std::vector<float> magnitudes(fftSize / 2 + 1);
        
        // Simulate formants (peaks in spectral envelope)
        for (int k = 0; k < fftSize / 2 + 1; ++k) {
            float freq = (float)k * sampleRate / fftSize;
            
            // Formant 1 around 800 Hz
            float f1 = std::exp(-std::pow((freq - 800.0f) / 100.0f, 2.0f));
            
            // Formant 2 around 1200 Hz
            float f2 = 0.7f * std::exp(-std::pow((freq - 1200.0f) / 150.0f, 2.0f));
            
            magnitudes[k] = f1 + f2;
        }
        
        formantPreserver.extractEnvelope(magnitudes);
        
        const auto& envelope = formantPreserver.getEnvelope();
        
        std::cout << "  Formant envelope extracted\n";
        std::cout << "  Envelope size: " << envelope.size() << "\n";
        
        // Find peaks in envelope
        int peakCount = 0;
        for (size_t k = 1; k < envelope.size() - 1; ++k) {
            if (envelope[k] > envelope[k-1] && envelope[k] > envelope[k+1] && 
                envelope[k] > 0.3f) {
                float freq = (float)k * sampleRate / fftSize;
                std::cout << "  Formant peak at " << freq << " Hz\n";
                peakCount++;
            }
        }
        std::cout << "  Total formant peaks: " << peakCount << "\n";
    }
    
    // ═══════════════════════════════════════════════════════════════
    // TEST 6: Comparison V1 vs V2 at 0.1x
    // ═══════════════════════════════════════════════════════════════
    std::cout << "\n┌─────────────────────────────────────────────────────────┐\n";
    std::cout << "│  TEST 6: V1 vs V2 Quality Comparison @ 0.1x            │\n";
    std::cout << "└─────────────────────────────────────────────────────────┘\n";
    
    {
        // V1 Engine
        Engine engineV1;
        Options optsV1;
        optsV1.quality = Quality::HighQuality;
        engineV1.initialize(sampleRate, channels, optsV1);
        engineV1.setSpeed(0.1f);
        
        // V2 Engine
        EngineV2 engineV2;
        Options optsV2;
        optsV2.quality = Quality::UltraQuality;
        engineV2.initialize(sampleRate, channels, optsV2);
        engineV2.setSpeed(0.1f);
        
        // Generate test
        std::vector<float> input;
        generateTestAudio(input, sampleRate, 22050);  // 0.5 second
        
        // Process V1
        std::vector<float> outputV1(22050 * 20);
        int framesV1 = engineV1.processInterleaved(
            input.data(), 22050,
            outputV1.data(), 22050 * 10
        );
        
        // Process V2
        std::vector<float> outputV2(22050 * 20);
        int framesV2 = engineV2.processV2(
            input.data(), 22050,
            outputV2.data(), 22050 * 10
        );
        
        std::cout << "  V1 Output: " << framesV1 << " frames\n";
        std::cout << "  V2 Output: " << framesV2 << " frames\n";
        
        analyzeAudio(outputV1.data(), framesV1 * channels, "  V1 Quality");
        analyzeAudio(outputV2.data(), framesV2 * channels, "  V2 Quality");
        
        engineV1.shutdown();
        engineV2.shutdown();
    }
    
    std::cout << "\n╔════════════════════════════════════════════════════════════╗\n";
    std::cout << "║              All V2 Tests Completed!                       ║\n";
    std::cout << "╚════════════════════════════════════════════════════════════╝\n";
    
    return 0;
}
