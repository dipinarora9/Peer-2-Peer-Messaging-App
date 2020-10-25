import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:connectivity/connectivity.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:peer2peer/models/common_classes.dart';
import 'package:peer2peer/models/constants.dart';
import 'package:peer2peer/screens/broadcast_chat.dart';
import 'package:peer2peer/services/client_service.dart';
import 'package:peer2peer/services/server_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'native_utils.dart';

class P2P with ChangeNotifier {
  bool _loading = false;

  static final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  String _roomKey;
  ClientService _clientService;
  ServerService _serverService;
  final TextEditingController meetingId = TextEditingController();
  final TextEditingController name = TextEditingController();

  bool get loading => _loading;

  setUpConfig() async {
    final RemoteConfig remoteConfig = await RemoteConfig.instance;
    try {
      await remoteConfig.setDefaults(defaults);

      await remoteConfig.fetch(expiration: const Duration(seconds: 0));
      await remoteConfig.activateFetched();
      defaults['server_ip'] = remoteConfig.getString('server_ip');
      debugPrint(defaults['server_ip']);
    } catch (e) {}
  }

  joinMeetingViaUrl() async {
    FirebaseDynamicLinks.instance
        .getInitialLink()
        .then((data) => data != null ? _parseDynamicLinkData(data, '') : null);
    FirebaseDynamicLinks.instance.onLink(
        onSuccess: (PendingDynamicLinkData data) async {
      if (data != null) _parseDynamicLinkData(data, '');
    }, onError: (OnLinkErrorException e) async {
      print(e.message);
      Fluttertoast.showToast(msg: e.message);
    });
  }

  joinMeeting() async {
    PendingDynamicLinkData data = await FirebaseDynamicLinks.instance
        .getDynamicLink(Uri.https('peer2peer.page.link', meetingId.text));
    _parseDynamicLinkData(data, meetingId.text);
  }

  _parseDynamicLinkData(PendingDynamicLinkData data, String meetingId) async {
    _loading = true;
    notifyListeners();
    UserCredential user = await FirebaseAuth.instance.signInAnonymously();
    SocketAddress serverAddress =
        SocketAddress.fromMap(data.link.queryParameters);
    SocketAddress mySocket = await _createMySocket();
    DatabaseReference ref = FirebaseDatabase.instance.reference();
    Map<String, dynamic> clientMap = mySocket.toMap();
    clientMap['username'] =
        name.text != '' ? name.text : user.user.uid.substring(0, 5);
    ref
        .child('rooms')
        .child(data.link.queryParameters['room_id'])
        .child(user.user.uid)
        .update(clientMap);
    _clientService = ClientService(mySocket, serverAddress, meetingId);
    ref
        .child('rooms')
        .child(data.link.queryParameters['room_id'])
        .child(user.user.uid)
        .onChildAdded
        .listen((event) {
      if (event.snapshot.value == true) {
        _loading = false;
        notifyListeners();
        navKey.currentState.push(
          MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider.value(
              value: _clientService
                ..initialize(user.user.uid)
                ..setupCallbackReceivers(),
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
    } else if (connectivityResult == ConnectivityResult.wifi) {
      addressType = InternetAddressType.IPv4;
    }
    if (addressType == null) return null;
    l.forEach((address) {
      address.addresses.any((add) {
        if (add.type == addressType) {
          myIp = IpAddress(add, sock.port);
          return true;
        }
        return false;
      });
    });
    sock.send('hey'.codeUnits, InternetAddress(defaults['server_ip']), 2020);
    RawSocketEvent event = RawSocketEvent.read;
    int i = 0;
    if (event == RawSocketEvent.read) {
      Datagram datagram;
      while (datagram == null && i < 20) {
        await Future.delayed(Duration(milliseconds: 100));
        i++;
        datagram = sock.receive();
      }
      if (datagram == null) return null;

      IpAddress externalIp =
          IpAddress.fromString(String.fromCharCodes(datagram.data));
      return SocketAddress(externalIp, myIp);
    } else
      return null;
  }

  Future<List<SocketAddress>> _createHostOffer() async {
    SocketAddress clientOffer = await _createMySocket();
    SocketAddress serverOffer = await _createMySocket();
    if (serverOffer != null && clientOffer != null)
      return [serverOffer, clientOffer];
    else
      return null;
  }

  createMeeting() async {
    if (name.text.isEmpty) {
      Fluttertoast.showToast(msg: 'Name cannot be empty');
      return;
    }
    if (!formKey.currentState.validate()) {
      Fluttertoast.showToast(msg: 'Please fix the errors');
      return;
    }
    _loading = true;
    notifyListeners();
    DatabaseReference ref = FirebaseDatabase.instance.reference();
    UserCredential user = await FirebaseAuth.instance.signInAnonymously();
    ref = ref.child('rooms').push();
    _roomKey = ref.key;
    List<SocketAddress> myOffer = await _createHostOffer();
    if (myOffer == null) {
      Fluttertoast.showToast(msg: 'Cannot establish connection to the server');
      _loading = false;
      notifyListeners();
      return;
    }
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
              value: _clientService
                ..initialize(user.user.uid)
                ..setupCallbackReceivers(),
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

  initialize() async {
    if (!await Permission.microphone.isGranted)
      await Permission.microphone.request();

    final Pointer Function() createINPlayer = p2pLib
        .lookup<NativeFunction<Pointer Function()>>("createINPlayer")
        .asFunction();
    inPlayer = createINPlayer();
    final Pointer Function() createOUTPlayer = p2pLib
        .lookup<NativeFunction<Pointer Function()>>("createOUTPlayer")
        .asFunction();
    outPlayer = createOUTPlayer();
    final initializeApi = p2pLib.lookupFunction<IntPtr Function(Pointer<Void>),
        int Function(Pointer<Void>)>("InitDartApiDL");
    int result = initializeApi(NativeApi.initializeApiDLData);
    debugPrint('HERE IS IT $inPlayer $outPlayer $result');
  }

  // resume() {
  //   final int Function(Pointer) resume = p2pLib
  //       .lookup<NativeFunction<Int32 Function(Pointer)>>("resume")
  //       .asFunction();
  //   int result = resume(player);
  //
  //   debugPrint('HERE IS IT RESUMED $result');
  // }
  //
  // pause() {
  //   final int Function(Pointer) stop = p2pLib
  //       .lookup<NativeFunction<Int32 Function(Pointer)>>("stop")
  //       .asFunction();
  //   int result = stop(player);
  //
  //   debugPrint('HERE IS IT PAUSED $result');
  // }

  // getBuffer() async {
  //   final BufferFunction buffer = NativeUtils.p2pLib
  //       .lookup<NativeFunction<BufferNativeFunction>>("getBuffer")
  //       .asFunction();
  //   int result =
  //       buffer(player, Pointer.fromFunction<CallbackFunction>(callback));
  //
  //   // await Future.delayed(Duration(seconds: 5));
  //   // debugPrint('HERE IS IT PLAYING NOW');
  //
  //   debugPrint('HERE IS IT $result');
  // }

  Future<String> askForName() {
    final TextEditingController name = TextEditingController();
    final GlobalKey<FormState> fKey = GlobalKey<FormState>();
    return showDialog(
      context: navKey.currentState.context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          child: WillPopScope(
            onWillPop: () {
              return Future(() => false);
            },
            child: SingleChildScrollView(
              child: Form(
                key: fKey,
                child: Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextFormField(
                        decoration: InputDecoration(labelText: 'Name'),
                        controller: name,
                        validator: (n) => n.startsWith(' ')
                            ? 'Name cannot start with a space'
                            : null,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: RaisedButton(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            'Submit',
                            textScaleFactor: 1.1,
                          ),
                        ),
                        elevation: 20,
                        onPressed: () {
                          if (!formKey.currentState.validate()) {
                            Fluttertoast.showToast(
                                msg: 'Please fix the errors');
                          } else
                            navKey.currentState.pop(name.text);
                        },
                        color: Color(0xff59C9A5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
