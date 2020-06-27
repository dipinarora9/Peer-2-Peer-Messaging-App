import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:connectivity/connectivity.dart';
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
  String mask = '192.168.0.';
  int _start = 100;
  int _end = 255;
  bool _searching = false;
  static ServerSocket _serverSocket;
  static final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();
  InternetAddress serverAddress;
  ServerService _serverService;
  String te = '';
  int natPort = -1;
  String destIp = '';
  int destPort = -1;
  String peer = '';
  int myPort = -1;

  bool get searching => _searching;

  /// Initializes the network, automatically register the user as a server or client/peer
  initializer({String ip}) async {
    if (ip != null && ip != '') {
      mask = ip.split(',')[0];
      _start = int.parse(ip.split(',')[1]);
      _end = int.parse(ip.split(',')[2]);
    }
    if (_serverSocket == null) {
      _searching = true;
      notifyListeners();
      Fluttertoast.showToast(
          msg: 'Checking if server is already available, please wait.',
          toastLength: Toast.LENGTH_LONG);
      final InternetAddress address = await findServer();
      if (address == null) {
        _serverSocket =
            await ServerSocket.bind('0.0.0.0', serverPort, shared: true);
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
              child: AllChatsScreen(),
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
    myPort = sock.port;
    List<NetworkInterface> l = await NetworkInterface.list();
    String myIp;
    var connectivityResult = await (Connectivity().checkConnectivity());
    InternetAddressType addressType;
    if (connectivityResult == ConnectivityResult.mobile) {
      addressType = InternetAddressType.IPv6;
    } else if (connectivityResult == ConnectivityResult.wifi) {
      addressType = InternetAddressType.IPv4;
    }
    l.forEach((address) {
      address.addresses.any((add) {
        if (add.type == addressType) {
          myIp = add.address;
          return true;
        }
        return false;
      });
    });

    debugPrint(myIp);
    sock.send('Register,$num-$myIp;$myPort!'.codeUnits,
        InternetAddress('13.127.251.194'), 2020); //todo: add server address

    await Future.delayed(Duration(seconds: 2));
    sock.send('Connect,$connectTo-$myIp;$myPort!'.codeUnits,
        InternetAddress('13.127.251.194'), 2020); //todo: add server address

    sock.listen((event) {
      if (event == RawSocketEvent.read) {
        peer = String.fromCharCodes(sock.receive()?.data);
        saveInfo();
        sock.close();
        debugPrint(peer);
      }
    });
  }

  saveInfo() async {
    destIp = peer.substring(0, peer.indexOf(':'));
    destPort =
        int.parse(peer.substring(peer.indexOf(':') + 1, peer.indexOf('-')));
    natPort = int.parse(peer.substring(peer.indexOf('-') + 1));
    _receiver();
  }

  sender(String message) async {
    RawDatagramSocket sock = await RawDatagramSocket.bind('0.0.0.0', natPort);
    sock.send('HERE IS IT - hole punched'.codeUnits, InternetAddress(destIp),
        destPort);
    debugPrint('message sent');
  }

  sendEmpty() async {
    RawDatagramSocket sock = await RawDatagramSocket.bind('0.0.0.0', natPort);
    sock.send([], InternetAddress(destIp), destPort);
    sock.send([], InternetAddress(destIp), destPort);
    sock.send([], InternetAddress(destIp), destPort);
    sock.send([], InternetAddress(destIp), destPort);
    debugPrint('trying to punch hole');
    sock.close();
  }

  _receiver() async {
    RawDatagramSocket sock = await RawDatagramSocket.bind('0.0.0.0', natPort);
    int count = 0;
    sock.listen((event) {
      if (event == RawSocketEvent.read) {
        Datagram message = sock.receive();
        debugPrint('HERE IS IT ${message.data}');
        if (message != null && count > 1) {
          te = String.fromCharCodes(message.data);
          notifyListeners();
//          debugPrint(String.fromCharCodes(message?.data));
        }
        count++;
      }
    });
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
          notifyListeners();
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
          notifyListeners();
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
  Future<InternetAddress> findServer() async {
    for (int i = _start; i <= _end; i++) {
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
