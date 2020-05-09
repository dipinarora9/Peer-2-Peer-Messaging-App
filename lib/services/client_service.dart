import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:peer2peer/models/common_classes.dart';
import 'package:peer2peer/screens/chat_screen.dart';
import 'package:provider/provider.dart';

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
  Encrypt myPair;
  Map<String, Chat> chats = {};
  String text = '';
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController chatBox = TextEditingController();

  ClientService(this._serverAddress);

  Future<bool> requestUsername(String username) async {
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
      setupIncomingServer(String.fromCharCodes(data).substring(9));
    else
      Fluttertoast.showToast(msg: 'Username already taken');
    return flag;
  }

  setupIncomingServer(String username) async {
    _clientSocket =
        await ServerSocket.bind('0.0.0.0', clientPort, shared: true);
    await setupListener();
    await requestPeers(username);
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
        } else if (String.fromCharCodes(data).startsWith('MESSAGE>')) {
          Message message = Message.fromString(String.fromCharCodes(data));

          /// A - sender
          /// B - receiver
          ///
          /// A-> B
          if (message.receiver.uid != me.uid)
            forwardMessage(message);
          else {
            if (chats.containsKey(message.sender.toString())) {
              chats[message.sender.toString()].chats[message.timestamp] =
                  message..message=myPair.decryption(message.message);
              notifyListeners();
              forwardMessage(message..status = MessageStatus.SENT);
            } else
              showPopup(message);
            notifyListeners();
          }
        } else if (String.fromCharCodes(data).startsWith('ACKNOWLEDGED>')) {
          Message message =
              Message.fromAcknowledgement(String.fromCharCodes(data));

          /// B - sender
          /// A - receiver
          ///
          /// A-> B
          if (message.receiver.uid != me.uid)
            forwardMessage(message);
          else {
            if (message.status == MessageStatus.DENY) {
//              P2P.navKey.currentState.pushAndRemoveUntil(
//                  MaterialPageRoute(
//                    builder: (_) => ChangeNotifierProvider.value(
//                      child: AllChatsScreen(),
//                      value: this,
//                    ),
//                  ),
//                  (route) => route.settings.name == '/chats');
              chats.remove(message.sender.toString());
            } else if (message.status == MessageStatus.ACCEPTED) {
              chats[message.sender.toString()].key =
                  Request.fromString(message.message).key;
              chats[message.sender.toString()].allowed = true;
            } else if (message.status == MessageStatus.SENT) {
              debugPrint(chats[message.sender.toString()].toString());
              chats[message.sender.toString()].chats[message.timestamp].status =
                  message.status;
            }
            notifyListeners();
          }
        }
      });
    });
  }

  allowChat(bool accept, Message message) {
    if (accept) {
      String senderKey = Request.fromString(message.message).key;
      message..message = Request(myPair.pubKey).toString();
      forwardMessage(message..status = MessageStatus.ACCEPTED);
      chats[message.sender.toString()] = Chat();
      chats[message.sender.toString()].allowed = true;
      chats[message.sender.toString()].key = senderKey;
      notifyListeners();
    } else
      forwardMessage(message..status = MessageStatus.DENY);
    P2P.navKey.currentState.pop();
  }

  Future<Socket> _connectToServer() async {
    debugPrint(_serverAddress.host);
    final sock = await Socket.connect(_serverAddress.host, serverPort);
    return sock;
  }

  requestPeers(String username) async {
    final Socket server = await _connectToServer();
    server.add('ROUTING_TABLE-$username'.codeUnits);
    Uint8List data =
        await server.timeout(Duration(seconds: 1), onTimeout: (abc) {}).first;
    String table = String.fromCharCodes(data);
    me = User.fromString(table.split('>')[0]);
    myPair = Encrypt();
    notifyListeners();
    debugPrint(me.toString());
    if (table.split('>').length > 1) {
      table = table.split('>')[1];
      table.split(';').forEach((peer) async {
        debugPrint(peer);
        Node node = Node.fromString(peer);
        outgoingNodes[node.user.uid] = node;
        await pingPeer(node.user.uid);
      });
    }
    setTimer();
    server.close();
  }

  setTimer() {
    if (_timer == null)
      _timer = Timer.periodic(Duration(minutes: 1), (timer) {
        outgoingNodes.keys.forEach((uid) async {
          await pingPeer(uid);
        });
      });
  }

  pingPeer(uid) async {
    try {
      final Socket peer =
          await Socket.connect(outgoingNodes[uid].ip.host, clientPort);
      peer.add('PING'.codeUnits);
      debugPrint('pinging $uid');
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
        _sendPeerDeadRequest(uid);
      }
    }
  }

  _sendPeerDeadRequest(int uid) async {
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

  sendQuitRequest() async {
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

  _sendMessage(Message message, InternetAddress address) async {
    try {
      final Socket peer = await Socket.connect(address.host, clientPort);
      debugPrint('Messages generated');
      if (message.status == MessageStatus.SENDING) {
        debugPrint(message.toString());
        peer.add(message.toString().codeUnits);
      } else {
        debugPrint(message.acknowledgementMessage());
        peer.add(message.acknowledgementMessage().codeUnits);
      }
      peer.close();
    } on Exception {}
  }

  forwardMessage(Message message) async {
    if ((message.timestamp - DateTime.now().millisecondsSinceEpoch).abs() >
            90 &&
        message.status == MessageStatus.SENDING) return;

    if (outgoingNodes.containsKey(message.receiver.uid) ||
        outgoingNodes.containsKey(message.sender.uid)) {
      debugPrint('Message outgoing $message');
      if (outgoingNodes.containsKey(message.receiver.uid))
        await _sendMessage(message, outgoingNodes[message.receiver.uid].ip);
      else
        await _sendMessage(message, outgoingNodes[message.sender.uid].ip);
    } else if (incomingNodes.containsKey(message.receiver.uid) ||
        incomingNodes.containsKey(message.sender.uid)) {
      debugPrint('Message incoming $message');
      if (incomingNodes.containsKey(message.receiver.uid))
        await _sendMessage(message, incomingNodes[message.receiver.uid].ip);
      else
        await _sendMessage(message, incomingNodes[message.sender.uid].ip);
    } else {
      debugPrint('Message hopping $message');
      Map<int, Node> allNodes = Map.from(incomingNodes);
      allNodes.addAll(outgoingNodes);
      if (allNodes.length > 0) {
        if (message.receiver.uid > message.sender.uid) {
          int dist = message.receiver.uid - message.sender.uid;
          int jump = (math.log(dist) ~/ math.log(2)).toInt();
          await _sendMessage(message, allNodes[message.sender.uid + jump].ip);
        } else {
          int dist = message.sender.uid - message.receiver.uid;
          int jump = (math.log(dist) ~/ math.log(2)).toInt();
          await _sendMessage(message, allNodes[message.sender.uid - jump].ip);
        }
      } else {
        await requestPeers(me.username);
        forwardMessage(message);
      }
    }
  }

  startNewChat(String username) async {
    final Socket server = await _connectToServer();
    server.add('UID_FROM_USERNAME-$username'.codeUnits);
    Uint8List data =
        await server.timeout(Duration(seconds: 1), onTimeout: (abc) {}).first;
    User receiver = User.fromString(String.fromCharCodes(data));
    server.close();

    if (chats.containsKey(receiver.toString())) {
      openChat(receiver);
    } else {
      int time = DateTime.now().millisecondsSinceEpoch;
      Message mess =
          Message(me, receiver, Request(myPair.pubKey).toString(), time);
      debugPrint('Message created $mess');
      await forwardMessage(mess);
      _appendMessage(receiver, mess, time);
    }
  }

  _appendMessage(User receiver, Message mess, int time) {
    if (!chats.containsKey(receiver.toString()))
      chats[receiver.toString()] = Chat();
    else {
      chats[receiver.toString()].chats[time] = mess
        ..message = myPair.decryption(mess.message);

      Timer(Duration(seconds: 90), () {
        if (chats[receiver.toString()].chats[time].status ==
            MessageStatus.SENDING) {
          chats[receiver.toString()].chats[time].status = MessageStatus.TIMEOUT;
          notifyListeners();
        }
      });
    }
  }

  openChat(User user) {
    P2P.navKey.currentState.push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: this,
          child: ChatScreen(user),
        ),
      ),
    );
  }

  createMessage(String username) async {
    int time = DateTime.now().millisecondsSinceEpoch;
    User receiver;
    chats.keys.any((user) {
      if (user.endsWith('@$username')) {
        receiver = User.fromString(user);
        return true;
      }
      return false;
    });
    Message mess = Message(me, receiver,
        myPair.encryption(chatBox.text, chats[receiver.toString()].key), time);
    debugPrint('Message created $mess');
    await forwardMessage(mess);
    chatBox.text = '';
    _appendMessage(receiver, mess, time);
    notifyListeners();
  }

  deleteChats() {
    chats.clear();
    notifyListeners();
  }

  showPopup(Message message) {
    return showDialog(
      context: this.scaffoldKey.currentState.context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          child: WillPopScope(
            onWillPop: () {
              return Future(() => false);
            },
            child: SingleChildScrollView(
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Allow chat from user ${message.sender.username}?',
                      textScaleFactor: 1.4,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: OutlineButton(
                          child: Text('Allow'),
                          color: Colors.green,
                          onPressed: () => allowChat(true, message),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: OutlineButton(
                          child: Text('Deny'),
                          color: Colors.red,
                          onPressed: () => allowChat(false, message),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
