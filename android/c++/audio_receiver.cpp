#include "audio_receiver.h"

/*
 * #include <iostream>
using namespace std;

void printF(float *arr){
    for(int i=0;i<5;i++)
        std::cout << arr[i] <<" ";
    cout<<endl;
}
void printI(int *arr){
    for(int i=0;i<5;i++)
        std::cout << arr[i] << " ";
    cout<<endl;
}

int main() {
    int numFrames= 5;
    float fd[] = {0.86264, 0.7818, -0.18418, 0.8141, 0.471};
    int id[] = { 22684, 7818, -18418,  8141, 471};

	for (int i = 0; i < numFrames; i++)
            id[i] = ((double) id[i] / 32768 + 1) / 2 * 255;
    printI(id);

     for (int i = 0; i < numFrames; i++)
            id[i] = ((double) id[i] / 255 * 2 - 1) * 32768;

    printI(id);

    for (int i = 0; i < numFrames; i++)
            fd[i] = (fd[i] + 1)/2 * 255;
    printF(fd);

     for (int i = 0; i < numFrames; i++)
            fd[i] = fd[i] / 255 * 2 -1;

    printF(fd);

	return 0;
}

 * */
static void FreeFinalizer(void *, Dart_WeakPersistentHandle, void *value) {
//    free(value);
}

static void callback(Dart_Port port, const float *buffer, int32_t frames) {
    Dart_CObject c_send_port;
    c_send_port.type = Dart_CObject_kNull;

    Dart_CObject c_pending_call;
    c_pending_call.type = Dart_CObject_kNull;
    uint8_t sendBuffer[3 * frames];
    Dart_CObject c_method_name;
    c_method_name.type = Dart_CObject_kString;
    c_method_name.value.as_string = const_cast<char *>("audio_buffer");
    for (int i = 0; i < frames; i++)
        sendBuffer[i] = buffer[i] > 0 ? 0 : 1;
    for (int i = frames, j = 0; j < frames; i += 2, j++) {
        sendBuffer[i] = buffer[j] * 255.0;
        sendBuffer[i + 1] = (buffer[j] * 255.0 - sendBuffer[i]) * 255.0;
    }
    Dart_CObject c_request_data;
    c_request_data.type = Dart_CObject_kExternalTypedData;
    c_request_data.value.as_external_typed_data.type = Dart_TypedData_kUint8;
    c_request_data.value.as_external_typed_data.length = 3 * frames;
    c_request_data.value.as_external_typed_data.data = sendBuffer;
    c_request_data.value.as_external_typed_data.peer = sendBuffer;
    c_request_data.value.as_external_typed_data.callback = FreeFinalizer;

    Dart_CObject *c_request_arr[] = {&c_send_port, &c_pending_call,
                                     &c_method_name, &c_request_data};
    Dart_CObject c_request;
    c_request.type = Dart_CObject_kArray;
    c_request.value.as_array.values = c_request_arr;
    c_request.value.as_array.length =
            sizeof(c_request_arr) / sizeof(c_request_arr[0]);

    Dart_PostCObject_DL(port, &c_request);
}

int32_t P2PInput::input() {
    oboe::AudioStreamBuilder builder;
    builder.setDirection(oboe::Direction::Input)
            ->setCallback(this)
            ->setFormat(oboe::AudioFormat::Float)
            ->setChannelCount(1)
            ->setSampleRate(48000)
            ->setSharingMode(oboe::SharingMode::Shared)
            ->setPerformanceMode(oboe::PerformanceMode::LowLatency)
            ->openManagedStream(inStream);

    auto result = inStream->requestStart();
    if (result != oboe::Result::OK) {
        LOGE("HERE IS IT error in", oboe::convertToText(result));
        return 0;
    }
    return 1;
}

int32_t P2POutput::output() {
    oboe::AudioStreamBuilder builder;
    builder.setDirection(oboe::Direction::Output)
            ->setSharingMode(oboe::SharingMode::Shared)
            ->setCallback(this)
            ->setFormat(oboe::AudioFormat::Float)
            ->setChannelCount(1)
            ->setSampleRate(48000)
            ->setPerformanceMode(oboe::PerformanceMode::LowLatency)
            ->openManagedStream(outStream);

    auto result = outStream->requestStart();
    // save 10 seconds of audio
    buffer = new float[outStream->getSampleRate() * 10];
    MAXLIMIT = outStream->getSampleRate() * 10;
    if (result != oboe::Result::OK) {
        LOGE("HERE IS IT error out", oboe::convertToText(result));
        return 0;
    }
    return 1;
}

void P2PInput::setIsRecording(bool r) { this->isRecording = r; }

oboe::DataCallbackResult
P2PInput::onAudioReady(oboe::AudioStream *oboeStream, void *audioData, int32_t numFrames) {
    if (this->isRecording) {
        auto *fd = (float *) audioData;
        callback(this->getDartPort(), fd, numFrames);
//        uint8_t sendBuffer[3 * numFrames];
//
//        for (int i = 0; i < numFrames; i++)
//            sendBuffer[i] = fd[i] > 0 ? 0 : 1;
//        for (int i = numFrames, j = 0; j < numFrames; i += 2, j++) {
//            sendBuffer[i] = fd[j] * 255.0;
//            sendBuffer[i + 1] = (fd[j] * 255.0 - sendBuffer[i]) * 255.0;
//        }
//
//        this->outputPlayer->write(sendBuffer, numFrames * 3);
    }
    return oboe::DataCallbackResult::Continue;
}

oboe::DataCallbackResult
P2POutput::onAudioReady(oboe::AudioStream *oboeStream, void *audioData, int32_t numFrames) {
    auto *d = (float *) audioData;
    int32_t s = read(d, numFrames);
    return oboe::DataCallbackResult::Continue;
}
