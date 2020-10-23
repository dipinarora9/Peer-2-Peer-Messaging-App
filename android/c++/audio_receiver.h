#ifndef ANDROID_AUDIO_RECEIVER_H
#define ANDROID_AUDIO_RECEIVER_H

#include <oboe/Oboe.h>
#include <../../../src/oboe/src/common/OboeDebug.h>
//#include "dart_api.h"
//#include "dart_native_api.h"
//#include "dart_api_dl.h"
#include "include/dart_api.h"
#include "include/dart_native_api.h"
#include "include/dart_api_dl.h"
#include <thread>
//#include <../../../src/flutter/bin/cache/dart-sdk/include/dart_api.h>
//#include <../../../src/flutter/bin/cache/dart-sdk/include/dart_api_dl2.h>
//#include <../../../src/flutter/bin/cache/dart-sdk/include/dart_native_api2.h>

//typedef bool (*Dart_PostCObjectType)(Dart_Port port_id, Dart_CObject* message);
//Dart_PostCObjectType Dart_PostCObject_DIPIN;

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

private:
    bool isRecording{false};
    Dart_Port dartPort;
};

#endif //ANDROID_AUDIO_RECEIVER_H
