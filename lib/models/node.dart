import 'dart:io';

class Node {
  int _id;
  InternetAddress _ip;
  bool _state = true;
  int _downCount = 0;

  int get id => _id;

  InternetAddress get ip => _ip;

  bool get state => _state;

  int get downCount => _downCount;

  set state(value) => _state = value;

  set downCount(value) => _downCount = value;

  Node(this._id, this._ip);

  Node.fromString(String node) {
    this._id = node.split('|')[0] as int;
    this._ip = InternetAddress(node.split('|')[1]);
  }

  @override
  toString() {
    return '$_id|${_ip.address};';
  }
}
