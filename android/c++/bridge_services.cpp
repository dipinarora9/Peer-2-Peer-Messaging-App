#include "audio_receiver.h"


DART_EXPORT intptr_t InitDartApiDL(void *data) {
    return Dart_InitializeApiDL(data);
}

DART_EXPORT
P2PInput *createINPlayer() {
    LOGE("HERE IS IT input INITIALIZED");
    auto *player = new P2PInput();
    int s = player->input();
    if (s)
        return player;
    else return nullptr;
}

DART_EXPORT
P2POutput *createOUTPlayer() {
    LOGE("HERE IS IT output INITIALIZED");
    auto *player = new P2POutput();
    int r = player->output();
    if (r)
        return player;
    else return nullptr;
}

//DART_EXPORT
//int32_t stop(P2P *player) {
//    player->inStream->requestPause();
//    player->outStream->requestPause();
//    player->setIsRecording(false);
//    return 1;
//}
//
//DART_EXPORT
//int32_t resume(P2P *player) {
//    player->inStream->requestFlush();
//    player->inStream->requestStart();
//    player->outStream->requestStart();
//    player->setIsRecording(true);
//    return 1;
//}


//void run(P2P *player) {
//    const auto requestFrames = (int32_t) (2 *
//                                          (player->inStream->getSampleRate() / 1000));
//    LOGE("HERE IS IT STARTING THREAD");
//    uint8_t buffer[requestFrames];
//    int64_t timeout = 1e6 * 3;
//    while (player->getIsRecording()) {
//        auto result = player->inStream->read(buffer, requestFrames, timeout);
//        if (result != oboe::Result::OK) {
//            LOGE("HERE IS IT NHI CHLA ", oboe::convertToText(result.error()));
//            player->setIsRecording(false);
//        } else;
////            callback(player->getDartPort(), buffer, requestFrames);
//
//    }
//    LOGE("HERE IS IT ENDING THREAD");
//}

//DART_EXPORT
//int16_t getBuffer(P2P *player) {
//    LOGE("HERE IS IT native called getBuffer");
//    if (player == nullptr) {
//        LOGE("HERE IS IT native nhi chla bsdk");
//        return 0;
//    }
//
//    constexpr int millisecondToRecord = 2;
//    const auto requestFrames = (int32_t) (millisecondToRecord *
//                                          (player->inStream->getSampleRate() / 1000));
//    LOGE("HERE IS IT idhr hu");
//    uint8_t buffer[requestFrames];
//    int64_t timeout = 1000000 * 3;
//    int frameReads = 0;
//    do {
//        auto result = player->inStream->read(buffer, player->inStream->getBufferSizeInFrames(),
//                                             0);
//        if (result != oboe::Result::OK) break;
//        frameReads = result.value();
//    } while (frameReads != 0);
//    LOGE("HERE IS IT hoyga khaali");
//
////    auto *thread1 = new std::thread(run, player);
//    LOGE("HERE IS IT after starting the thread");
//    return 1;
//}

DART_EXPORT
int32_t playBuffer(P2POutput *player, int16_t *b, int32_t frames) {
    LOGE("HERE IS IT adding to buffer");

    player->buffer[player->buffer_index % 100] = std::make_pair(b, frames);
    player->buffer_index++;
    if (player->buffer_index == 500) {
        player->buffer_index = 0;
        player->player_index = 0;
    }
    return 1;
}

void P2PInput::nativeHandler(Dart_Port_DL p, Dart_CObject *message) {
    LOGE("MESSAGE RECEIVED NATIVELY");
    Dart_CObject **c_response_args = message->value.as_array.values;
    Dart_CObject *c_pending_call = c_response_args[0];
    Dart_CObject *buffer = c_response_args[1];
    auto frames = reinterpret_cast<int32_t *>(c_response_args[2]);
    Dart_CObject *playPointer = c_response_args[3];
//    playBuffer(reinterpret_cast<P2P *>(playPointer), reinterpret_cast<int16_t *>(buffer),
//               *frames);
}

void P2POutput::nativeHandler(Dart_Port_DL p, Dart_CObject *message) {
    LOGE("MESSAGE RECEIVED NATIVELY");
    Dart_CObject **c_response_args = message->value.as_array.values;
    Dart_CObject *c_pending_call = c_response_args[0];
    Dart_CObject *buffer = c_response_args[1];
    auto frames = reinterpret_cast<int32_t *>(c_response_args[2]);
    Dart_CObject *playPointer = c_response_args[3];
//    playBuffer(reinterpret_cast<P2P *>(playPointer), reinterpret_cast<int16_t *>(buffer),
//               *frames);
}

int sendPort(P2PInput *player) {
    Dart_CObject c_send_port;
    c_send_port.type = Dart_CObject_kSendPort;
    c_send_port.value.as_send_port.id = player->getCppPort();
    c_send_port.value.as_send_port.origin_id = ILLEGAL_PORT;

    Dart_CObject c_pending_call;
    c_pending_call.type = Dart_CObject_kNull;

    Dart_CObject c_method_name;
    c_method_name.type = Dart_CObject_kString;
    c_method_name.value.as_string = const_cast<char *>("send_port");

    Dart_CObject c_request_data;
    c_request_data.type = Dart_CObject_kNull;

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

    Dart_PostCObject_DL(player->getDartPort(), &c_request);
    LOGE("Sent");
    return 1;
}

DART_EXPORT
int64_t record(P2PInput *player, int8_t v, Dart_Port port) {
    LOGE("RECORD CALLED");
    player->setDartPort(port);
    player->setIsRecording(v);
    if (v) {
        player->initializeCppNative();
        return sendPort(player);
    }
    return 0;
}