import 'dart:io';
import 'dart:typed_data';

import 'package:peer2peer/screens/client.dart';
import 'package:peer2peer/screens/server.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:peer2peer/services/server_service.dart';
import 'package:provider/provider.dart';

class P2P with ChangeNotifier {
  final int serverPort = 32465;
  final int clientPort = 23654;
  final String mask = '192.168.0.';
  bool _searching = false;
  static ServerSocket _serverSocket;
  static final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();
  InternetAddress serverAddress;
  ServerService _serverService;

  bool get searching => _searching;

  P2P({this.serverAddress});

  initializer() async {
    if (_serverSocket == null) {
      _searching = true;
      notifyListeners();
      Fluttertoast.showToast(
          msg: 'Checking if server is already available, please wait.',
          toastLength: Toast.LENGTH_LONG);
      final InternetAddress address = await findServer();
      if (address == null) {
        _serverSocket = await ServerSocket.bind('0.0.0.0', serverPort);
        _serverService = ServerService();
        addServerListener();
        Fluttertoast.showToast(msg: 'Server started');
        _searching = false;

        navKey.currentState.push(
          MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider(
              child: ServerScreen(),
              create: (_) => P2P(),
            ),
          ),
        );
      } else {
        _searching = false;
        notifyListeners();
        Fluttertoast.showToast(msg: 'Server already available');
        debugPrint('Server already available');
        navKey.currentState.push(
          MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider(
              child: ClientScreen(),
              create: (_) => P2P(serverAddress: address),
            ),
          ),
        );
      }
    } else {
      Fluttertoast.showToast(msg: 'This device is already a Server');
    }
  }

  addServerListener() {
    _serverSocket.listen((sock) {
      sock.listen((data) async {
        debugPrint("Message from client ${String.fromCharCodes(data)}");
        if (String.fromCharCodes(data) == "PING") {
          sock.add('PONG'.codeUnits);
        } else if (String.fromCharCodes(data) == "ROUTING_TABLE") {
          Uint8List tables = _serverService.addNode(sock.address);
          sock.add(tables);
          // send routing tables
        } else if (String.fromCharCodes(data) == "QUIT") {
          //--------------------- change state of that ip who quits------------
          InternetAddress ip = sock.address;
          int uid = _serverService.getUID(ip);
          _serverService.removeNode(uid);
          // reply
        } else if (String.fromCharCodes(data).startsWith('DEAD-')) {
          //--------------------- change state of that ip to dead--------------
          InternetAddress ip =
              InternetAddress(String.fromCharCodes(data).substring(5));
          int uid = _serverService.getUID(ip);
          bool dead;
          try {
            Socket _clientSock = await Socket.connect(
                ServerService.allNodes[uid].ip, clientPort);
            dead = await ping(_clientSock, ServerService.allNodes[uid].ip);
            _clientSock.close();
          } on Exception {
            dead = true;
          }
          if (dead) {
            _serverService.removeNode(uid);
            sock.add('DEAD'.codeUnits);
          } else
            sock.add('NOT_DEAD'.codeUnits);
          // reply
        } else if (String.fromCharCodes(data).startsWith('UID-')) {
          //--------------------- get uid of given ip {'UID-192.65.23.155}------
          InternetAddress ip =
              InternetAddress(String.fromCharCodes(data).substring(4));
          int uid = _serverService.getUID(ip);
          sock.add('$uid'.codeUnits);
        }
      });
    });
  }

  Future<bool> ping(Socket sock, InternetAddress address) async {
    sock.add('PING'.codeUnits);
    Uint8List data = await sock.timeout(Duration(seconds: 1), onTimeout: (abc) {
      return false;
    }).first;
    debugPrint("Message from server ${String.fromCharCodes(data)}");
    if ('PONG' == String.fromCharCodes(data)) {
      Fluttertoast.showToast(msg: 'Connected at host $address');
      return true;
    } else
      return false;
  }

  closeServer() async {
    await _serverSocket.close();
    _serverSocket = null;
    Fluttertoast.showToast(msg: 'Socket closed');
    notifyListeners();
    navKey.currentState.pop();
  }

  Future<InternetAddress> findServer({int start: 100, int end: 255}) async {
    for (int i = start; i <= end; i++) {
      try {
        final Socket sock = await Socket.connect(mask + '$i', serverPort,
            timeout: Duration(milliseconds: 200));
        InternetAddress address = sock.address;
        Fluttertoast.showToast(msg: 'Found a server at $address, pinging');
        bool pong = await ping(sock, address);
        if (pong) {
          await sock.close();
          return address;
        } else
          continue;
      } on Exception {
        debugPrint('$mask$i is not a server');
        continue;
      }
    }
    return null;
  }
}
