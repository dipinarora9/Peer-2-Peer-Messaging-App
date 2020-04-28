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

class Chat {
  bool _allowed = false;
  Map<int, Message> _chats = {};

  set allowed(v) => _allowed = v;

  bool get allowed => _allowed;

  Map<int, Message> get chats => _chats ?? {};

  set chats(v) => _chats = v;
}

enum MessageStatus { DENY, SENDING, SENT, TIMEOUT }

class Message {
  User _sender;
  User _receiver;
  String _message; // encrypted message -> Message_content
  int _timestamp;
  MessageStatus _status = MessageStatus.SENDING;

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
    _status = getStatus(int.parse(message.split('|')[3]));
  }

  MessageStatus getStatus(int stat) {
    switch (stat) {
      case 0:
        return MessageStatus.DENY;
        break;
      case 1:
        return MessageStatus.SENDING;
        break;
      case 2:
        return MessageStatus.SENT;
        break;
      default:
        return MessageStatus.TIMEOUT;
    }
  }

  String get message => _message;

  int get timestamp => _timestamp;

  User get sender => _sender;

  User get receiver => _receiver;

  MessageStatus get status => _status;

  set status(v) => _status = v;

  String acknowledgementMessage() {
    return 'ACKNOWLEDGED>$_receiver|$_sender|$_timestamp|${_status.index}';
  }

  @override
  String toString() {
    return 'MESSAGE>$_sender|$_receiver|$_message|$_timestamp';
  }
}
