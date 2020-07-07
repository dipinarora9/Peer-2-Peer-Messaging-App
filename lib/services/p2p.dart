import 'dart:async';
import 'dart:io';

import 'package:connectivity/connectivity.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:peer2peer/models/common_classes.dart';
import 'package:peer2peer/services/client_service.dart';
import 'package:peer2peer/services/server_service.dart';

class P2P with ChangeNotifier {
  bool _searching = false;

  static final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

  String _shareLink;
  String _roomKey;
  ClientService _clientService;
  ServerService _serverService;

  String get shareLink => _shareLink;

  bool get searching => _searching;

//  /// Initializes the network, automatically register the user as a server or client/peer
//  initializer({String ip}) async {
//    if (ip != null && ip != '') {
//      mask = ip.split(',')[0];
//      _start = int.parse(ip.split(',')[1]);
//      _end = int.parse(ip.split(',')[2]);
//    }
//    if (_serverSocket == null) {
//      _searching = true;
//      notifyListeners();
//      Fluttertoast.showToast(
//          msg: 'Checking if server is already available, please wait.',
//          toastLength: Toast.LENGTH_LONG);
//      final InternetAddress address = await findServer();
//      if (address == null) {
//        _serverSocket =
//            await ServerSocket.bind('0.0.0.0', serverPort, shared: true);
//        _serverService = ServerService(_serverSocket);
//        addServerListener();
//        Fluttertoast.showToast(msg: 'Server started');
//        _searching = false;
//
//        navKey.currentState.push(
//          MaterialPageRoute(
//            builder: (_) => ChangeNotifierProvider(
//              child: ServerScreen(),
//              create: (_) => _serverService,
//            ),
//          ),
//        );
//      } else {
//        _searching = false;
//        notifyListeners();
//        Fluttertoast.showToast(msg: 'Server already available');
//        debugPrint('Server already available');
//        navKey.currentState.push(
//          MaterialPageRoute(
//            builder: (_) => ChangeNotifierProvider(
//              child: AllChatsScreen(),
//              create: (_) => ClientService(address),
//            ),
//          ),
//        );
//      }
//    } else {
//      Fluttertoast.showToast(msg: 'This device is already a Server');
//    }
//  }

//  testingNatHolePunching(String num, String connectTo) async {
//    RawDatagramSocket sock = await RawDatagramSocket.bind('0.0.0.0', 0);
//    sock.timeout(Duration(seconds: 10000));
//    myPort = sock.port;
//    List<NetworkInterface> l = await NetworkInterface.list();
//    String myIp;
//    var connectivityResult = await (Connectivity().checkConnectivity());
//    InternetAddressType addressType;
//    if (connectivityResult == ConnectivityResult.mobile) {
//      addressType = InternetAddressType.IPv6;
//    } else if (connectivityResult == ConnectivityResult.wifi) {
//      addressType = InternetAddressType.IPv4;
//    }
//    l.forEach((address) {
//      address.addresses.any((add) {
//        if (add.type == addressType) {
//          myIp = add.address;
//          return true;
//        }
//        return false;
//      });
//    });
//
//    debugPrint(myIp);
//    sock.send('Register,$num-$myIp;$myPort!'.codeUnits,
//        InternetAddress('15.207.7.66'), 2020); //todo: add server address
//
//    await Future.delayed(Duration(seconds: 2));
//    sock.send('Connect,$connectTo-$myIp;$myPort!'.codeUnits,
//        InternetAddress('15.207.7.66'), 2020); //todo: add server address
//
//    sock.listen((event) {
//      if (event == RawSocketEvent.read) {
//        peer = String.fromCharCodes(sock.receive()?.data);
//        saveInfo();
//        sock.close();
//        debugPrint(peer);
//      }
//    });
//  }
//
//  saveInfo() async {
//    destIp = peer.substring(0, peer.indexOf(':'));
//    destPort =
//        int.parse(peer.substring(peer.indexOf(':') + 1, peer.indexOf('-')));
//    natPort = int.parse(peer.substring(peer.indexOf('-') + 1));
//    _receiver();
//  }
//
//  sender() async {
//    RawDatagramSocket sock = await RawDatagramSocket.bind('0.0.0.0', natPort);
//    sock.send('HELLO TO $destIp'.codeUnits, InternetAddress(destIp), destPort);
//    debugPrint('message sent');
//  }
//
//  sendEmpty(bool withNatPort) async {
//    RawDatagramSocket sock = await RawDatagramSocket.bind('0.0.0.0', natPort);
//    sock.send([], InternetAddress(destIp), destPort);
//    sock.send([], InternetAddress(destIp), destPort);
//    sock.send([], InternetAddress(destIp), destPort);
//    sock.send([], InternetAddress(destIp), destPort);
//    debugPrint('trying to punch hole');
//    sock.close();
//  }
//
//  _receiver() async {
//    RawDatagramSocket sock = await RawDatagramSocket.bind('0.0.0.0', natPort);
//    int count = 0;
//    sock.listen((event) {
//      if (event == RawSocketEvent.read) {
//        Datagram message = sock.receive();
//        debugPrint('HERE IS IT ${message.data}');
//        if (message != null && count > 1) {
//          te = String.fromCharCodes(message.data);
//          notifyListeners();
////          debugPrint(String.fromCharCodes(message?.data));
//        }
//        count++;
//      }
//    });
//  }
//
//  // Pinging server
//  Future<bool> ping(Socket sock, InternetAddress address) async {
//    sock.add('PING'.codeUnits);
//    Uint8List data = await sock.timeout(Duration(seconds: 1), onTimeout: (abc) {
//      return false;
//    }).first;
//    debugPrint("Message from server ${String.fromCharCodes(data)}");
//    if ('PONG' == String.fromCharCodes(data)) {
//      Fluttertoast.showToast(msg: 'Connected at host $address');
//      return true;
//    } else
//      return false;
//  }

  joinMeetingViaUrl() async {
    PendingDynamicLinkData data =
        await FirebaseDynamicLinks.instance.getInitialLink();
    _parseDynamicLinkData(data);
  }

  joinMeeting(String meetingCode) async {
    PendingDynamicLinkData data = await FirebaseDynamicLinks.instance
        .getDynamicLink(Uri.https('https://peer2peer.page.link', meetingCode));
    _parseDynamicLinkData(data);
  }

  _parseDynamicLinkData(PendingDynamicLinkData data) async {
    SocketAddress serverAddress =
        SocketAddress.fromMap(data.link.queryParameters);
    SocketAddress mySocket = await _createMySocket();
    DatabaseReference ref = FirebaseDatabase.instance.reference();
    FirebaseUser user = await FirebaseAuth.instance.currentUser();
    ref
        .child('rooms')
        .child(data.link.queryParameters['room_id'])
        .child(user.uid)
        .update(mySocket.toMap());
    _clientService = ClientService(mySocket, serverAddress);
  }

  Future<SocketAddress> _createMySocket() async {
    RawDatagramSocket sock = await RawDatagramSocket.bind('0.0.0.0', 0);
    sock.timeout(Duration(seconds: 10000));
    int myPort = sock.port;
    List<NetworkInterface> l = await NetworkInterface.list();
    InternetAddress myIp;
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
          myIp = add;
          return true;
        }
        return false;
      });
    });
    String externalIp;
    sock.send('hey'.codeUnits, InternetAddress('15.207.7.66'), 2020);
    externalIp = String.fromCharCodes(sock.receive().data);
    return SocketAddress(InternetAddress(externalIp.split(':')[0]),
        int.parse(externalIp.split(':')[1]), myIp, myPort);
  }

  Future<List<SocketAddress>> _createHostOffer() async {
    SocketAddress clientOffer = await _createMySocket();
    SocketAddress serverOffer = await _createMySocket();

    return [serverOffer, clientOffer];
  }

  createMeeting() async {
    DatabaseReference ref = FirebaseDatabase.instance.reference();
    FirebaseUser user = await FirebaseAuth.instance.currentUser();
    ref = ref.child('rooms').push();
    _roomKey = ref.key;
    List<SocketAddress> myOffer = await _createHostOffer();
    _serverService = ServerService(myOffer[0], _roomKey);
    _clientService = ClientService(myOffer[1], myOffer[0]);
    Map<String, dynamic> serverMap = myOffer[0].toMap();
    ref.update({'host': serverMap});
    ref.update({user.uid: myOffer[1].toMap()});
    listenToDatabaseChanges();
    //todo: start server and client in their services
    // todo: register client as first node

    serverMap['room_id'] = _roomKey;
    _shareLink = await _generateDynamicUrl(
        Uri.https('https://peer2peer.page.link', 'room', serverMap));
    notifyListeners();
  }

  Future<String> _generateDynamicUrl(Uri uri) async {
    final DynamicLinkParameters parameters = DynamicLinkParameters(
      uriPrefix: 'https://peer2peer.page.link',
      link: uri,
      androidParameters: AndroidParameters(
        packageName: 'dipinarora9.peer2peer',
      ),
      dynamicLinkParametersOptions: DynamicLinkParametersOptions(
        shortDynamicLinkPathLength: ShortDynamicLinkPathLength.short,
      ),
    );

    final ShortDynamicLink shortLink = await parameters.buildShortLink();
    return shortLink.shortUrl.toString();
  }
}
