#include "audio_receiver.h"


DART_EXPORT intptr_t InitDartApiDL(void *data) {
    return Dart_InitializeApiDL(data);
}

DART_EXPORT
P2PInput *createINPlayer(P2POutput *output) {
    LOGE("HERE IS IT input INITIALIZED");
    auto *player = new P2PInput();
    player->setOutPlayer(output);
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

DART_EXPORT
int32_t playBuffer(P2POutput *player, uint8_t *b, int32_t frames) {
    player->write(b, frames);
    return 1;
}

void P2POutput::nativeHandler(Dart_Port_DL p, Dart_CObject *message) {
    LOGE("MESSAGE RECEIVED NATIVELY");
    Dart_CObject **c_response_args = message->value.as_array.values;
    Dart_CObject *c_pending_call = c_response_args[0];
    Dart_CObject *buffer = c_response_args[1];
    auto frames = reinterpret_cast<int32_t *>(c_response_args[2]);
    Dart_CObject *playPointer = c_response_args[3];
//    __android_log_print(ANDROID_LOG_INFO, "HERE IS IT DIPIN",
//                        "address %d",
//                        (int) playPointer);
    playBuffer(reinterpret_cast<P2POutput *>(playPointer), reinterpret_cast<uint8_t *>(buffer),
               *frames);
}

int sendPort(P2POutput *player) {
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
int64_t record(P2PInput *inPlayer, P2POutput *outPlayer, int8_t v, Dart_Port port) {
    LOGE("RECORD CALLED");
    inPlayer->setDartPort(port);
    outPlayer->setDartPort(port);
    inPlayer->setIsRecording(v);
    if (v)
        inPlayer->inStream->start();
    else inPlayer->inStream->stop();
    if (v) {
        outPlayer->initializeCppNative();
        return sendPort(outPlayer);
    }
    return 0;
}