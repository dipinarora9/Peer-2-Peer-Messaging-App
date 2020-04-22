import 'dart:io';

class Node {
  int _id;
  InternetAddress _ip;
  bool _state;

  int get id => _id;

  InternetAddress get ip => _ip;

  bool get state => _state ?? true;

  set state(value) => _state = value;

  Node(this._id, this._ip, this._state);

  @override
  toString() {
    return '$_id|${_ip.address}|$_state';
  }
}
