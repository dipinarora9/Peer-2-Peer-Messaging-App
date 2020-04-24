import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:peer2peer/models/common_classes.dart';

import 'p2p.dart';

class ClientService with ChangeNotifier {
  final int serverPort = 32465;
  final int clientPort = 23654;
  static ServerSocket _clientSocket;
  InternetAddress _serverAddress;
  Map<int, Node> incomingNodes = {};
  Map<int, Node> outgoingNodes = {};
  Timer _timer;
  User me;
  Map<User, Map<int, Message>> chats = {};
  String text = '';

  ClientService(this._serverAddress);

  requestUsername(String username) async {
    bool flag = false;
    final Socket server = await _connectToServer();
    server.add('USERNAME-$username'.codeUnits);
    Uint8List data =
        await server.timeout(Duration(seconds: 1), onTimeout: (abc) {
      return false;
    }).first;
    if (String.fromCharCodes(data).startsWith('ACCEPTED>')) flag = true;
    server.close();
    if (flag)
      setupIncomingServer();
    else
      Fluttertoast.showToast(msg: 'Username already taken');
  }

  setupIncomingServer() async {
    _clientSocket =
        await ServerSocket.bind('0.0.0.0', clientPort, shared: true);
    await setupListener();
    await requestPeers();
  }

  setupListener() {
    _clientSocket.listen((sock) {
      sock.listen((data) async {
        if (String.fromCharCodes(data) == 'PING') {
          sock.add('PONG'.codeUnits);
          if (sock.remoteAddress != _serverAddress) {
            bool callServer = true;
            incomingNodes.values.any((peer) {
              if (peer.ip == sock.remoteAddress) {
                incomingNodes[peer.user.uid].state = true;
                callServer = false;
                return true;
              }
              return false;
            });
            if (callServer) {
              User user = await requestUID(sock.remoteAddress.host);
              incomingNodes[user.uid] = Node(sock.remoteAddress, user);
            }
          }
        } else if (String.fromCharCodes(data).startsWith('MESSAGE')) {
          Message message = Message.fromString(String.fromCharCodes(data));
          if (message.receiver.uid != me.uid)
            forwardMessage(message);
          else {
            chats[message.sender] = {message.timestamp: message};
            notifyListeners();
          }
        } else if (String.fromCharCodes(data).startsWith('ACKNOWLEDGED>')) {
          String mes = String.fromCharCodes(data).split('>')[1];
          Message message = Message.fromAcknowledgement(mes);
          if (message.receiver.uid != me.uid)
            forwardMessage(message);
          else {
            chats[message.sender][message.timestamp].acknowledged = 1;
            notifyListeners();
          }
        }
      });
    });
  }

  Future<Socket> _connectToServer() async {
    debugPrint(_serverAddress.host);
    final sock = await Socket.connect(_serverAddress.host, serverPort);
    return sock;
  }

  requestPeers() async {
    final Socket server = await _connectToServer();
    server.add('ROUTING_TABLE-${me.username}'.codeUnits);
    Uint8List data =
        await server.timeout(Duration(seconds: 1), onTimeout: (abc) {}).first;
    String table = String.fromCharCodes(data);
    me = User.fromString(table.split('>')[0]);
    debugPrint(me.toString());
    if (table.split('>').length > 1) {
      table = table.split('>')[1];
      table.split(';').forEach((peer) {
        debugPrint(peer);
        Node node = Node.fromString(peer);
        outgoingNodes[node.user.uid] = node;
      });
    }
    setTimer();
    server.close();
  }

  setTimer() {
    if (_timer == null)
      _timer = Timer.periodic(Duration(minutes: 1), (timer) {
        outgoingNodes.keys.forEach((uid) {
          pingPeer(uid);
        });
      });
  }

  pingPeer(uid) async {
    try {
      final Socket peer =
          await Socket.connect(outgoingNodes[uid].ip.host, clientPort);
      peer.add('PING'.codeUnits);
      Uint8List data =
          await peer.timeout(Duration(seconds: 1), onTimeout: (abc) {
        return false;
      }).first;
      if ('PONG' == String.fromCharCodes(data)) {
        outgoingNodes[uid].downCount = 0;
        outgoingNodes[uid].state = true;
      } else {
        outgoingNodes[uid].downCount++;
        outgoingNodes[uid].state = false;
      }
      peer.close();
    } on Exception {
      outgoingNodes[uid].state = false;
      outgoingNodes[uid].downCount++;
      if (outgoingNodes[uid].downCount > 2) {
        sendPeerDeadRequest(uid);
      }
    }
  }

  sendPeerDeadRequest(int uid) async {
    final Socket server = await _connectToServer();
    server.add('DEAD-$uid'.codeUnits);
    Uint8List data =
        await server.timeout(Duration(seconds: 1), onTimeout: (abc) {
      return false;
    }).first;

    if (String.fromCharCodes(data) == 'DEAD') {
      outgoingNodes.remove(uid);
    } else if (String.fromCharCodes(data) == 'NOT_DEAD') {
      pingPeer(uid);
    }
    server.close();
  }

  sendQuitRequest(int uid) async {
    final Socket server = await _connectToServer();
    server.add('QUIT'.codeUnits);
    server.close();
    _timer.cancel();
    await _clientSocket.close();
    P2P.navKey.currentState.pop();
  }

  Future<User> requestUID(String ip) async {
    final Socket server = await _connectToServer();
    server.add('UID_FROM_IP-$ip'.codeUnits);
    Uint8List data =
        await server.timeout(Duration(seconds: 1), onTimeout: (abc) {
      return false;
    }).first;
    await server.close();
    return User.fromString(String.fromCharCodes(data));
  }

  sendMessage(Message message, InternetAddress address) async {
    try {
      final Socket peer = await Socket.connect(address.host, clientPort);
      if (message.acknowledged == 0)
        peer.add(message.toString().codeUnits);
      else
        peer.add(message.acknowledgementMessage().codeUnits);
      peer.close();
    } on Exception {}
  }

  forwardMessage(Message message) async {
    if (outgoingNodes.containsKey(message.receiver.uid)) {
      await sendMessage(message, outgoingNodes[message.receiver.uid].ip);
      forwardMessage(Message.fromAcknowledgement(
        message.acknowledgementMessage(),
      ));
    } else if (incomingNodes.containsKey(message.receiver.uid)) {
      await sendMessage(message, incomingNodes[message.receiver.uid].ip);
      forwardMessage(Message.fromAcknowledgement(
        message.acknowledgementMessage(),
      ));
    } else {
      Map<int, Node> allNodes = Map.from(incomingNodes);
      allNodes.addAll(outgoingNodes);
      if (message.receiver.uid > message.sender.uid) {
        int dist = message.receiver.uid - message.sender.uid;
        int jump = math.log(dist) / math.log(2) as int;
        await sendMessage(message, allNodes[message.sender.uid + jump].ip);
      } else {
        int dist = message.sender.uid - message.receiver.uid;
        int jump = math.log(dist) / math.log(2) as int;
        await sendMessage(message, allNodes[message.sender.uid - jump].ip);
      }
    }
  }

  createMessage(String message, String username) async {
    int time = DateTime.now().millisecondsSinceEpoch;
    final Socket server = await _connectToServer();
    server.add('UID_FROM_USERNAME-$username'.codeUnits);
    Uint8List data =
        await server.timeout(Duration(seconds: 1), onTimeout: (abc) {}).first;
    User receiver = User.fromString(String.fromCharCodes(data));
    server.close();
    Message mess = Message(me, receiver, message, time);
    forwardMessage(mess);
    chats[receiver] = {time: mess};
  }
}
