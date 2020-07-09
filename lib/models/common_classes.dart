import 'dart:io';

import 'package:rsa_util/rsa_util.dart';

class MyDatagram extends Datagram {
  int _myPort;

  MyDatagram(Datagram datagram, this._myPort)
      : super(datagram.data, datagram.address, datagram.port);

  int get myPort => _myPort;

  @override
  String toString() {
    return 'my port: $_myPort, ${String.fromCharCodes(super.data)} from ${super.address.address}:${super.port}';
  }
}

class IpAddress {
  InternetAddress _address;
  int _port;

  InternetAddress get address => _address;

  int get port => _port;

  IpAddress(this._address, this._port);

  IpAddress.fromString(String ip) {
    _address = InternetAddress(ip.split(':')[0]);
    _port = int.parse(ip.split(':')[1]);
  }

  @override
  String toString() => "${address.address}:$_port";
}

class SocketAddress {
  IpAddress _external;
  IpAddress _internal;

  SocketAddress(this._external, this._internal);

  IpAddress get external => _external;

  IpAddress get internal => _internal;

  SocketAddress.fromString(String sockAddress)
      : _external = IpAddress.fromString(sockAddress.split(',')[0]),
        _internal = IpAddress.fromString(sockAddress.split(',')[1]);

  SocketAddress.fromMap(Map<dynamic, dynamic> map) {
    _external = IpAddress(
      InternetAddress(map['external_ip']),
      map['external_port'].runtimeType == int
          ? map['external_port']
          : int.parse(map['external_port']),
    );
    _internal = IpAddress(
      InternetAddress(map['internal_ip']),
      map['internal_port'].runtimeType == int
          ? map['internal_port']
          : int.parse(map['internal_port']),
    );
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = Map();
    map['external_ip'] = _external.address.address;
    map['external_port'] = _external.port;
    map['internal_ip'] = _internal.address.address;
    map['internal_port'] = internal.port;
    return map;
  }

  @override
  String toString() {
    return '$_external,$_internal';
  }
}

class Node {
  User _user;
  SocketAddress _socket;
  bool _state = true;
  int _downCount = 0;

  User get user => _user;

  SocketAddress get socket => _socket;

  bool get state => _state;

  int get downCount => _downCount;

  set state(value) => _state = value;

  set user(v) => _user = v;

  set downCount(value) => _downCount = value;

  Node(this._socket, this._user);

  Node.fromString(String node) {
    this._socket = SocketAddress.fromString(node.split('^&^&')[0]);
    this._user = User.fromString(node.split('^&^&')[1]);
  }

  @override
  toString() {
    return '$_socket^&^&$_user;';
  }
}

class User {
  int _numbering;
  String _uid;
  String _username;

  String get uid => _uid;

  int get numbering => _numbering;

  String get username => _username;

  User(int number, String uid, String username)
      : _numbering = number,
        _uid = uid,
        _username = username;

  User.fromString(String s) {
    _numbering = int.parse(s.split('@')[0]);
    _uid = s.split('@')[1];
    _username = s.split('@')[2];
  }

  @override
  String toString() {
    return '$_numbering@$_uid@$_username';
  }
}

class Request {
  String _key;

  Request(String key) {
    _key = key;
  }

  String get key => _key;

  Request.fromString(String message) {
    _key = message;
  }

  @override
  String toString() {
    return key;
  }
}

class Chat {
  bool _allowed = false;
  String _key;
  Map<int, Message> _chats = {};

  set allowed(v) => _allowed = v;

  bool get allowed => _allowed;

  String get key => _key;

  Map<int, Message> get chats => _chats ?? {};

  set chats(v) => _chats = v;

  set key(v) => _key = v;
}

enum MessageStatus { DENY, SENDING, SENT, TIMEOUT, ACCEPTED }

class BroadcastMessage {
  User _sender;
  String _message;
  int _timestamp;

  BroadcastMessage(this._sender, this._message)
      : _timestamp = DateTime.now().millisecondsSinceEpoch;

  String get message => _message;

  User get sender => _sender;

  int get timestamp => _timestamp;

  BroadcastMessage.fromString(String message) {
    message = message.split('>')[1];
    _sender = User.fromString(message.split('|')[0]);
    _message = message.split('|')[1];
    _timestamp = int.parse(message.split('|')[2]);
  }

  @override
  String toString() {
    return 'BROADCAST>$_sender|$_message|$_timestamp';
  }
}

class Message {
  User _sender;
  User _receiver;
  String _message;
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
    if (_status == MessageStatus.ACCEPTED) _message = message.split('|')[4];
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
      case 4:
        return MessageStatus.ACCEPTED;
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

  set message(v) => _message = v;

  String acknowledgementMessage() {
    if (_status == MessageStatus.ACCEPTED)
      return 'ACKNOWLEDGED>$_receiver|$_sender|$_timestamp|${_status.index}|$_message';
    return 'ACKNOWLEDGED>$_receiver|$_sender|$_timestamp|${_status.index}';
  }

  @override
  String toString() {
    return 'MESSAGE>$_sender|$_receiver|$_message|$_timestamp';
  }
}

class Encrypt {
  String _publicKey;
  String _privateKey;

  Encrypt() {
    List<String> keys = RSAUtil.generateKeys(1024);
    _publicKey = keys[0];
    _privateKey = keys[1];
  }

  String get pubKey => _publicKey;

  String encryption(String pub, String msg) =>
      RSAUtil.getInstance(pub, _privateKey).encryptByPublicKey(msg);

  String decryption(String pub, String msg) =>
      RSAUtil.getInstance(pub, _privateKey).decryptByPrivateKey(msg);
}
