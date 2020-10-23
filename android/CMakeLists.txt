cmake_minimum_required(VERSION 3.4.1)

set(OBOE_DIR C:/src/oboe)

add_subdirectory(${OBOE_DIR} ./oboe)
include_directories(${OBOE_DIR}/include)

set(DART_DIR C:/src/flutter/bin/cache/dart-sdk)

add_library(p2p
        SHARED
        c++/audio_receiver.cpp c++/audio_receiver.h c++/bridge_services.cpp
        c++/include/dart_api_dl.cc c++/include/dart_api.h c++/include/dart_api_dl.h
        c++/include/dart_native_api.h c++/include/internal/dart_api_dl_impl.h c++/include/dart_tools_api.h
        c++/include/dart_version.h)

target_link_libraries(p2p oboe log)