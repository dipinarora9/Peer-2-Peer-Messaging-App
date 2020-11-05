import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:peer2peer/services/client_service.dart';

typedef BufferNativeFunction = Int32 Function(
    Pointer, Pointer<NativeFunction<CallbackFunction>>);

typedef BufferFunction = int Function(
    Pointer, Pointer<NativeFunction<CallbackFunction>>);

typedef CallbackFunction = Void Function(Pointer<Uint8>, Int32, Int64);

Pointer inPlayer;
Pointer outPlayer;
DynamicLibrary p2pLib = DynamicLibrary.open("libp2p.so");
ClientService globalClient;

class NativeUtils {
  static Uint8List fromPointer(Pointer<Uint8> ptr, int length) {
    final view = ptr.asTypedList(length);
    final builder = BytesBuilder(copy: false);
    builder.add(view);
    return builder.takeBytes();
  }

  static Pointer<Uint8> toPointer(Uint8List bytes) {
    final ptr = allocate<Uint8>(count: bytes.length);
    final byteList = ptr.asTypedList(bytes.length);
    byteList.setAll(0, bytes);
    return ptr.cast();
  }

  static final int Function(Pointer, Pointer, int, int) nativeRecord = p2pLib
      .lookup<NativeFunction<Int32 Function(Pointer, Pointer, Int8, Int64)>>(
          'record')
      .asFunction();

  static final int Function(Pointer, Pointer<Uint8>, int) playBuffer = p2pLib
      .lookup<NativeFunction<Int64 Function(Pointer, Pointer<Uint8>, Int32)>>(
          'playBuffer')
      .asFunction();
}
