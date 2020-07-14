import 'dart:async';
import 'dart:io';

import 'package:connectivity/connectivity.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:peer2peer/models/common_classes.dart';
import 'package:peer2peer/screens/broadcast_chat.dart';
import 'package:peer2peer/services/client_service.dart';
import 'package:peer2peer/services/server_service.dart';
import 'package:provider/provider.dart';

class P2P with ChangeNotifier {
  bool _loading = false;

  static final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

  String _roomKey;
  ClientService _clientService;
  ServerService _serverService;
  final TextEditingController meetingId = TextEditingController();
  final TextEditingController name = TextEditingController();

  bool get loading => _loading;

  joinMeetingViaUrl() async {
    _loading = true;
    notifyListeners();
    AuthResult user = await FirebaseAuth.instance.signInAnonymously();
    PendingDynamicLinkData data =
        await FirebaseDynamicLinks.instance.getInitialLink();
    _parseDynamicLinkData(data, user.user, '');
  }

  joinMeeting() async {
    _loading = true;
    notifyListeners();
    AuthResult user = await FirebaseAuth.instance.signInAnonymously();
    PendingDynamicLinkData data = await FirebaseDynamicLinks.instance
        .getDynamicLink(Uri.https('peer2peer.page.link', meetingId.text));
    _parseDynamicLinkData(data, user.user, meetingId.text);
  }

  _parseDynamicLinkData(
      PendingDynamicLinkData data, FirebaseUser user, String meetingId) async {
    SocketAddress serverAddress =
        SocketAddress.fromMap(data.link.queryParameters);
    SocketAddress mySocket = await _createMySocket();
    DatabaseReference ref = FirebaseDatabase.instance.reference();
    Map<String, dynamic> clientMap = mySocket.toMap();
    clientMap['username'] = name.text;
    ref
        .child('rooms')
        .child(data.link.queryParameters['room_id'])
        .child(user.uid)
        .update(clientMap);
    _clientService = ClientService(mySocket, serverAddress, meetingId);
    ref
        .child('rooms')
        .child(data.link.queryParameters['room_id'])
        .child(user.uid)
        .onChildAdded
        .listen((event) {
      if (event.snapshot.value == true) {
        _loading = false;
        notifyListeners();
        navKey.currentState.push(
          MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider.value(
              value: _clientService..initialize(user.uid),
              child: BroadcastChat(false),
            ),
          ),
        );
      } else if (event.snapshot.value == false) {
        Fluttertoast.showToast(msg: 'The host denied your entrance');
        _loading = false;
        notifyListeners();
      }
    });
  }

  Future<SocketAddress> _createMySocket() async {
    RawDatagramSocket sock = await RawDatagramSocket.bind('0.0.0.0', 0,
        reuseAddress: true, ttl: 255);
    List<NetworkInterface> l = await NetworkInterface.list();
    IpAddress myIp;
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
          myIp = IpAddress(add, sock.port);
          return true;
        }
        return false;
      });
    });

    sock.send('hey'.codeUnits, InternetAddress('15.207.7.66'), 2020);
    RawSocketEvent event = RawSocketEvent.read;
    if (event == RawSocketEvent.read) {
      Datagram datagram;
      while (datagram == null) {
        await Future.delayed(Duration(milliseconds: 100));
        datagram = sock.receive();
      }
      IpAddress externalIp =
          IpAddress.fromString(String.fromCharCodes(datagram.data));
      return SocketAddress(externalIp, myIp);
    } else
      return null;
  }

  Future<List<SocketAddress>> _createHostOffer() async {
    SocketAddress clientOffer = await _createMySocket();
    SocketAddress serverOffer = await _createMySocket();

    return [serverOffer, clientOffer];
  }

  createMeeting() async {
    if (name.text.isEmpty) {
      Fluttertoast.showToast(msg: 'Name cannot be empty');
      return;
    }
    _loading = true;
    notifyListeners();
    DatabaseReference ref = FirebaseDatabase.instance.reference();
    AuthResult user = await FirebaseAuth.instance.signInAnonymously();
    ref = ref.child('rooms').push();
    _roomKey = ref.key;
    List<SocketAddress> myOffer = await _createHostOffer();
    _serverService = ServerService(myOffer[0], _roomKey);
    Map<String, dynamic> serverMap = myOffer[0].toMap();
    Map<String, dynamic> clientMap = myOffer[1].toMap();
    ref.child('host').set(serverMap);
    clientMap['username'] = name.text;
    ref.child(user.user.uid).update(clientMap);
    Map<String, String> linkMap = {};
    serverMap.forEach((key, value) => linkMap[key] = value.toString());
    linkMap['room_id'] = _roomKey;
    String shareLink = await _generateDynamicUrl(
        Uri.https('peer2peer.page.link', 'room', linkMap));
    _clientService =
        ClientService(myOffer[1], myOffer[0], shareLink.split('/').last);
    _loading = false;
    notifyListeners();
    navKey.currentState.push(
      MaterialPageRoute(
        builder: (_) => MultiProvider(
          providers: [
            ChangeNotifierProvider.value(
              value: _serverService
                ..initialize(myOffer[1], user.user.uid, name.text),
            ),
            ChangeNotifierProvider.value(
              value: _clientService..initialize(user.user.uid),
            ),
          ],
          child: BroadcastChat(true),
        ),
      ),
    );
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
