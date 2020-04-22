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
    return '$_id|${_ip.host};';
  }
}

class Message {
  int _senderUid;
  int _receiverUid;
  String _message; // encrypted message ->  192.168.0.1|Message_content
  int _timestamp;
  int _acknowledged = 0;

  Message(this._senderUid, this._receiverUid, this._message, this._timestamp);

  Message.fromString(String message) {
    message = message.split('>')[1];
    _senderUid = int.parse(message.split('|')[0]);
    _receiverUid = int.parse(message.split('|')[1]);
    _message = message.split('|')[2];
    _timestamp = int.parse(message.split('|')[3]);
  }

  String get message => _message;

  int get timestamp => _timestamp;

  int get senderUid => _senderUid;

  int get receiverUid => _receiverUid;

  int get acknowledged => _acknowledged;

  @override
  String toString() {
    return 'MESSAGE>$_senderUid|$_receiverUid|$_message|$_timestamp';
  }
}
