import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:peer2peer/models/common_classes.dart';
import 'package:peer2peer/screens/chats.dart';
import 'package:peer2peer/screens/server.dart';
import 'package:peer2peer/services/client_service.dart';
import 'package:peer2peer/services/server_service.dart';
import 'package:provider/provider.dart';

class P2P with ChangeNotifier {
  final int serverPort = 32465;
  final int clientPort = 23654;

  /// Defaults.. will be changed later
  /// for WIFI: 192.168.0.
  /// for Mobile hotspot 192.168.43.
  final String mask = '192.168.0.';
  bool _searching = false;
  static ServerSocket _serverSocket;
  static final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();
  InternetAddress serverAddress;
  ServerService _serverService;
  String te = '';

  bool get searching => _searching;

  /// Intializes the network, automatically register the user as a server or client/peer
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
        _serverService = ServerService(_serverSocket);
        addServerListener();
        Fluttertoast.showToast(msg: 'Server started');
        _searching = false;

        navKey.currentState.push(
          MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider(
              child: ServerScreen(),
              create: (_) => _serverService,
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
              create: (_) => ClientService(address),
            ),
          ),
        );
      }
    } else {
      Fluttertoast.showToast(msg: 'This device is already a Server');
    }
  }

  testingNatHolePunching(String num, String connectTo) async {
    RawDatagramSocket sock = await RawDatagramSocket.bind('0.0.0.0', 0);
    sock.timeout(Duration(seconds: 10000));
    int myPort = sock.port;
    List<NetworkInterface> l = await NetworkInterface.list();
    String myIp;
    l.forEach((address) {
      address.addresses.any((add) {
        if (add.type == InternetAddressType.IPv4) {
          myIp = add.address;
          return true;
        }
        return false;
      });
    });

    debugPrint(myIp);
    sock.send('Register,$num-$myIp;$myPort!'.codeUnits, InternetAddress(''),
        2020); //todo: add server address
    Datagram data;

    await Future.delayed(Duration(seconds: 5));
    data = sock.receive();

    debugPrint('Registered peers are');
    debugPrint(String.fromCharCodes(data?.data));
    debugPrint('sending connect request for $connectTo');

    sock.send('Connect,$connectTo-$myIp;$myPort!'.codeUnits,
        InternetAddress(''), 2020); //todo: add server address
    await Future.delayed(Duration(seconds: 2));
    String peer = String.fromCharCodes(sock.receive()?.data);
    sock.close();
    debugPrint(peer);
    initiateConnection(peer);
  }

  initiateConnection(String peer) async {
    String destIp = peer.substring(0, peer.indexOf(':'));
    int destPort =
        int.parse(peer.substring(peer.indexOf(':') + 1, peer.indexOf('-')));
    int natPort = int.parse(peer.substring(peer.indexOf('-') + 1));

    await sender(destIp, destPort);
    await receiver(natPort);
  }

  sender(String destIp, int destPort) async {
    RawDatagramSocket sock = await RawDatagramSocket.bind('0.0.0.0', 0);
    await Future.delayed(Duration(seconds: 1));
    sock.send('HELLO TO $destIp'.codeUnits, InternetAddress(destIp), destPort);
    sock.send('HELLO TO $destIp'.codeUnits, InternetAddress(destIp), destPort);
    sock.send('HELLO TO $destIp'.codeUnits, InternetAddress(destIp), destPort);
    sock.send('HELLO TO $destIp'.codeUnits, InternetAddress(destIp), destPort);
    debugPrint('message sent');
  }

  Future<Datagram> receive(RawDatagramSocket sock) async {
    Datagram s;
    while (s == null) {
      s = sock.receive();
    }
    return s;
  }

  receiver(int natPort) async {
    RawDatagramSocket sock = await RawDatagramSocket.bind('0.0.0.0', natPort);
    await Future.delayed(Duration(seconds: 2));
    try {
      Datagram message = sock.receive();
      //    if (message == null) await Future.delayed(Duration(seconds: 2));
      te = String.fromCharCodes(message?.data);
      notifyListeners();
      debugPrint(String.fromCharCodes(message?.data));
    } on Exception {}
  }

  addServerListener() {
    _serverSocket.listen((sock) {
      sock.listen((data) async {
        debugPrint("Message from client ${String.fromCharCodes(data)}");
        if (String.fromCharCodes(data) == "PING") {
          sock.add('PONG'.codeUnits);
        } else if (String.fromCharCodes(data).startsWith("ROUTING_TABLE-")) {
          String tables = _serverService.addNode(
              sock.remoteAddress, String.fromCharCodes(data).substring(14));
          sock.add(tables.codeUnits);
          // send routing tables
        } else if (String.fromCharCodes(data) == "QUIT") {
          //--------------------- change state of that ip who quits------------
          InternetAddress ip = sock.remoteAddress;
          User user = _serverService.getUID(ip: ip);
          _serverService.removeNode(user.uid);
          // reply
        } else if (String.fromCharCodes(data).startsWith('DEAD-')) {
          //--------------------- change state of that ip to dead--------------
          InternetAddress ip =
              InternetAddress(String.fromCharCodes(data).substring(5));
          User user = _serverService.getUID(ip: ip);
          bool dead;
          try {
            Socket _clientSock = await Socket.connect(
                _serverService.allNodes[user.uid].ip, clientPort);
            dead =
                await ping(_clientSock, _serverService.allNodes[user.uid].ip);
            _clientSock.close();
          } on Exception {
            dead = true;
          }
          if (dead) {
            _serverService.removeNode(user.uid);
            sock.add('DEAD'.codeUnits);
          } else
            sock.add('NOT_DEAD'.codeUnits);
          // reply
        } else if (String.fromCharCodes(data).startsWith('UID_FROM_IP-')) {
          //--------------------- get uid of given ip {'UID_FROM_IP-192.65.23.155}------
          InternetAddress ip =
              InternetAddress(String.fromCharCodes(data).substring(12));
          User user = _serverService.getUID(ip: ip);
          sock.add('$user'.codeUnits);
        } else if (String.fromCharCodes(data)
            .startsWith('UID_FROM_USERNAME-')) {
          //--------------------- get uid of given ip {'UID_FROM_USERNAME-abc}------
          String username = String.fromCharCodes(data).substring(18);
          User user = _serverService.getUID(username: username);
          sock.add('$user'.codeUnits);
        } else if (String.fromCharCodes(data).startsWith('USERNAME-')) {
          //--------------------- get uid of given ip {'USERNAME-abc}------
          String result = _serverService
              .checkUsername(String.fromCharCodes(data).substring(9));
          sock.add(result.codeUnits);
        }
      });
    });
  }

  // Pinging server
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

  // Search for server in the LAN
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
