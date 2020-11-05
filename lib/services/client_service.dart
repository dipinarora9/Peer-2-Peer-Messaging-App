import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:peer2peer/models/common_classes.dart';
import 'package:peer2peer/models/native_models.dart';
import 'package:peer2peer/screens/private_chat.dart';
import 'package:provider/provider.dart';

import 'native_utils.dart';
import 'p2p.dart';

class ClientService with ChangeNotifier {
  SocketAddress _clientSocket;
  SocketAddress _serverAddress;
  StreamController<MyDatagram> _mySock = StreamController<MyDatagram>();
  Map<int, Node> _incomingNodes = {};
  Map<int, Node> _outgoingNodes = {};
  Timer _timer;
  User me;
  Encrypt myPair;
  Map<String, Chat> chats = {};
  RawDatagramSocket _sock1;
  RawDatagramSocket _sock2;
  Map<String, BroadcastMessage> _broadcastChat = {};
  final List<String> actions = ['Debug Info', 'Share Link', 'Quit'];
  String _meetingId;
  int _lastNodeTillNow = 0;
  final interactiveCppRequests = ReceivePort()..listen(handleCppRequests);
  int nativePort;
  SendPort sendPort;
  bool play = false;

  //todo: for debugging purpose
  Map<int, Node> get incomingNodes => _incomingNodes;

  Map<int, Node> get outgoingNodes => _outgoingNodes;

  Map<String, BroadcastMessage> get broadcastChat => _broadcastChat;
  final TextEditingController chatBox = TextEditingController();
  final FocusNode chatFocus = FocusNode();
  final ScrollController chatController = ScrollController();

  String get meetingId => _meetingId;

  ClientService(this._clientSocket, this._serverAddress, this._meetingId);

  initialize(String uid) async {
    _sock1 = await RawDatagramSocket.bind(
        '0.0.0.0', _clientSocket.external.port,
        reuseAddress: true, ttl: 255);
    _sock2 = await RawDatagramSocket.bind(
        '0.0.0.0', _clientSocket.internal.port,
        reuseAddress: true, ttl: 255);
    _sock1.listen((event) {
      if (event == RawSocketEvent.read) {
        Datagram datagram = _sock1.receive();
        if (datagram != null) _mySock.add(MyDatagram(datagram, _sock1.port));
      }
    });
    _sock2.listen((event) {
      if (event == RawSocketEvent.read) {
        Datagram datagram = _sock2.receive();
        if (datagram != null) _mySock.add(MyDatagram(datagram, _sock2.port));
      }
    });
    _setupListener();
    _sendDummy(_serverAddress);
    debugPrint('Requesting routing table');
    _sendBuffer('ROUTING_TABLE>$uid'.codeUnits, _serverAddress);
    Timer.periodic(Duration(seconds: 10), (timer) {
      if (me == null) {
        debugPrint('Nat Hole Punching Unsuccessful😢');
        Fluttertoast.showToast(msg: 'Nat Hole Punching Unsuccessful😢');
        P2P.navKey.currentState.pop();
      }
      timer.cancel();
    });
//    if (_meetingId == '') _sendBuffer('MEETING_ID'.codeUnits, _serverAddress);
    chatController.jumpTo(chatController.position.maxScrollExtent + 100);
  }

  _setupListener() {
    _mySock.stream.listen((datagram) async {
      if (datagram.data[0] == 9 &&
          datagram.data[datagram.data.length - 1] == 9) {
        NativeUtils.playBuffer(
            outPlayer,
            NativeUtils.toPointer(
                datagram.data.sublist(1, datagram.data.length - 2)),
            datagram.data.length - 2);
      } else if (String.fromCharCodes(datagram.data) == 'PING') {
        _sendDatagramBuffer('PONG>${me.numbering}'.codeUnits, datagram);
      } else if (String.fromCharCodes(datagram.data).startsWith('PONG>')) {
        int numbering =
            int.parse(String.fromCharCodes(datagram.data).split('>')[1]);
        if (numbering != -1) {
          _outgoingNodes[numbering].downCount = 0;
          _outgoingNodes[numbering].state = true;
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
          } else {
            //todo: check
          }
          notifyListeners();
        }
      } else if (String.fromCharCodes(datagram.data).startsWith('BROADCAST>')) {
        BroadcastMessage message =
            BroadcastMessage.fromString(String.fromCharCodes(datagram.data));
        if (!_broadcastChat
            .containsKey('${message.timestamp}-${message.sender}')) {
          _broadcastChat['${message.timestamp}-${message.sender}'] = message;
          notifyListeners();
          chatController.animateTo(
              chatController.position.maxScrollExtent + 150,
              curve: Curves.easeIn,
              duration: Duration(milliseconds: 200));
          _broadcastMessage(message);
        }
      } else if (String.fromCharCodes(datagram.data).startsWith('UPDATE_')) {
        Node user =
            Node.fromString(String.fromCharCodes(datagram.data).split('>')[1]);
        if (String.fromCharCodes(datagram.data)
            .split('>')[0]
            .startsWith('UPDATE_INCOMING')) _sendDummy(user.socket);
        _updateRoutingTable(int.parse(
            String.fromCharCodes(datagram.data).split('>')[0].split('_').last));
      } else if (String.fromCharCodes(datagram.data)
          .startsWith('ROUTING_TABLE_')) {
        String table = String.fromCharCodes(datagram.data);
        _lastNodeTillNow = int.parse(table.split('>')[0].split('_').last);
        me = User.fromString(table.split('>')[1]);
        myPair = Encrypt();
        notifyListeners();
        if (table.split('>').length > 2) {
          table = table.split('>')[2];
          debugPrint(table.toString());
          String incomingTable = table.split('&&&&')[0];
          incomingTable.split(';').forEach((peer) {
            if (peer != '') {
              Node node = Node.fromString(peer);
              _incomingNodes[node.user.numbering] = node;
              _sendDummy(node.socket);
            }
          });
          String outgoingTable = table.split('&&&&')[1];
          outgoingTable.split(';').forEach((peer) async {
            if (peer != '') {
              Node node = Node.fromString(peer);
              _outgoingNodes[node.user.numbering] = node;
              await pingPeer(node.user.uid);
            }
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
                Request.fromString(message.message).key;
            chats[message.sender.toString()].allowed = true;
          } else if (message.status == MessageStatus.SENT) {
            chats[message.sender.toString()].chats[message.timestamp].status =
                message.status;
          }
          notifyListeners();
        }
      } else if (String.fromCharCodes(datagram.data).startsWith('DEAD_')) {
        User deadUser =
            User.fromString(String.fromCharCodes(datagram.data).split('>')[1]);
        _updateRoutingTable(
            int.parse(String.fromCharCodes(datagram.data)
                .split('>')[0]
                .split('_')[1]),
            dead: deadUser.numbering);
      } else if (String.fromCharCodes(datagram.data).startsWith('NOT_DEAD>')) {
        String uid = String.fromCharCodes(datagram.data).split('>')[1];
        int num = _getUser(uid);
        _outgoingNodes[num].downCount = 0;
        _outgoingNodes[num].state = true;
        pingPeer(uid);
      } else if (String.fromCharCodes(datagram.data).startsWith('USER_')) {
        Node node =
            Node.fromString(String.fromCharCodes(datagram.data).split('>')[1]);
        if (String.fromCharCodes(datagram.data)
            .split('>')[0]
            .startsWith('USER_INCOMING'))
          _incomingNodes[node.user.numbering] = node;
        else
          _outgoingNodes[node.user.numbering] = node;
      }
    });
  }

  void _sendDummy(SocketAddress dest) {
    debugPrint('SENDING DUMMY message to $dest');
    _sendBuffer([], dest);
    _sendBuffer([], dest);
    _sendBuffer([], dest);
    _sendBuffer([], dest);
  }

  void _sendDatagramBuffer(List<int> buffer, MyDatagram datagram) {
    if (datagram.myPort == _sock1.port)
      _sock1.send(buffer, datagram.address, datagram.port);
    else
      _sock2.send(buffer, datagram.address, datagram.port);
  }

  void _sendBuffer(List<int> buffer, SocketAddress dest) {
    if (_clientSocket.external.address == dest.external.address)
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

  setTimer() {
    if (_timer == null)
      _timer = Timer.periodic(Duration(minutes: 1), (timer) {
        _outgoingNodes.values.forEach((user) async {
          await pingPeer(user.user.uid);
        });
      });
  }

  int _getUser(String uid) {
    int numbering;
    _outgoingNodes.values.any((v) {
      if (v.user.uid == uid) {
        numbering = v.user.numbering;
        return true;
      }
      return false;
    });
    return numbering;
  }

  pingPeer(String uid) async {
    int num = _getUser(uid);
    if (!_outgoingNodes[num].state && _outgoingNodes[num].downCount > 2) {
      _sendBuffer(
          'DEAD>${_outgoingNodes[num].user.uid}'.codeUnits, _serverAddress);
      return;
    }
    _outgoingNodes[num].downCount++;
    _outgoingNodes[num].state = false;
    _sendBuffer('PING'.codeUnits, _outgoingNodes[num].socket);
  }

  sendQuitRequest() async {
    _sendBuffer('QUIT>${me.numbering}'.codeUnits, _serverAddress);
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
        _sendBuffer(message.toString().codeUnits, dest);
      } else {
        debugPrint(message.acknowledgementMessage());
        _sendBuffer(message.acknowledgementMessage().codeUnits, dest);
      }
    } on Exception {}
  }

  forwardMessage(Message message) async {
    if ((message.timestamp - DateTime.now().millisecondsSinceEpoch).abs() >
            90 &&
        message.status == MessageStatus.SENDING) return;

    if (_outgoingNodes.containsKey(message.receiver.numbering) ||
        _outgoingNodes.containsKey(message.sender.numbering)) {
      debugPrint('Message outgoing $message');
      if (_outgoingNodes.containsKey(message.receiver.numbering))
        await _sendMessage(
            message, _outgoingNodes[message.receiver.numbering].socket);
      else
        await _sendMessage(
            message, _outgoingNodes[message.sender.numbering].socket);
    } else if (_incomingNodes.containsKey(message.receiver.numbering) ||
        _incomingNodes.containsKey(message.sender.numbering)) {
      debugPrint('Message incoming $message');
      if (_incomingNodes.containsKey(message.receiver.numbering))
        await _sendMessage(
            message, _incomingNodes[message.receiver.numbering].socket);
      else
        await _sendMessage(
            message, _incomingNodes[message.sender.numbering].socket);
    } else {
      debugPrint('Message hopping $message');
      Map<int, Node> allNodes = Map.from(_incomingNodes);
      allNodes.addAll(_outgoingNodes);
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
        _sendBuffer('ROUTING_TABLE>${me.uid}'.codeUnits, _serverAddress);
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
        builder: (_) => ChangeNotifierProvider.value(
          value: this,
          child: PrivateChat(user),
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
    chatController.animateTo(chatController.position.maxScrollExtent + 150,
        curve: Curves.easeIn, duration: Duration(milliseconds: 200));
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

  bool areNodesConnected(int node1, int node2, int last) {
//    if (node1 == node2)
//      return false;
    if (node2 < node1) {
      node2 += last;
    }
    // checking if number is in powers of 2
    double distance = math.log(node2 - node1) /
        math.log(2); // converting number to log base 2
    return distance % 1 == 0; // checking for integer value
  }

// calculates incoming and outgoing nodes of newNode
  void _updateRoutingTable(int lastNode, {int dead}) {
    _lastNodeTillNow = lastNode;
    int myId = me.numbering, outgoingDeadCount = 0, incomingDeadCount = 0;
    for (int number = 0; number <= lastNode; ++number) {
      if (myId == number) continue;
      // Outgoing Nodes
      if (areNodesConnected(myId, number - outgoingDeadCount, lastNode + 1)) {
        // checking if state if false
        if (number == dead) {
          if (_outgoingNodes.containsKey(number)) _outgoingNodes.remove(number);
          ++outgoingDeadCount;
        }
        // check if don't exist in connection
        else if (!_outgoingNodes.containsKey(number)) {
          _sendBuffer('GET_OUTGOING>$number'.codeUnits, _serverAddress);
        }
      } else {
        if (_outgoingNodes.containsKey(number)) {
          _outgoingNodes.remove(number);
        }
      }
      // Incoming Nodes
      if (areNodesConnected(number + incomingDeadCount, myId, lastNode + 1)) {
        if (number == dead) {
          if (_incomingNodes.containsKey(number)) _incomingNodes.remove(number);
          ++incomingDeadCount;
        }
        // check if don't exist in connection
        else if (!_incomingNodes.containsKey(number)) {
          _sendBuffer('GET_INCOMING>$number'.codeUnits, _serverAddress);
        }
      } else {
        if (_incomingNodes.containsKey(number)) {
          _incomingNodes.remove(number);
        }
      }
    }
  }

  createBroadcastMessage() {
    if (chatBox.text == ' ' || chatBox.text == '') {
      chatBox.clear();
      chatFocus.unfocus();
      return;
    }
    BroadcastMessage mess = BroadcastMessage(me, chatBox.text);
    _broadcastChat['${mess.timestamp}-${mess.sender}'] = mess;
    notifyListeners();
    chatController.animateTo(chatController.position.maxScrollExtent + 150,
        curve: Curves.easeIn, duration: Duration(milliseconds: 200));
    chatBox.clear();
    _broadcastMessage(mess);
  }

  _broadcastMessage(BroadcastMessage feed) {
    int senderId = feed.sender.numbering;
    int p = 1, last = _lastNodeTillNow;
    int i = me.numbering;
    if (senderId <= me.numbering) {
      for (i = me.numbering; i + p <= last; p *= 2) {
        debugPrint('sending message to ${_outgoingNodes[i + p].user}');
        _sendBuffer(feed.toString().codeUnits, _outgoingNodes[i + p].socket);
      }
      if (i + p > senderId) i -= (last + 1);
    }
    for (; i + p < senderId; p *= 2) {
      debugPrint('sending message to ${_outgoingNodes[i + p].user}');
      _sendBuffer(feed.toString().codeUnits, _outgoingNodes[i + p].socket);
    }
  }

  broadcastBytes(List<int> bytes) {
    int senderId = me.numbering;
    int p = 1, last = _lastNodeTillNow;
    int i = me.numbering;
    if (senderId <= me.numbering) {
      for (i = me.numbering; i + p <= last; p *= 2) {
        debugPrint('sending message to ${_outgoingNodes[i + p].user}');
        _sendBuffer(bytes, _outgoingNodes[i + p].socket);
      }
      if (i + p > senderId) i -= (last + 1);
    }
    for (; i + p < senderId; p *= 2) {
      debugPrint('sending message to ${_outgoingNodes[i + p].user}');
      _sendBuffer(bytes, _outgoingNodes[i + p].socket);
    }
  }

  setupCallbackReceivers() {
    nativePort = interactiveCppRequests.sendPort.nativePort;
  }

  static void handleCppRequests(dynamic message) {
    final cppRequest = CppRequest.fromCppMessage(message);
    if (cppRequest.method == 'audio_buffer') {
      // NativeUtils.playBuffer(outPlayer, NativeUtils.toPointer(cppRequest.data),
      //     cppRequest.data.length);
      final List<int> temp = cppRequest.data;
      List<int> buffer = Uint8List(temp.length + 2);
      buffer[0] = 9;
      for (int i = 0; i < temp.length; i++) buffer[i + 1] = temp[i];
      buffer[buffer.length - 1] = 9;
      globalClient.broadcastBytes(buffer);
    } else if (cppRequest.method == 'sample_rate') {
      debugPrint("SAMPLE RATE AAGYA     ${cppRequest.replyPort}");
    }
  }

  bool _recording = false;

  bool get recording => _recording;

  record() {
    _recording = !_recording;
    notifyListeners();
    debugPrint(nativePort.toString());
    int result = NativeUtils.nativeRecord(
        inPlayer, outPlayer, _recording ? 1 : 0, nativePort);
    debugPrint('HERE IS IT Recording $result');
  }
}
