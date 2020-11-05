#ifndef ANDROID_AUDIO_RECEIVER_H
#define ANDROID_AUDIO_RECEIVER_H

#include <oboe/Oboe.h>
#include <android/log.h>
#include <../../../src/oboe/src/common/OboeDebug.h>
#include "include/dart_api.h"
#include "include/dart_native_api.h"
#include "include/dart_api_dl.h"
#include <vector>
#include <string>

class P2POutput : public oboe::AudioStreamCallback {
public:
    int32_t output();

    oboe::DataCallbackResult
    onAudioReady(oboe::AudioStream *oboeStream, void *audioData, int32_t numFrames) override;

    oboe::ManagedStream outStream;

    float *buffer = nullptr;
    int64_t buffer_index = 0;
    int64_t player_index = 0;

    void setDartPort(Dart_Port p) { this->dartPort = p; }

    Dart_Port getDartPort() { return this->dartPort; }

    Dart_Port getCppPort() { return this->cppPort; }

    Dart_Port initializeCppNative() {
        cppPort = Dart_NewNativePort_DL("cppPort", &nativeHandler, false);
        return cppPort;
    }

    static void nativeHandler(Dart_Port_DL p, Dart_CObject *message);


    int32_t write(uint8_t *b, int32_t numFrames) {
        int32_t framesLeft = numFrames;
        if (player_index < 0) player_index++;
        while (framesLeft > 0) {
            int32_t indexFrame = buffer_index % MAXLIMIT;
            // contiguous writes
            int32_t framesToEnd = MAXLIMIT - indexFrame;
            int32_t framesNow = std::min(framesLeft, framesToEnd);
            int32_t numSamples = framesNow;
            int32_t sampleIndex = indexFrame;

            for (int i = 0; i < numSamples; i++)
                buffer[i + sampleIndex] = (double) b[i] / 255 * 2 - 1;

//            memcpy(&buffer[sampleIndex],
//                   b,
//                   (numSamples * sizeof(float)));
//            b += numSamples;
            buffer_index += framesNow;
            framesLeft -= framesNow;
        }
        return numFrames;
    }

    int32_t read(float *b, int32_t numFrames) {
        int32_t framesRead = 0;

        int32_t framesLeft = std::min(numFrames,
                                      std::min(MAXLIMIT, (int32_t) (buffer_index - player_index)));
        while (framesLeft > 0 && player_index >= 0) {
            int32_t indexFrame = player_index % MAXLIMIT;
            // contiguous reads
            int32_t framesToEnd = MAXLIMIT - indexFrame;
            int32_t framesNow = std::min(framesLeft, framesToEnd);
            int32_t numSamples = framesNow;
            int32_t sampleIndex = indexFrame;

            memcpy(b,
                   &buffer[sampleIndex],
                   (numSamples * sizeof(float)));

            player_index += framesNow;
            framesLeft -= framesNow;
            framesRead += framesNow;
        }
        return framesRead;
    }

private:
    Dart_Port dartPort;
    Dart_Port cppPort;
    int32_t MAXLIMIT;
};


class P2PInput : public oboe::AudioStreamCallback {
public:
    int32_t input();

    P2POutput *outputPlayer;

    oboe::DataCallbackResult
    onAudioReady(oboe::AudioStream *oboeStream, void *audioData, int32_t numFrames) override;

    oboe::ManagedStream inStream;

    void setIsRecording(bool);

    void setDartPort(Dart_Port p) { this->dartPort = p; }

    Dart_Port getDartPort() { return this->dartPort; }

private:
    bool isRecording{false};
    Dart_Port dartPort;
};

#endif //ANDROID_AUDIO_RECEIVER_H
