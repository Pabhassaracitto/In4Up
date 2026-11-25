/// The audio source is independent of the speech-recognition engine.
/// System playback requires the offline engine because platform STT owns the mic.
enum CabinAudioSource { microphone, systemAudio }
