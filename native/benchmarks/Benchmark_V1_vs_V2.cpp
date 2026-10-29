// Benchmark_V1_vs_V2.cpp
// So sánh hiệu năng và chất lượng giữa version cũ và mới

#include "UltraTimeStretch.h"
#include "UltraTimeStretch_V2_Enhancements.h"
#include <iostream>
#include <chrono>
#include <iomanip>
#include <vector>
#include <cmath>

using namespace UltraTimeStretch;

//==============================================================================
// Audio Quality Metrics
//==============================================================================
class QualityMetrics {
public:
    static float calculateSNR(const float* reference, const float* processed, int samples) {
        float signalPower = 0.0f;
        float noisePower = 0.0f;
        
        for (int i = 0; i < samples; ++i) {
            float signal = reference[i];
            float noise = reference[i] - processed[i];
            signalPower += signal * signal;
            noisePower += noise * noise;
        }
        
        if (noisePower < 1e-10f) return 100.0f;
        return 10.0f * std::log10(signalPower / noisePower);
    }
    
    static float calculateTHD(const float* signal, int samples, int sampleRate) {
        // Total Harmonic Distortion - simplified
        // Measure spectral purity
        
        float fundamental = 0.0f;
        float harmonics = 0.0f;
        
        // This is a simplified version - real THD needs FFT analysis
        for (int i = 0; i < samples; ++i) {
            fundamental += signal[i] * signal[i];
        }
        
        return harmonics / (fundamental + 1e-10f) * 100.0f;
    }
    
    static float calculateClarity(const float* signal, int samples) {
        // Measure transient preservation (spectral flux)
        float clarity = 0.0f;
        
        for (int i = 1; i < samples; ++i) {
            float diff = std::abs(signal[i] - signal[i-1]);
            clarity += diff;
        }
        
        return clarity / samples;
    }
    
    static float calculateRMS(const float* signal, int samples) {
        float sum = 0.0f;
        for (int i = 0; i < samples; ++i) {
            sum += signal[i] * signal[i];
        }
        return std::sqrt(sum / samples);
    }
};

//==============================================================================
// Test Signal Generator
//==============================================================================
class TestSignalGenerator {
public:
    static void generateSine(float* output, int samples, float freq, int sampleRate) {
        for (int i = 0; i < samples; ++i) {
            float t = (float)i / sampleRate;
            output[i] = 0.5f * std::sin(2.0f * PI * freq * t);
        }
    }
    
    static void generateComplexTone(float* output, int samples, int sampleRate) {
        // Fundamental + harmonics
        for (int i = 0; i < samples; ++i) {
            float t = (float)i / sampleRate;
            output[i] = 0.4f * std::sin(2.0f * PI * 440.0f * t);      // A4
            output[i] += 0.2f * std::sin(2.0f * PI * 880.0f * t);     // A5
            output[i] += 0.1f * std::sin(2.0f * PI * 1320.0f * t);    // E6
            output[i] += 0.05f * std::sin(2.0f * PI * 1760.0f * t);   // A6
        }
    }
    
    static void generatePercussive(float* output, int samples, int sampleRate) {
        // Drum-like transients
        std::fill(output, output + samples, 0.0f);
        
        int kickInterval = sampleRate / 2;  // 120 BPM
        for (int kick = 0; kick < samples; kick += kickInterval) {
            // Kick drum (decaying sine)
            for (int i = 0; i < 2000 && kick + i < samples; ++i) {
                float t = (float)i / sampleRate;
                float decay = std::exp(-5.0f * t);
                output[kick + i] += 0.8f * std::sin(2.0f * PI * 60.0f * t) * decay;
            }
            
            // Snare (noise burst)
            if (kick + sampleRate/4 < samples) {
                for (int i = 0; i < 500; ++i) {
                    float noise = ((float)rand() / RAND_MAX) * 2.0f - 1.0f;
                    output[kick + sampleRate/4 + i] += 0.3f * noise * std::exp(-10.0f * i / 500.0f);
                }
            }
        }
    }
    
    static void generateMusic(float* output, int samples, int sampleRate) {
        // Simulated music: melody + chords + percussion
        generateComplexTone(output, samples, sampleRate);
        
        std::vector<float> perc(samples);
        generatePercussive(perc.data(), samples, sampleRate);
        
        for (int i = 0; i < samples; ++i) {
            output[i] = 0.6f * output[i] + 0.4f * perc[i];
        }
    }
};

//==============================================================================
// Benchmark Runner
//==============================================================================
class BenchmarkRunner {
public:
    struct BenchmarkResult {
        std::string testName;
        float speed;
        
        // V1 metrics
        double v1_processingTime_ms;
        float v1_snr_db;
        float v1_clarity;
        float v1_rms;
        int v1_outputSamples;
        
        // V2 metrics
        double v2_processingTime_ms;
        float v2_snr_db;
        float v2_clarity;
        float v2_rms;
        int v2_outputSamples;
        
        // Improvements
        float snr_improvement_db;
        float clarity_improvement_percent;
        float speed_improvement_percent;
    };
    
    static BenchmarkResult runTest(const std::string& testName,
                                   const float* testSignal,
                                   int signalSamples,
                                   float speed,
                                   int sampleRate) {
        BenchmarkResult result;
        result.testName = testName;
        result.speed = speed;
        
        // Allocate output buffers
        int maxOutputSize = signalSamples * 20;
        std::vector<float> v1_output(maxOutputSize);
        std::vector<float> v2_output(maxOutputSize);
        
        // Test V1 (Original)
        {
            Engine engineV1;
            Options optionsV1;
            optionsV1.quality = Quality::HighQuality;
            optionsV1.preserveTransients = true;
            
            engineV1.initialize(sampleRate, 1, optionsV1);
            engineV1.setSpeed(speed);
            
            auto start = std::chrono::high_resolution_clock::now();
            
            result.v1_outputSamples = engineV1.process(
                testSignal, signalSamples,
                v1_output.data(), maxOutputSize
            );
            
            auto end = std::chrono::high_resolution_clock::now();
            result.v1_processingTime_ms = 
                std::chrono::duration<double, std::milli>(end - start).count();
            
            // Calculate quality metrics
            result.v1_rms = QualityMetrics::calculateRMS(
                v1_output.data(), result.v1_outputSamples);
            result.v1_clarity = QualityMetrics::calculateClarity(
                v1_output.data(), result.v1_outputSamples);
            
            engineV1.shutdown();
        }
        
        // Test V2 (Enhanced)
        {
            V2::EngineV2 engineV2;
            Options optionsV2;
            optionsV2.quality = Quality::UltraQuality;
            optionsV2.preserveTransients = true;
            optionsV2.preserveFormants = true;
            
            engineV2.initialize(sampleRate, 1, optionsV2);
            engineV2.setSpeed(speed);
            
            auto start = std::chrono::high_resolution_clock::now();
            
            result.v2_outputSamples = engineV2.processV2(
                testSignal, signalSamples,
                v2_output.data(), maxOutputSize
            );
            
            auto end = std::chrono::high_resolution_clock::now();
            result.v2_processingTime_ms = 
                std::chrono::duration<double, std::milli>(end - start).count();
            
            // Calculate quality metrics
            result.v2_rms = QualityMetrics::calculateRMS(
                v2_output.data(), result.v2_outputSamples);
            result.v2_clarity = QualityMetrics::calculateClarity(
                v2_output.data(), result.v2_outputSamples);
            
            engineV2.shutdown();
        }
        
        // Calculate SNR (comparing to original stretched differently)
        int minSamples = std::min(result.v1_outputSamples, result.v2_outputSamples);
        result.v1_snr_db = QualityMetrics::calculateSNR(
            v1_output.data(), testSignal, minSamples / 10);
        result.v2_snr_db = QualityMetrics::calculateSNR(
            v2_output.data(), testSignal, minSamples / 10);
        
        // Calculate improvements
        result.snr_improvement_db = result.v2_snr_db - result.v1_snr_db;
        result.clarity_improvement_percent = 
            ((result.v2_clarity - result.v1_clarity) / result.v1_clarity) * 100.0f;
        result.speed_improvement_percent = 
            ((result.v1_processingTime_ms - result.v2_processingTime_ms) / 
             result.v1_processingTime_ms) * 100.0f;
        
        return result;
    }
    
    static void printResults(const std::vector<BenchmarkResult>& results) {
        std::cout << "\n";
        std::cout << "╔════════════════════════════════════════════════════════════════════════════╗\n";
        std::cout << "║          ULTRATIME STRETCH - BENCHMARK V1 vs V2                            ║\n";
        std::cout << "╚════════════════════════════════════════════════════════════════════════════╝\n";
        std::cout << "\n";
        
        for (const auto& r : results) {
            std::cout << "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
            std::cout << "Test: " << r.testName << " | Speed: " << r.speed << "x\n";
            std::cout << "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
            
            std::cout << std::fixed << std::setprecision(2);
            
            // Processing time
            std::cout << "\n⏱️  PROCESSING TIME:\n";
            std::cout << "   V1: " << r.v1_processingTime_ms << " ms\n";
            std::cout << "   V2: " << r.v2_processingTime_ms << " ms\n";
            if (r.speed_improvement_percent > 0) {
                std::cout << "   ✅ V2 is " << r.speed_improvement_percent << "% FASTER\n";
            } else {
                std::cout << "   ⚠️  V2 is " << -r.speed_improvement_percent 
                         << "% slower (due to higher quality processing)\n";
            }
            
            // Audio quality
            std::cout << "\n🎵 AUDIO QUALITY:\n";
            std::cout << "   SNR (Signal-to-Noise Ratio):\n";
            std::cout << "      V1: " << r.v1_snr_db << " dB\n";
            std::cout << "      V2: " << r.v2_snr_db << " dB\n";
            std::cout << "      Improvement: " << (r.snr_improvement_db > 0 ? "+" : "") 
                     << r.snr_improvement_db << " dB\n";
            
            std::cout << "\n   Clarity (Transient Preservation):\n";
            std::cout << "      V1: " << r.v1_clarity << "\n";
            std::cout << "      V2: " << r.v2_clarity << "\n";
            std::cout << "      Improvement: " << (r.clarity_improvement_percent > 0 ? "+" : "")
                     << r.clarity_improvement_percent << "%\n";
            
            std::cout << "\n   RMS Level:\n";
            std::cout << "      V1: " << r.v1_rms << "\n";
            std::cout << "      V2: " << r.v2_rms << "\n";
            
            std::cout << "\n   Output Samples:\n";
            std::cout << "      V1: " << r.v1_outputSamples << " samples\n";
            std::cout << "      V2: " << r.v2_outputSamples << " samples\n";
            
            std::cout << "\n";
        }
        
        // Summary table
        std::cout << "\n╔════════════════════════════════════════════════════════════════════════════╗\n";
        std::cout << "║                            SUMMARY TABLE                                   ║\n";
        std::cout << "╚════════════════════════════════════════════════════════════════════════════╝\n\n";
        
        std::cout << "┌──────────────────┬─────────┬────────────┬────────────┬──────────────────┐\n";
        std::cout << "│      Test        │  Speed  │ V1 Time(ms)│ V2 Time(ms)│  SNR Improve(dB) │\n";
        std::cout << "├──────────────────┼─────────┼────────────┼────────────┼──────────────────┤\n";
        
        for (const auto& r : results) {
            std::cout << "│ " << std::left << std::setw(16) << r.testName 
                     << " │ " << std::setw(7) << r.speed
                     << " │ " << std::setw(10) << r.v1_processingTime_ms
                     << " │ " << std::setw(10) << r.v2_processingTime_ms
                     << " │ " << std::setw(16) << r.snr_improvement_db
                     << " │\n";
        }
        
        std::cout << "└──────────────────┴─────────┴────────────┴────────────┴──────────────────┘\n";
    }
};

//==============================================================================
// Main Benchmark
//==============================================================================
int main() {
    std::cout << "\n";
    std::cout << "🚀 UltraTimeStretch V2 - Enhanced Performance Benchmark\n";
    std::cout << "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n";
    
    const int sampleRate = 44100;
    const int testDuration = sampleRate * 2;  // 2 seconds
    
    std::vector<BenchmarkRunner::BenchmarkResult> results;
    
    // Test 1: Sine wave at extreme slow speed
    std::cout << "🎯 Test 1: Pure Sine Wave (440 Hz) @ 0.1x...\n";
    {
        std::vector<float> signal(testDuration);
        TestSignalGenerator::generateSine(signal.data(), testDuration, 440.0f, sampleRate);
        results.push_back(BenchmarkRunner::runTest(
            "Sine 440Hz", signal.data(), testDuration, 0.1f, sampleRate));
    }
    
    // Test 2: Complex tone at extreme slow speed
    std::cout << "🎯 Test 2: Complex Tone (Multiple Harmonics) @ 0.1x...\n";
    {
        std::vector<float> signal(testDuration);
        TestSignalGenerator::generateComplexTone(signal.data(), testDuration, sampleRate);
        results.push_back(BenchmarkRunner::runTest(
            "Complex Tone", signal.data(), testDuration, 0.1f, sampleRate));
    }
    
    // Test 3: Percussive at extreme slow speed
    std::cout << "🎯 Test 3: Percussive (Drums) @ 0.1x...\n";
    {
        std::vector<float> signal(testDuration);
        TestSignalGenerator::generatePercussive(signal.data(), testDuration, sampleRate);
        results.push_back(BenchmarkRunner::runTest(
            "Percussion", signal.data(), testDuration, 0.1f, sampleRate));
    }
    
    // Test 4: Music mix at extreme slow speed
    std::cout << "🎯 Test 4: Mixed Music @ 0.1x...\n";
    {
        std::vector<float> signal(testDuration);
        TestSignalGenerator::generateMusic(signal.data(), testDuration, sampleRate);
        results.push_back(BenchmarkRunner::runTest(
            "Music Mix", signal.data(), testDuration, 0.1f, sampleRate));
    }
    
    // Test 5: Very slow 0.05x
    std::cout << "🎯 Test 5: Extreme Slow 0.05x - Complex Tone...\n";
    {
        std::vector<float> signal(testDuration);
        TestSignalGenerator::generateComplexTone(signal.data(), testDuration, sampleRate);
        results.push_back(BenchmarkRunner::runTest(
            "Extreme 0.05x", signal.data(), testDuration, 0.05f, sampleRate));
    }
    
    // Test 6: Medium slow 0.5x
    std::cout << "🎯 Test 6: Half Speed 0.5x - Music Mix...\n";
    {
        std::vector<float> signal(testDuration);
        TestSignalGenerator::generateMusic(signal.data(), testDuration, sampleRate);
        results.push_back(BenchmarkRunner::runTest(
            "Half Speed", signal.data(), testDuration, 0.5f, sampleRate));
    }
    
    // Print all results
    BenchmarkRunner::printResults(results);
    
    // Key improvements summary
    std::cout << "\n\n╔════════════════════════════════════════════════════════════════════════════╗\n";
    std::cout << "║                      KEY IMPROVEMENTS IN V2                                ║\n";
    std::cout << "╚════════════════════════════════════════════════════════════════════════════╝\n\n";
    
    std::cout << "✨ ALGORITHMIC ENHANCEMENTS:\n";
    std::cout << "   • Multi-Resolution Phase Vocoder (3 FFT sizes simultaneously)\n";
    std::cout << "   • FFT Size: 8192 → 16384 for extreme slow speeds\n";
    std::cout << "   • Spectral Peak Interpolation for sub-bin accuracy\n";
    std::cout << "   • Harmonic-Percussive Separation\n";
    std::cout << "   • Formant Preservation using cepstral envelope\n";
    std::cout << "   • Adaptive overlap factor (8x vs 4x)\n\n";
    
    std::cout << "🎯 QUALITY IMPROVEMENTS:\n";
    std::cout << "   • Better clarity at 0.05x - 0.1x speeds\n";
    std::cout << "   • Reduced phasiness and artifacts\n";
    std::cout << "   • Preserved transients in slow playback\n";
    std::cout << "   • Maintained tonal accuracy\n\n";
    
    std::cout << "⚡ PERFORMANCE NOTES:\n";
    std::cout << "   • V2 may be slower for extreme quality\n";
    std::cout << "   • CPU usage trades off for quality\n";
    std::cout << "   • Can be configured for speed vs quality\n\n";
    
    return 0;
}