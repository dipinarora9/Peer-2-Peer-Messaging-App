#include "audio_receiver.h"


//void callback(Dart_Port port, uint8_t *buffer, int32_t frames) {
//    Dart_CObject c_send_port;
//    c_send_port.type = Dart_CObject_kNull;
//
//    Dart_CObject c_pending_call;
//    c_pending_call.type = Dart_CObject_kNull;
//
//    Dart_CObject c_method_name;
//    c_method_name.type = Dart_CObject_kString;
//    c_method_name.value.as_string = const_cast<char *>("audio_buffer");
//
//    Dart_CObject c_request_data;
//    c_request_data.type = Dart_CObject_kExternalTypedData;
//    c_request_data.value.as_external_typed_data.type = Dart_TypedData_kUint8;
//    c_request_data.value.as_external_typed_data.length = frames;
//    c_request_data.value.as_external_typed_data.data =
//            buffer;
//    c_request_data.value.as_external_typed_data.peer = buffer;
//
//    Dart_CObject *c_request_arr[] = {&c_send_port, &c_pending_call,
//                                     &c_method_name, &c_request_data};
//    Dart_CObject c_request;
//    c_request.type = Dart_CObject_kArray;
//    c_request.value.as_array.values = c_request_arr;
//    c_request.value.as_array.length =
//            sizeof(c_request_arr) / sizeof(c_request_arr[0]);
//    LOGE("Sending message dart side now");
////    printf("C   :  Dart_PostCObject_(request: %" Px ", call: %" Px ").\n",
////            reinterpret_cast<intptr_t>(&c_request),
////            reinterpret_cast<intptr_t>(&c_pending_call));
////    Dart_PostCObject_DL(port, &c_request);
//    Dart_PostCObject_DL(port, &c_request);
////    LOGE("Sending message dart side now");
//}


DART_EXPORT intptr_t InitDartApiDL(void *data) {
    return Dart_InitializeApiDL(data);
}

DART_EXPORT
P2P *createPlayer() {
    LOGE("HERE IS IT native INITIALIZED");
    auto *player = new P2P();
    int r = player->output();
    int s = player->input();
    if (r && s)
        return player;
    else return nullptr;
}

DART_EXPORT
int32_t stop(P2P *player) {
    player->inStream->requestPause();
    player->outStream->requestPause();
    player->setIsRecording(false);
    return 1;
}

DART_EXPORT
int32_t resume(P2P *player) {
    player->inStream->requestFlush();
    player->inStream->requestStart();
    player->outStream->requestStart();
    player->setIsRecording(true);
    return 1;
}


void run(P2P *player) {
    const auto requestFrames = (int32_t) (2 *
                                          (player->inStream->getSampleRate() / 1000));
    LOGE("HERE IS IT STARTING THREAD");
    uint8_t buffer[requestFrames];
    int64_t timeout = 1e6 * 3;
    while (player->getIsRecording()) {
        auto result = player->inStream->read(buffer, requestFrames, timeout);
        if (result != oboe::Result::OK) {
            LOGE("HERE IS IT NHI CHLA ", oboe::convertToText(result.error()));
            player->setIsRecording(false);
        } else;
//            callback(player->getDartPort(), buffer, requestFrames);

    }
    LOGE("HERE IS IT ENDING THREAD");
}

DART_EXPORT
int16_t getBuffer(P2P *player) {
    LOGE("HERE IS IT native called getBuffer");
    if (player == nullptr) {
        LOGE("HERE IS IT native nhi chla bsdk");
        return 0;
    }

    constexpr int millisecondToRecord = 2;
    const auto requestFrames = (int32_t) (millisecondToRecord *
                                          (player->inStream->getSampleRate() / 1000));
    LOGE("HERE IS IT idhr hu");
    uint8_t buffer[requestFrames];
    int64_t timeout = 1000000 * 3;
    int frameReads = 0;
    do {
        auto result = player->inStream->read(buffer, player->inStream->getBufferSizeInFrames(),
                                             0);
        if (result != oboe::Result::OK) break;
        frameReads = result.value();
    } while (frameReads != 0);
    LOGE("HERE IS IT hoyga khaali");

    auto *thread1 = new std::thread(run, player);
    LOGE("HERE IS IT after starting the thread");
    return 1;
}

DART_EXPORT
int32_t playBuffer(P2P *player, int16_t *buffer, int32_t frames) {
    LOGE("HERE IS IT playing buffer");
    player->outStream->write(buffer, frames, 0);
    return 1;
}


DART_EXPORT
int32_t record(P2P *player, int8_t v, Dart_Port port) {
    LOGE("RECORD CALLED");
    player->setDartPort(port);
    player->setIsRecording(v);
//    if (v)
//        return getBuffer(player);
    return 1;
//    if (v)
//        return getBuffer(player, callback);
//    else return 1;
}
//DART_EXPORT
//int32_t *buf(P2P *player) {
//    return;
//}
