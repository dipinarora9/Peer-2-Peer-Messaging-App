import 'dart:io';

import 'package:peer2peer/screens/client.dart';
import 'package:peer2peer/screens/server.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

class P2P with ChangeNotifier {
  final int serverPort = 32465;
  final String mask = '192.168.0.';
  bool _searching = false;
  static ServerSocket _serverSocket;
  static final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();
  InternetAddress serverAddress;

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
        pong();
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

  pong() {
    _serverSocket.listen((sock) {
      sock.listen((data) {
        debugPrint("Message from client ${String.fromCharCodes(data)}");
        if (String.fromCharCodes(data) == "PING") {
          sock.add('PONG'.codeUnits);
        }
      });
    });
  }

  ping(Socket sock, InternetAddress address) {
    sock.add('PING'.codeUnits);
    sock.listen((data) {
      debugPrint("Message from server ${String.fromCharCodes(data)}");
      if ('PONG' == String.fromCharCodes(data)) {
        Fluttertoast.showToast(msg: 'Connected at host $address');
//        return true;
      }
//      return false;
    });
//    return false;
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
        ping(sock, address);
//        if (pong) {
        await sock.close();
        return address;
//        } else
//          continue;
      } on Exception {
        debugPrint('$mask$i is not a server');
        continue;
      }
    }
    return null;
  }
}
