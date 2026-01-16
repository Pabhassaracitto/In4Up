// SIMDOptimizations.h
#ifndef SIMD_OPTIMIZATIONS_H
#define SIMD_OPTIMIZATIONS_H

#include <cstdint>

namespace UltraTimeStretch {
namespace SIMD {

//==============================================================================
// Vector Operations
//==============================================================================

#if defined(UTS_USE_NEON)

// ARM NEON Optimizations
inline void multiplyAdd(float* dst, const float* src1, const float* src2, 
                        float scalar, int count) {
    float32x4_t vScalar = vdupq_n_f32(scalar);
    int i = 0;
    
    for (; i + 4 <= count; i += 4) {
        float32x4_t v1 = vld1q_f32(src1 + i);
        float32x4_t v2 = vld1q_f32(src2 + i);
        float32x4_t vDst = vld1q_f32(dst + i);
        
        v1 = vmulq_f32(v1, v2);
        v1 = vmulq_f32(v1, vScalar);
        vDst = vaddq_f32(vDst, v1);
        
        vst1q_f32(dst + i, vDst);
    }
    
    // Handle remaining
    for (; i < count; ++i) {
        dst[i] += src1[i] * src2[i] * scalar;
    }
}

inline void applyWindow(float* data, const float* window, int count) {
    int i = 0;
    for (; i + 4 <= count; i += 4) {
        float32x4_t vData = vld1q_f32(data + i);
        float32x4_t vWindow = vld1q_f32(window + i);
        vData = vmulq_f32(vData, vWindow);
        vst1q_f32(data + i, vData);
    }
    for (; i < count; ++i) {
        data[i] *= window[i];
    }
}

inline float sumSquares(const float* data, int count) {
    float32x4_t vSum = vdupq_n_f32(0.0f);
    int i = 0;
    
    for (; i + 4 <= count; i += 4) {
        float32x4_t v = vld1q_f32(data + i);
        vSum = vmlaq_f32(vSum, v, v);
    }
    
    float result = vgetq_lane_f32(vSum, 0) + vgetq_lane_f32(vSum, 1) +
                   vgetq_lane_f32(vSum, 2) + vgetq_lane_f32(vSum, 3);
    
    for (; i < count; ++i) {
        result += data[i] * data[i];
    }
    
    return result;
}

inline void complexMultiply(float* realA, float* imagA, 
                            const float* realB, const float* imagB, int count) {
    int i = 0;
    for (; i + 4 <= count; i += 4) {
        float32x4_t ra = vld1q_f32(realA + i);
        float32x4_t ia = vld1q_f32(imagA + i);
        float32x4_t rb = vld1q_f32(realB + i);
        float32x4_t ib = vld1q_f32(imagB + i);
        
        // (a + bi)(c + di) = (ac - bd) + (ad + bc)i
        float32x4_t realResult = vsubq_f32(vmulq_f32(ra, rb), vmulq_f32(ia, ib));
        float32x4_t imagResult = vaddq_f32(vmulq_f32(ra, ib), vmulq_f32(ia, rb));
        
        vst1q_f32(realA + i, realResult);
        vst1q_f32(imagA + i, imagResult);
    }
    
    for (; i < count; ++i) {
        float tempReal = realA[i] * realB[i] - imagA[i] * imagB[i];
        float tempImag = realA[i] * imagB[i] + imagA[i] * realB[i];
        realA[i] = tempReal;
        imagA[i] = tempImag;
    }
}

#elif defined(UTS_USE_SSE)

// x86 SSE/AVX Optimizations
inline void multiplyAdd(float* dst, const float* src1, const float* src2, 
                        float scalar, int count) {
    __m128 vScalar = _mm_set1_ps(scalar);
    int i = 0;
    
    for (; i + 4 <= count; i += 4) {
        __m128 v1 = _mm_loadu_ps(src1 + i);
        __m128 v2 = _mm_loadu_ps(src2 + i);
        __m128 vDst = _mm_loadu_ps(dst + i);
        
        v1 = _mm_mul_ps(v1, v2);
        v1 = _mm_mul_ps(v1, vScalar);
        vDst = _mm_add_ps(vDst, v1);
        
        _mm_storeu_ps(dst + i, vDst);
    }
    
    for (; i < count; ++i) {
        dst[i] += src1[i] * src2[i] * scalar;
    }
}

inline void applyWindow(float* data, const float* window, int count) {
    int i = 0;
    for (; i + 4 <= count; i += 4) {
        __m128 vData = _mm_loadu_ps(data + i);
        __m128 vWindow = _mm_loadu_ps(window + i);
        vData = _mm_mul_ps(vData, vWindow);
        _mm_storeu_ps(data + i, vData);
    }
    for (; i < count; ++i) {
        data[i] *= window[i];
    }
}

inline float sumSquares(const float* data, int count) {
    __m128 vSum = _mm_setzero_ps();
    int i = 0;
    
    for (; i + 4 <= count; i += 4) {
        __m128 v = _mm_loadu_ps(data + i);
        v = _mm_mul_ps(v, v);
        vSum = _mm_add_ps(vSum, v);
    }
    
    // Horizontal sum
    __m128 shuf = _mm_shuffle_ps(vSum, vSum, _MM_SHUFFLE(2, 3, 0, 1));
    vSum = _mm_add_ps(vSum, shuf);
    shuf = _mm_movehl_ps(shuf, vSum);
    vSum = _mm_add_ss(vSum, shuf);
    
    float result = _mm_cvtss_f32(vSum);
    
    for (; i < count; ++i) {
        result += data[i] * data[i];
    }
    
    return result;
}

#else

// Scalar fallback
inline void multiplyAdd(float* dst, const float* src1, const float* src2, 
                        float scalar, int count) {
    for (int i = 0; i < count; ++i) {
        dst[i] += src1[i] * src2[i] * scalar;
    }
}

inline void applyWindow(float* data, const float* window, int count) {
    for (int i = 0; i < count; ++i) {
        data[i] *= window[i];
    }
}

inline float sumSquares(const float* data, int count) {
    float result = 0.0f;
    for (int i = 0; i < count; ++i) {
        result += data[i] * data[i];
    }
    return result;
}

#endif

} // namespace SIMD
} // namespace UltraTimeStretch

#endif // SIMD_OPTIMIZATIONS_H