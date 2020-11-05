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
    uint8_t sendBuffer[frames];
    Dart_CObject c_method_name;
    c_method_name.type = Dart_CObject_kString;
    c_method_name.value.as_string = const_cast<char *>("audio_buffer");
    for (int i = 0; i < frames; i++)
        sendBuffer[i] = ((buffer[i] + 1) / 2 * 255);
    Dart_CObject c_request_data;
    c_request_data.type = Dart_CObject_kExternalTypedData;
    c_request_data.value.as_external_typed_data.type = Dart_TypedData_kUint8;
    c_request_data.value.as_external_typed_data.length = frames;
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
//        int32_t framesLeft = numFrames;
//        while (framesLeft > 0) {
//            int32_t indexFrame = outputPlayer->buffer_index;
//            // contiguous writes
//            int32_t framesToEnd = outputPlayer->getLimit() - indexFrame;
//            int32_t framesNow = std::min(framesLeft, framesToEnd);
//
//            memcpy(&outputPlayer->buffer[framesNow],
//                   fd,
//                   (framesNow * sizeof(float)));
//            outputPlayer->buffer += framesNow;
//            outputPlayer->buffer_index += framesNow;
//            framesLeft -= framesNow;
//        }
//        auto fD = (int16_t *) audioData;
//        int32_t framesLeft = numFrames;
//        while (framesLeft > 0) {
//            int32_t indexFrame = outputPlayer->buffer_index;
//            // contiguous writes
//            int32_t framesToEndOfBuffer = outputPlayer->getLimit() - indexFrame;
//            int32_t framesNow = std::min(framesLeft, framesToEndOfBuffer);
//
//            for (int i = 0; i < framesNow; i++) {
//                outputPlayer->buffer[outputPlayer->buffer_index % (outputPlayer->getLimit())] =
//                        (int16_t) (*fD++ * (1.0f / 32768));
//                outputPlayer->buffer_index++;
//            }
//
//            framesLeft -= framesNow;
//        }
//
//        if (outputPlayer->buffer_index == outputPlayer->getLimit() - 1) {
//            outputPlayer->buffer_index = 0;
//        }


    }
    return oboe::DataCallbackResult::Continue;
}

oboe::DataCallbackResult
P2POutput::onAudioReady(oboe::AudioStream *oboeStream, void *audioData, int32_t numFrames) {

//    if (player_index < buffer_index && testFlag) {
//        auto *data = (int16_t *) audioData;
//        int32_t framesRead = 0;
//        int32_t framesLeft = std::min(numFrames,
//                                      std::min(MAXLIMIT, (int32_t) (buffer_index - player_index)));
//        while (framesLeft > 0) {
//            int32_t indexFrame = player_index;
//            // contiguous reads
//            int32_t framesToEnd = MAXLIMIT - indexFrame;
//            int32_t framesNow = std::min(framesLeft, framesToEnd);
//            int32_t numSamples = framesNow;
//            int32_t sampleIndex = indexFrame;
//
//            memcpy(data,
//                   &buffer[sampleIndex],
//                   (numSamples * sizeof(float)));
//
//            player_index += framesNow;
//            framesLeft -= framesNow;
//            framesRead += framesNow;
//        }
//
////        for (int i = 0; i < numFrames; i++) {
////            if (i < buffer[player_index % 100].second)
////                data[i] = buffer[player_index % 100].first[i];
////            else data[i] = 0;
////        }
////        player_index++;
//        if (player_index == MAXLIMIT / 2) {
//            player_index = 0;
//            buffer_index -= MAXLIMIT / 2;
//        }
//    } else
//        memset(static_cast<int16_t *>(audioData), 0, numFrames * oboeStream->getBytesPerFrame());
    auto *d = (float *) audioData;
    int32_t s = read(d, numFrames);
    return oboe::DataCallbackResult::Continue;
}
