import 'dart:io';

class Node {
  User _user;
  InternetAddress _ip;
  bool _state = true;
  int _downCount = 0;

  User get user => _user;

  InternetAddress get ip => _ip;

  bool get state => _state;

  int get downCount => _downCount;

  set state(value) => _state = value;

  set user(v) => _user = v;

  set downCount(value) => _downCount = value;

  Node(this._ip, this._user);

  Node.fromString(String node) {
    this._ip = InternetAddress(node.split('|')[0]);
    this._user = User.fromString(node.split('|')[1]);
  }

  @override
  toString() {
    return '${_ip.host}|$_user;';
  }
}

class User {
  int _uid;
  String _username;

  int get uid => _uid;

  String get username => _username;

  set uid(v) => _uid = v;

  set username(v) => _username = v;

  User(int id, String username) {
    _uid = id;
    _username = username;
  }

  User.fromString(String s) {
    _uid = int.parse(s.split('@')[0]);
    _username = s.split('@')[1];
  }

  @override
  String toString() {
    return '$_uid@$_username';
  }
}

class Message {
  User _sender;
  User _receiver;
  String _message; // encrypted message -> Message_content
  int _timestamp;
  int _acknowledged = 0;

  Message(this._sender, this._receiver, this._message, this._timestamp);

  Message.fromString(String message) {
    message = message.split('>')[1];
    _sender = User.fromString(message.split('|')[0]);
    _receiver = User.fromString(message.split('|')[1]);
    _message = message.split('|')[2];
    _timestamp = int.parse(message.split('|')[3]);
  }

  Message.fromAcknowledgement(String message) {
    message = message.split('>')[1];
    _sender = User.fromString(message.split('|')[0]);
    _receiver = User.fromString(message.split('|')[1]);
    _timestamp = int.parse(message.split('|')[2]);
    _acknowledged = 1;
  }

  String get message => _message;

  int get timestamp => _timestamp;

  User get sender => _sender;

  User get receiver => _receiver;

  int get acknowledged => _acknowledged;

  set acknowledged(v) => _acknowledged = v;

  String acknowledgementMessage() {
    return 'ACKNOWLEDGED>$_receiver|$_sender|$_timestamp';
  }

  @override
  String toString() {
    return 'MESSAGE>$_sender|$_receiver|$_message|$_timestamp';
  }
}
