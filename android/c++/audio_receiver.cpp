#include "audio_receiver.h"


static void FreeFinalizer(void *, Dart_WeakPersistentHandle, void *value) {
//    free(value);
}

static void callback(Dart_Port port, int16_t *buffer, int32_t frames) {
    Dart_CObject c_send_port;
    c_send_port.type = Dart_CObject_kNull;

    Dart_CObject c_pending_call;
    c_pending_call.type = Dart_CObject_kNull;

    Dart_CObject c_method_name;
    c_method_name.type = Dart_CObject_kString;
    c_method_name.value.as_string = const_cast<char *>("audio_buffer");

    Dart_CObject c_request_data;
    c_request_data.type = Dart_CObject_kExternalTypedData;
    c_request_data.value.as_external_typed_data.type = Dart_TypedData_kInt16;
    c_request_data.value.as_external_typed_data.length = frames;
    c_request_data.value.as_external_typed_data.data =
            reinterpret_cast<uint8_t *>(buffer);
    c_request_data.value.as_external_typed_data.peer = buffer;
    c_request_data.value.as_external_typed_data.callback = FreeFinalizer;

    Dart_CObject *c_request_arr[] = {&c_send_port, &c_pending_call,
                                     &c_method_name, &c_request_data};
    Dart_CObject c_request;
    c_request.type = Dart_CObject_kArray;
    c_request.value.as_array.values = c_request_arr;
    c_request.value.as_array.length =
            sizeof(c_request_arr) / sizeof(c_request_arr[0]);

//    printf("C   :  Dart_PostCObject_(request: %" Px ", call: %" Px ").\n",
//            reinterpret_cast<intptr_t>(&c_request),
//            reinterpret_cast<intptr_t>(&c_pending_call));

    Dart_PostCObject_DL(port, &c_request);
    LOGE("Sent");
}

int32_t P2P::input() {
    oboe::AudioStreamBuilder builder;
    builder.setDirection(oboe::Direction::Input)
            ->setCallback(this)
            ->setSharingMode(oboe::SharingMode::Exclusive)
            ->setPerformanceMode(oboe::PerformanceMode::LowLatency)
            ->openManagedStream(inStream);

    auto result = inStream->requestStart();
    if (result != oboe::Result::OK) {
        LOGE("HERE IS IT error in", oboe::convertToText(result));
        return 0;
    }
    return 1;
}

int32_t P2P::output() {
    oboe::AudioStreamBuilder builder;
    builder.setSharingMode(oboe::SharingMode::Exclusive)
            ->setCallback(nullptr)
            ->setPerformanceMode(oboe::PerformanceMode::LowLatency)
            ->openManagedStream(outStream);

    auto result = outStream->requestStart();
    if (result != oboe::Result::OK) {
        LOGE("HERE IS IT error out", oboe::convertToText(result));
        return 0;
    }
    return 1;
}

void P2P::setIsRecording(bool r) { this->isRecording = r; }

oboe::DataCallbackResult
P2P::onAudioReady(oboe::AudioStream *oboeStream, void *audioData, int32_t numFrames) {
    if (this->isRecording) {
        callback(this->getDartPort(), (int16_t *) audioData, numFrames);
    }
    return oboe::DataCallbackResult::Continue;
}
