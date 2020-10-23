import 'dart:isolate';
import 'dart:typed_data';

class CppRequest {
  final SendPort replyPort;
  final int pendingCall;
  final String method;
  final Uint8List data;

  factory CppRequest.fromCppMessage(List message) {
    return CppRequest._(message[0], message[1], message[2], message[3]);
  }

  CppRequest._(this.replyPort, this.pendingCall, this.method, this.data);

  String toString() => 'CppRequest(method: $method, ${data.length} bytes)';
}

class CppResponse {
  final int pendingCall;
  final Uint8List data;

  CppResponse(this.pendingCall, this.data);

  List toCppMessage() => List.from([pendingCall, data], growable: false);

  String toString() => 'CppResponse(message: ${data.length})';
}
