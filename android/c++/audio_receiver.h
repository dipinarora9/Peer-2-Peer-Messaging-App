#ifndef ANDROID_AUDIO_RECEIVER_H
#define ANDROID_AUDIO_RECEIVER_H

#include <oboe/Oboe.h>
#include <../../../src/oboe/src/common/OboeDebug.h>
#include "include/dart_api.h"
#include "include/dart_native_api.h"
#include "include/dart_api_dl.h"


class P2P : public oboe::AudioStreamCallback {
public:
    int32_t input();

    int32_t output();

    oboe::DataCallbackResult
    onAudioReady(oboe::AudioStream *oboeStream, void *audioData, int32_t numFrames) override;

    oboe::ManagedStream outStream;
    oboe::ManagedStream inStream;

    void setIsRecording(bool);

    bool getIsRecording() { return isRecording; }

    void setDartPort(Dart_Port p) { this->dartPort = p; }

    Dart_Port getDartPort() { return this->dartPort; }

    Dart_Port getCppPort() { return this->cppPort; }

    Dart_Port initializeCppNative() {
        cppPort = Dart_NewNativePort_DL("cppPort", &nativeHandler, false);
        return cppPort;
    }

    static void nativeHandler(Dart_Port_DL p, Dart_CObject *message);

private:
    bool isRecording{false};
    Dart_Port dartPort;
    Dart_Port cppPort;
};

#endif //ANDROID_AUDIO_RECEIVER_H
