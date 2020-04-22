import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
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
  int myUid;
  Map<int, Map<int, Message>> chats = {};
  String text = '';

  ClientService(this._serverAddress);

  setupIncomingServer() async {
    _clientSocket = await ServerSocket.bind('0.0.0.0', clientPort);
    setupListener();
    requestPeers();
  }

  setupListener() {
    _clientSocket.listen((sock) {
      sock.listen((data) async {
        if (String.fromCharCodes(data) == 'PING') {
          sock.add('PONG'.codeUnits);
          if (sock.address != _serverAddress) {
            bool callServer = true;
            incomingNodes.values.any((peer) {
              if (peer.ip == sock.address) {
                incomingNodes[peer.id].state = true;
                callServer = false;
                return true;
              }
              return false;
            });
            if (callServer) {
              int uid = await requestUID(sock.address.host);
              incomingNodes[uid] = Node(uid, sock.address);
            }
          }
        } else if (String.fromCharCodes(data).startsWith('MESSAGE')) {
          Message message = Message.fromString(String.fromCharCodes(data));
          if (message.receiverUid != myUid)
            forwardMessage(message);
          else {
            debugPrint(message.toString());
            text = message.message;
            notifyListeners();
          }
        } else if (String.fromCharCodes(data).startsWith('ACKNOWLEDGED')) {
          String mes = String.fromCharCodes(data).split('>')[1];
          Message message = Message.fromString(mes);
          //todo: deal with it
        }
      });
    });
  }

  Future<Socket> _connectToServer() async {
    final sock = await Socket.connect(_serverAddress.host, serverPort);
    return sock;
  }

  requestPeers() async {
    final Socket server = await _connectToServer();
    server.add('ROUTING_TABLE'.codeUnits);
    Uint8List data =
        await server.timeout(Duration(seconds: 1), onTimeout: (abc) {
      return false;
    }).first;
    String table = String.fromCharCodes(data);
    myUid = int.parse(table.split('>')[0]);
    table = table.split('>')[1];
    table.split(';').forEach((peer) {
      Node node = Node.fromString(peer);
      outgoingNodes[node.id] = node;
    });
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

  Future<int> requestUID(String ip) async {
    final Socket server = await _connectToServer();
    server.add('UID-$ip'.codeUnits);
    Uint8List data =
        await server.timeout(Duration(seconds: 1), onTimeout: (abc) {
      return false;
    }).first;
    await server.close();
    return int.parse(String.fromCharCodes(data));
  }

  sendMessage(Message message, InternetAddress address) async {
    try {
      final Socket peer = await Socket.connect(address.host, clientPort);
      peer.add(message.toString().codeUnits);
      peer.close();
    } on Exception {}
  }

  forwardMessage(Message message) async {
    if (outgoingNodes.containsKey(message.receiverUid)) {
      await sendMessage(message, outgoingNodes[message.receiverUid].ip);
      await sendMessage(
          Message(myUid, message.senderUid, 'ACKNOWLEDGED${message.toString()}',
              DateTime.now().millisecondsSinceEpoch),
          outgoingNodes[message.senderUid].ip);
    } else if (incomingNodes.containsKey(message.receiverUid)) {
      await sendMessage(message, incomingNodes[message.receiverUid].ip);
      await sendMessage(
          Message(myUid, message.senderUid, 'ACKNOWLEDGED${message.toString()}',
              DateTime.now().millisecondsSinceEpoch),
          incomingNodes[message.senderUid].ip);
    } else {
      Map<int, Node> allNodes = Map.from(incomingNodes);
      allNodes.addAll(outgoingNodes);
      if (message.receiverUid > message.senderUid) {
        int dist = message.receiverUid - message.senderUid;
        int jump = math.log(dist) / math.log(2) as int;
        await sendMessage(message, allNodes[message.senderUid + jump].ip);
      } else {
        int dist = message.senderUid - message.receiverUid;
        int jump = math.log(dist) / math.log(2) as int;
        await sendMessage(message, allNodes[message.senderUid - jump].ip);
      }
    }
  }

  createMessage(String message, int receiverUID) {
    int time = DateTime.now().millisecondsSinceEpoch;
    Message mess = Message(myUid, receiverUID, message, time);
    forwardMessage(mess);
    chats[receiverUID] = {time: mess};
  }
}
