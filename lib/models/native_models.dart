import 'dart:isolate';

class CppRequest {
  final SendPort replyPort;
  final int pendingCall;
  final String method;
  final List<int> data;

  factory CppRequest.fromCppMessage(List message) {
    return CppRequest._(message[0], message[1], message[2], message[3]);
  }

  CppRequest._(this.replyPort, this.pendingCall, this.method, this.data);

  String toString() =>
      'CppRequest(method: $method, ${data != null ? data : 0} bytes)';
}

class CppResponse {
  final int pendingCall;
  final List<int> data;
  final int length;
  final int pointer;

  CppResponse(this.pendingCall, this.data, this.length, this.pointer);

  List toCppMessage() =>
      List.from([pendingCall, data, length, pointer], growable: false);

  String toString() => 'CppResponse(message: $data)';
}
