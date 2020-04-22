import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:peer2peer/models/node.dart';

class ClientService {
  final int serverPort = 32465;
  int clientPort = 23654;
  static ServerSocket _clientSocket;
  InternetAddress _serverAddress;
  Map<int, Node> incomingNodes = {};
  Map<int, Node> outgoingNodes = {};
  Timer _timer;

  ClientService(this._serverAddress);

  setupIncomingServer() async {
    _clientSocket = await ServerSocket.bind('0.0.0.0', clientPort);
    setupListener();
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
        } else if (String.fromCharCodes(data) == 'PING') {
          // other listeners
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

    String.fromCharCodes(data).split(';').forEach((peer) {
      Node node = Node.fromString(peer);
      outgoingNodes[node.id] = node;
    });
    // setup periodic timer to ping clients
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
}
