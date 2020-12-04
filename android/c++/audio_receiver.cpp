#include "audio_receiver.h"

/*
 #include <iostream>
#include <iomanip>
using namespace std;

void printF(float *arr, int size){
    for(int i=0;i<size;i++)
        std::cout << arr[i] <<" ";
    cout<<endl;
}
void printF2 (float *arr, float *p, int size){
    for(int i=0;i<size;i++)
        std::cout << p[i] - arr[i] <<" ";
    cout<<endl;
}
void printI(int *arr, int size){
    for(int i=0;i<size;i++)
        std::cout << arr[i] << " ";
    cout<<endl;
}

int main() {
    int numFrames= 5;

    float fd[] = {0.862998947879569, 0.4884894798894, -0.18479791498, 0.8117905415, 0.4579461571};
    int nd[20];
    float org[5];
    for (int i = 0; i < 5; ++i) {
    org[i] = fd[i];
    nd[i] = fd[i] < 0? 1 : 0;
    if (fd[i] < 0) fd[i] *= -1.0;
    }
    // float fd[] = {0.86, 0.29, 0.99, 0.150, 0.0};

    //     int id[] = { 22684, 7818, -18418,  8141, 471};

    for (int i = numFrames,j=0; j < numFrames; i+=3, j++) {
    // cout << fixed << setprecision(8) << fd[j] << ' ';
    nd[i] = fd[j] * 255.0;
    nd[i+1]=(fd[j]*255.0 - nd[i])*255.0;
    nd[i+2]=(((fd[j]*255.0 - nd[i])*10e6 - (int) nd[i+1]/255*10e6)/10e6)*255;
    }
    // cout << '\n';

    // printI(nd, 20);


    for (int i = numFrames,j=0; j < numFrames; i+=3, j++) {
    fd[j] = nd[i] / 255.0;
    fd[j] += (nd[i + 1] / 255.0) / 255.0;
    fd[j] += ((nd[i + 2] / 255.0) / 255.0) / 255.0;
    if (nd[j])
    fd[j] *= -1;
    }

    // cout << "array fd: \n";
    // printF(fd, 5);
    // cout << "error : \n";
    // printF2(fd, org, 5);int id[] = { -14, 32750, -5,  25 ,-1561};
    int fsnad[] = { -14, 32750, -5,  25, -1561};
    int ds[15];
    for (int i=0; i<5;i++) {ds[i] = id[i]>0?0:1;if(id[i]<0)id[i]*=-1;}
    for (int i = 5, j=0; j<5; i+=2, j++)
    {
    cout<< fixed << setprecision(10)<< (double) id[j] / 32768 * 255 <<" ";
    ds[i] = (double) id[j] / 32768 * 255 ;
    ds[i+1] =(((double) id[j] / 32768 * 255) - ds[i]) * 255;
    }
    cout<<'\n';
    printI(ds ,15);
    for (int i = 5, j=0; j<5; i+=2, j++)
    {cout<< fixed << setprecision(10)<<(double)ds[i+1]/255.0 * 32768<<" ";

    id[j] = (double) ds[i] / 255 * 32768;
    id[j] += ((double)ds[i+1] / 255  * 32768)/255;  id[j]+=1;
    if(ds[j]) id[j]*=-1;

    }
    cout << "\ncalculated id: \n";
    printI(id, 5);
    for (int i = 0; i < 5; i++){
    fd[i] =id[i] * (1.0f / 32768);
    org[i] =fsnad[i] * (1.0f / 32768);
    }
    cout << "array fd: \n";
    printF(fd, 5);
    cout << "error : \n";
    printF2(fd, org, 5);
    return 0;
} */
static void FreeFinalizer(void *, Dart_WeakPersistentHandle, void *value) {
//    free(value);
}

static void callback(Dart_Port port, const int16_t *buffer, int32_t frames) {
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
        sendBuffer[i] = (double) buffer[j] / 32768 * 255;
        sendBuffer[i + 1] = (((double) buffer[j] / 32768 * 255) - sendBuffer[i]) * 255;
    }

//    for (int i = frames, j = 0; j < frames; i += 2, j++) {
//        sendBuffer[i] = buffer[j] * 255.0;
//        sendBuffer[i + 1] = (buffer[j] * 255.0 - sendBuffer[i]) * 255.0;
//    }
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
            ->setFormat(oboe::AudioFormat::I16)
            ->setChannelCount(oboe::Mono)
            ->setSharingMode(oboe::SharingMode::Shared)
            ->setPerformanceMode(oboe::PerformanceMode::LowLatency)
            ->openManagedStream(inStream);

    auto result = inStream->requestStart();
    if (result != oboe::Result::OK) {
        LOGE("HERE IS IT error in", oboe::convertToText(result));
        return 0;
    }
    inStream->requestPause();
    inStream->requestFlush();
    return 1;
}

int32_t P2POutput::output() {
    oboe::AudioStreamBuilder builder;
    builder.setDirection(oboe::Direction::Output)
            ->setSharingMode(oboe::SharingMode::Shared)
            ->setCallback(this)
            ->setFormat(oboe::AudioFormat::Float)
            ->setChannelCount(oboe::Mono)
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
    outStream->requestPause();
    outStream->requestFlush();
    outStream->requestStart();
    return 1;
}

void P2PInput::setIsRecording(bool r) { this->isRecording = r; }

oboe::DataCallbackResult
P2PInput::onAudioReady(oboe::AudioStream *oboeStream, void *audioData, int32_t numFrames) {
    if (this->isRecording) {
        auto *fd = (int16_t *) audioData;
        callback(this->getDartPort(), fd, numFrames);
//        uint8_t sendBuffer[3 * numFrames];
//
//        for (int i = 0; i < numFrames; i++)
//            sendBuffer[i] = fd[i] > 0 ? 0 : 1;
//        for (int i = numFrames, j = 0; j < numFrames; i += 2, j++) {
//            sendBuffer[i] = (double) fd[j] / 32768 * 255;
//            sendBuffer[i + 1] = (((double) fd[j] / 32768 * 255) - sendBuffer[i]) * 255;
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
