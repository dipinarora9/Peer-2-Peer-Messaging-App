import 'dart:io';

import 'package:rsa_util/rsa_util.dart';

class SocketAddress {
  InternetAddress _externalIp;
  int _externalPort;
  InternetAddress _internalIp;
  int _internalPort;

  SocketAddress(
    this._externalIp,
    this._externalPort,
    this._internalIp,
    this._internalPort,
  );

  InternetAddress get externalIp => _externalIp;

  int get externalPort => _externalPort;

  InternetAddress get internalIp => _internalIp;

  int get internalPort => _internalPort;

  SocketAddress.fromString(String sockAddress) {
    _externalIp = InternetAddress(sockAddress.split(',')[0].split(':')[0]);
    _externalPort = int.parse(sockAddress.split(',')[0].split(':')[1]);
    _internalIp = InternetAddress(sockAddress.split(',')[1].split(':')[0]);
    _internalPort = int.parse(sockAddress.split(',')[1].split(':')[1]);
  }

  SocketAddress.fromMap(Map<String, dynamic> map) {
    _externalIp = InternetAddress(map['external_ip']);
    _externalPort = map['external_port'];
    _internalIp = InternetAddress(map['internal_ip']);
    _internalPort = map['internal_port'];
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = Map();
    map['external_ip'] = _externalIp.address;
    map['external_port'] = _externalPort;
    map['internal_ip'] = _internalIp.address;
    map['internal_port'] = _internalPort;
    return map;
  }

  @override
  String toString() {
    return '$_externalIp:$_externalPort,$_internalIp:$_internalPort';
  }
}

class Sockets {
  SocketAddress _server;
  SocketAddress _client;

  SocketAddress get server => _server;
  SocketAddress get client => _client;
  Sockets(this._server, this._client);

  Sockets.fromMap(Map<String, dynamic> map) {
    this._server = SocketAddress.fromMap(map['server']);
    this._client = SocketAddress.fromMap(map['client']);
  }
  Sockets.fromString(String node) {
    this._server = SocketAddress.fromString(node.split('|')[0]);
    this._client = SocketAddress.fromString(node.split('|')[1]);
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = Map();
    map['server'] = _server.toMap();
    map['client'] = _client.toMap();
    return map;
  }

  @override
  String toString() {
    return '$_server|$_client';
  }
}

class Node {
  User _user;
  Sockets _sockets;
  bool _state = true;
  int _downCount = 0;

  User get user => _user;

  Sockets get sockets => _sockets;

  bool get state => _state;

  int get downCount => _downCount;

  set state(value) => _state = value;

  set user(v) => _user = v;

  set downCount(value) => _downCount = value;

  Node(this._sockets, this._user);

  Node.fromString(String node) {
    this._sockets = Sockets.fromString(node.split('&&')[0]);
    this._user = User.fromString(node.split('&&')[1]);
  }

  @override
  toString() {
    return '$_sockets&&$_user;';
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
  }

  @override
  String toString() {
    return '$_numbering@$_uid';
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
