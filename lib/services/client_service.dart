import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:math';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
  Map<String, BroadcastMessage> _broadcastChat = {};

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

  setupIncomingServer() async {
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
    FirebaseUser user = await FirebaseAuth.instance.currentUser();
    await setupListener();
    sendBuffer('ROUTING_TABLE>${user.uid}'.codeUnits, _serverAddress);
  }

  setupListener() {
    _mySock.stream.listen((datagram) async {
      if (String.fromCharCodes(datagram.data) == 'PING') {
        sendDatagramBuffer('PONG>${me.uid}'.codeUnits, datagram);
      } else if (String.fromCharCodes(datagram.data).startsWith('PONG>')) {
        String uid = String.fromCharCodes(datagram.data).split('>')[1];
        if (uid != 'HOST') {
          outgoingNodes[uid].downCount = 0;
          outgoingNodes[uid].state = true;
        }
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
      } else if (String.fromCharCodes(datagram.data).startsWith('BROADCAST>')) {
        BroadcastMessage message =
        BroadcastMessage.fromString(String.fromCharCodes(datagram.data));
        _broadcastChat['${message.timestamp}-${message.sender}'] = message;
        notifyListeners();
        _broadcastMessage(message);
      } else if (String.fromCharCodes(datagram.data)
          .startsWith('ROUTING_TABLE>')) {
        String table = String.fromCharCodes(datagram.data);
        me = User.fromString(table.split('>')[0]);
        myPair = Encrypt();
        notifyListeners();
        debugPrint(me.toString());
        if (table
            .split('>')
            .length > 1) {
          table = table.split('>')[1];
          String incomingTable = table.split('&&&&')[0];
          incomingTable.split(';').forEach((peer) async {
            debugPrint(peer);
            Node node = Node.fromString(peer);
            incomingNodes[node.user.numbering] = node;
            await pingPeer(node.user.numbering);
          });
          String outgoingTable = table.split('&&&&')[1];
          outgoingTable.split(';').forEach((peer) async {
            debugPrint(peer);
            Node node = Node.fromString(peer);
            outgoingNodes[node.user.numbering] = node;
            await pingPeer(node.user.numbering);
          });
        }
        setTimer();
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
                Request
                    .fromString(message.message)
                    .key;
            chats[message.sender.toString()].allowed = true;
          } else if (message.status == MessageStatus.SENT) {
            chats[message.sender.toString()].chats[message.timestamp].status =
                message.status;
          }
          notifyListeners();
        }
      } else if (String.fromCharCodes(datagram.data).startsWith('DEAD>')) {
        String uid = String.fromCharCodes(datagram.data).split('>')[1];
        outgoingNodes.remove(uid);
      } else if (String.fromCharCodes(datagram.data).startsWith('NOT_DEAD>')) {
        String uid = String.fromCharCodes(datagram.data).split('>')[1];
        pingPeer(uid);
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
      String senderKey = Request
          .fromString(message.message)
          .key;
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

  setTimer() {
    if (_timer == null)
      _timer = Timer.periodic(Duration(minutes: 1), (timer) {
        outgoingNodes.keys.forEach((uid) async {
          await pingPeer(uid);
        });
      });
  }

  pingPeer(uid) async {
    if (!outgoingNodes[uid].state && outgoingNodes[uid].downCount > 2) {
      sendBuffer('DEAD>$uid'.codeUnits, _serverAddress);
      return;
    }
    outgoingNodes[uid].downCount++;
    outgoingNodes[uid].state = false;
    sendBuffer('PING'.codeUnits, outgoingNodes[uid].socket);
  }

  sendQuitRequest() async {
    sendBuffer('QUIT>${me.numbering}'.codeUnits, _serverAddress);
    _timer.cancel();
    _sock1.close();
    _sock2.close();
    P2P.navKey.currentState.pop();
  }

//  Future<User> requestUID(String ip) async {
//    final Socket server = await _connectToServer();
//    server.add('UID_FROM_IP-$ip'.codeUnits);
//    Uint8List data =
//        await server.timeout(Duration(seconds: 1), onTimeout: (abc) {
//      return false;
//    }).first;
//    await server.close();
//    return User.fromString(String.fromCharCodes(data));
//  }

  _sendMessage(Message message, SocketAddress dest) async {
    try {
      debugPrint('Messages generated');
      if (message.status == MessageStatus.SENDING) {
        debugPrint(message.toString());
        sendBuffer(message
            .toString()
            .codeUnits, dest);
      } else {
        debugPrint(message.acknowledgementMessage());
        sendBuffer(message
            .acknowledgementMessage()
            .codeUnits, dest);
      }
    } on Exception {}
  }

  forwardMessage(Message message) async {
    if ((message.timestamp - DateTime
        .now()
        .millisecondsSinceEpoch).abs() >
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
        sendBuffer('ROUTING_TABLE>${me.uid}'.codeUnits, _serverAddress);
        forwardMessage(message);
      }
    }
  }

//  startNewChat(String username) async {
//    if (username == me.username) {
//      Fluttertoast.showToast(msg: "Can't send message to yourself");
//      return;
//    }
//    final Socket server = await _connectToServer();
//    server.add('UID_FROM_USERNAME-$username'.codeUnits);
//    Uint8List data =
//        await server.timeout(Duration(seconds: 1), onTimeout: (abc) {}).first;
//    if (String.fromCharCodes(data) == 'null') {
//      Fluttertoast.showToast(msg: "User doesn't exist");
//      return;
//    }
//    User receiver = User.fromString(String.fromCharCodes(data));
//    server.close();
//
//    if (chats.containsKey(receiver.toString())) {
//      P2P.navKey.currentState.pop(); //todo
//      openChat(receiver);
//    } else {
//      int time = DateTime.now().millisecondsSinceEpoch;
//      Message mess =
//          Message(me, receiver, Request(myPair.pubKey).toString(), time);
//      await forwardMessage(mess);
//      _appendMessage(receiver, mess, time);
//    }
//  }

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
        builder: (_) =>
            ChangeNotifierProvider.value(
              value: this,
              child: ChatScreen(user),
            ),
      ),
    );
  }

  createMessage(String username) async {
    int time = DateTime
        .now()
        .millisecondsSinceEpoch;
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

  bool areNodesConnected(int node1, int node2, int last) {
//    if (node1 == node2)
//      return false;
    if (node2 < node1) {
      node2 += last;
    }
    // checking if number is in powers of 2
    double distance =
        log(node2 - node1) / log(2); // converting number to log base 2
    return distance % 1 == 0; // checking for integer value
  }

// calculates incoming and outgoing nodes of newNode
  List updateRoutingTable(int lastNode) {
    //todo:  update only peers whose numbering is smaller than me
    int myId = me.numbering;
    for (int number = 0; number <= lastNode; ++number) {
      if (myId == number) continue;
      // Outgoing Nodes
      if (areNodesConnected(myId, number, lastNode + 1)) {
        // check if don't exist in connection
        if (outgoingNodes.containsKey(number) == false) {
          outgoingNodes[number] = getUserData(number);
        }
      } else {
        // remove if present
        if (outgoingNodes.containsKey(number)) {
          outgoingNodes.remove(number);
        }
      }
      // Incoming Nodes
      if (areNodesConnected(number, myId, lastNode + 1)) {
        // check if don't exist in connection
        if (incomingNodes.containsKey(number) == false) {
          incomingNodes[number] = getUserData(number);
        }
      } else {
        // remove if present
        if (incomingNodes.containsKey(number)) {
          incomingNodes.remove(number);
        }
      }
    }
  }

  getUserData(int number) {}

  createBroadcastMessage(String message) {
    BroadcastMessage mess = BroadcastMessage(me, message);
    _broadcastChat['${mess.timestamp}-${mess.sender}'] = mess;
    _broadcastMessage(mess);
  }

  _broadcastMessage(BroadcastMessage feed) {
// sendBuffer(feed.toString().codeUnits, node.socket);
    int senderId = feed.sender.numbering;
    int x = 0;
    int p = 1;
    for (int i = me.numbering + p; i + p < outgoingNodes) {
      if (outgoingNodes[i].state) {
        // send feed[j] to ith node
        sendBuffer(feed
            .toString()
            .codeUnits, node.socket);
        ++x;
      }
    }
  }
}
