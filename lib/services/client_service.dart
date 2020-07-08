import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:peer2peer/models/common_classes.dart';
import 'package:peer2peer/screens/chat_screen.dart';
import 'package:provider/provider.dart';

import 'p2p.dart';

class ClientService with ChangeNotifier {
  SocketAddress _clientSocket;
  SocketAddress _serverAddress;
  StreamController<MyDatagram> _mySock = StreamController<MyDatagram>();
  Map<int, Node> incomingNodes = {};
  Map<int, Node> outgoingNodes = {};
  Timer _timer;
  User me;
  Encrypt myPair;
  Map<String, Chat> chats = {};
  RawDatagramSocket _sock1;
  RawDatagramSocket _sock2;
  Map<int, BroadcastMessage> _broadcastChat = {};

//  String text = '';
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController chatBox = TextEditingController();
  final ScrollController chatController = ScrollController();

  ClientService(this._clientSocket, this._serverAddress);

//  Future<bool> requestUsername(String username) async {
//    bool flag = false;
//    final Socket server = await _connectToServer();
//    server.add('USERNAME-$username'.codeUnits);
//    Uint8List data =
//        await server.timeout(Duration(seconds: 1), onTimeout: (abc) {
//      return false;
//    }).first;
//    if (String.fromCharCodes(data).startsWith('ACCEPTED>')) flag = true;
//    server.close();
//    if (flag)
//      setupIncomingServer(String.fromCharCodes(data).substring(9));
//    else
//      Fluttertoast.showToast(msg: 'Username already taken');
//    return flag;
//  }

  setupIncomingServer(String username) async {
    _sock1 =
        await RawDatagramSocket.bind('0.0.0.0', _clientSocket.external.port);
    _sock2 =
        await RawDatagramSocket.bind('0.0.0.0', _clientSocket.internal.port);
    _sock1.listen((event) {
      if (event == RawSocketEvent.read)
        _mySock.add(MyDatagram(_sock1.receive(), _sock1.port));
    });
    _sock2.listen((event) {
      if (event == RawSocketEvent.read)
        _mySock.add(MyDatagram(_sock2.receive(), _sock2.port));
    });
    await setupListener();
    await requestPeers(username);
  }

  setupListener() {
    _mySock.stream.listen((datagram) async {
      if (String.fromCharCodes(datagram.data) == 'PING') {
        sendDatagramBuffer('PONG'.codeUnits, datagram);
//        if (datagram.address != _serverAddress) {
//          bool callServer = true;
//          incomingNodes.values.any((peer) {
//            if (peer.ip == datagram.address) {
//              incomingNodes[peer.user.numbering].state = true;
//              callServer = false;
//              return true;
//            }
//            return false;
//          });
//          if (callServer) {
//            User user = await requestUID(datagram.address.host);
//            incomingNodes[user.numbering] = Node(datagram.address, user);
//          }
//        }
      } else if (String.fromCharCodes(datagram.data).startsWith('MESSAGE>')) {
        Message message =
            Message.fromString(String.fromCharCodes(datagram.data));

        /// A - sender
        /// B - receiver
        ///
        /// A-> B
        if (message.receiver.numbering != me.numbering)
          forwardMessage(message);
        else {
          if (chats.containsKey(message.sender.toString())) {
            chats[message.sender.toString()].chats[message.timestamp] = message
              ..message = myPair.decryption(
                  chats[message.sender.toString()].key, message.message);
            notifyListeners();
            forwardMessage(message..status = MessageStatus.SENT);
          } else
            showPopup(message);
          notifyListeners();
        }
      } else if (String.fromCharCodes(datagram.data)
          .startsWith('ACKNOWLEDGED>')) {
        Message message =
            Message.fromAcknowledgement(String.fromCharCodes(datagram.data));
        debugPrint(message.acknowledgementMessage());

        /// B - sender
        /// A - receiver
        ///
        /// A-> B
        if (message.receiver.numbering != me.numbering)
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
            chats[message.sender.toString()].chats[message.timestamp].status =
                message.status;
          }
          notifyListeners();
        }
      }
    });
  }

  void sendDatagramBuffer(Uint8List buffer, MyDatagram datagram) {
    if (datagram.myPort == _sock1.port)
      _sock1.send(buffer, datagram.address, datagram.port);
    else
      _sock2.send(buffer, datagram.address, datagram.port);
  }

  void sendBuffer(Uint8List buffer, SocketAddress dest) {
    if (_clientSocket.external == dest.external)
      _sock2.send(buffer, dest.internal.address, dest.internal.port);
    else
      _sock1.send(buffer, dest.external.address, dest.external.port);
  }

  allowChat(bool accept, Message message) {
    if (accept) {
      String senderKey = Request.fromString(message.message).key;
      message..message = Request(myPair.pubKey).toString();
      forwardMessage(message..status = MessageStatus.ACCEPTED);
      chats[message.sender.toString()] = Chat();
      chats[message.sender.toString()].allowed = true;
      chats[message.sender.toString()].key = senderKey;
      chats[message.sender.toString()].chats = <int, Message>{};
      notifyListeners();
    } else
      forwardMessage(message..status = MessageStatus.DENY);
    P2P.navKey.currentState.pop();
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
        outgoingNodes[node.user.numbering] = node;
        await pingPeer(node.user.numbering);
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
      sendBuffer('PING>${me.uid}'.codeUnits, outgoingNodes[uid].socket);
      debugPrint('pinging $uid');

      // todo: incorporate into listener
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
    } on Exception {
      outgoingNodes[uid].state = false;
      outgoingNodes[uid].downCount++;
      if (outgoingNodes[uid].downCount > 2) {
        _sendPeerDeadRequest(uid);
      }
    }
  }

  //todo:  incorporate into listener
  _sendPeerDeadRequest(int uid) async {
    sendBuffer('DEAD-$uid'.codeUnits, _serverAddress);
    Uint8List data =
        await server.timeout(Duration(seconds: 1), onTimeout: (abc) {
      return false;
    }).first;

    if (String.fromCharCodes(data) == 'DEAD') {
      outgoingNodes.remove(uid);
    } else if (String.fromCharCodes(data) == 'NOT_DEAD') {
      pingPeer(uid);
    }
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

  _sendMessage(Message message, SocketAddress dest) async {
    try {
      debugPrint('Messages generated');
      if (message.status == MessageStatus.SENDING) {
        debugPrint(message.toString());
        sendBuffer(message.toString().codeUnits, dest);
      } else {
        debugPrint(message.acknowledgementMessage());
        sendBuffer(message.acknowledgementMessage().codeUnits, dest);
      }
    } on Exception {}
  }

  forwardMessage(Message message) async {
    if ((message.timestamp - DateTime.now().millisecondsSinceEpoch).abs() >
            90 &&
        message.status == MessageStatus.SENDING) return;

    if (outgoingNodes.containsKey(message.receiver.numbering) ||
        outgoingNodes.containsKey(message.sender.numbering)) {
      debugPrint('Message outgoing $message');
      if (outgoingNodes.containsKey(message.receiver.numbering))
        await _sendMessage(
            message, outgoingNodes[message.receiver.numbering].socket);
      else
        await _sendMessage(
            message, outgoingNodes[message.sender.numbering].socket);
    } else if (incomingNodes.containsKey(message.receiver.numbering) ||
        incomingNodes.containsKey(message.sender.numbering)) {
      debugPrint('Message incoming $message');
      if (incomingNodes.containsKey(message.receiver.numbering))
        await _sendMessage(
            message, incomingNodes[message.receiver.numbering].socket);
      else
        await _sendMessage(
            message, incomingNodes[message.sender.numbering].socket);
    } else {
      debugPrint('Message hopping $message');
      Map<int, Node> allNodes = Map.from(incomingNodes);
      allNodes.addAll(outgoingNodes);
      if (allNodes.length > 0) {
        if (message.receiver.numbering > message.sender.numbering) {
          int dist = message.receiver.numbering - message.sender.numbering;
          int jump = (math.log(dist) ~/ math.log(2)).toInt();
          await _sendMessage(
              message, allNodes[message.sender.numbering + jump].socket);
        } else {
          int dist = message.sender.numbering - message.receiver.numbering;
          int jump = (math.log(dist) ~/ math.log(2)).toInt();
          await _sendMessage(
              message, allNodes[message.sender.numbering - jump].socket);
        }
      } else {
        await requestPeers(me.username);
        forwardMessage(message);
      }
    }
  }

  startNewChat(String username) async {
    if (username == me.username) {
      Fluttertoast.showToast(msg: "Can't send message to yourself");
      return;
    }
    final Socket server = await _connectToServer();
    server.add('UID_FROM_USERNAME-$username'.codeUnits);
    Uint8List data =
        await server.timeout(Duration(seconds: 1), onTimeout: (abc) {}).first;
    if (String.fromCharCodes(data) == 'null') {
      Fluttertoast.showToast(msg: "User doesn't exist");
      return;
    }
    User receiver = User.fromString(String.fromCharCodes(data));
    server.close();

    if (chats.containsKey(receiver.toString())) {
      P2P.navKey.currentState.pop(); //todo
      openChat(receiver);
    } else {
      int time = DateTime.now().millisecondsSinceEpoch;
      Message mess =
          Message(me, receiver, Request(myPair.pubKey).toString(), time);
      await forwardMessage(mess);
      _appendMessage(receiver, mess, time);
    }
  }

  _appendMessage(User receiver, Message mess, int time) {
    if (!chats.containsKey(receiver.toString())) {
      chats[receiver.toString()] = Chat();
      chats[receiver.toString()].chats = <int, Message>{};
    } else {
      chats[receiver.toString()].chats[time] = mess;

      Timer(Duration(seconds: 90), () {
        if (chats[receiver.toString()].chats[time] != null &&
            chats[receiver.toString()].chats[time].status ==
                MessageStatus.SENDING) {
          chats[receiver.toString()].chats[time].status = MessageStatus.TIMEOUT;
          notifyListeners();
        }
      });
    }
    notifyListeners();
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
    Message mess = Message(me, receiver, chatBox.text, time);
    _appendMessage(receiver, mess, time);
    chatController.animateTo(chatController.position.maxScrollExtent + 100,
        curve: Curves.easeIn, duration: Duration(milliseconds: 500));
    Message f = Message.fromString(mess.toString());
    await forwardMessage(f
      ..message =
          myPair.encryption(chats[receiver.toString()].key, chatBox.text));

    chatBox.text = '';
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
                        child: MaterialButton(
                          child: Text('Allow'),
                          color: Colors.green,
                          onPressed: () => allowChat(true, message),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: MaterialButton(
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

// calculates incoming and outgoing nodes of newNode
  List updateRoutingTable(int lastNode) {
    int distance = 1, till = lastNode + 1;
    //todo:  update only peers whose numbering is smaller than me
    int myId = me.numbering;

//     Outgoing Nodes
    while (myId + distance <= lastNode) {
      //todo: value at [myId + distance]
      outgoingNodes.add(myId + distance);
      distance *= 2;
    }
    // outgoing cycle
    while ((myId + distance) % till < myId) {
      //todo: value at [(myId + distance) % till]
      outgoingNodes.add((myId + distance) % till);
      distance *= 2;
    }
//    Incoming Nodes
    distance = 1;
    while (myId - distance >= 0) {
      //todo: value at [myId - distance]
      incomingNodes.add(myId - distance);
      distance *= 2;
    }
    // incoming cycle
    while (myId - distance + lastNode + 1 > myId) {
      //todo: value at [myId - distance + _lastNodeTillNow + 1]
      incomingNodes.add(myId - distance + lastNode + 1);
      distance *= 2;
    }
  }

  getUserData(int number) {}

  createBroadcastMessage(String message) {
    BroadcastMessage mess = BroadcastMessage(message);
    _broadcastChat[mess.timestamp] = mess;
    _broadcastMessage({me.numbering: mess});
  }

  _broadcastMessage(Map<int, BroadcastMessage> feed) {
    int x = 1;
    for (Node node in outgoingNodes.values) {
      if (node.state == true) {
        for (int j = me.numbering, k = 0; j >= 0 && k < x; --j, ++k) {
          // send feed[j] to ith node
          sendBuffer(feed[j].toString().codeUnits, node.socket);
        }
        ++x;
      }
    }
  }
}
