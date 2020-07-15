import 'dart:async';
import 'dart:io';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:peer2peer/models/common_classes.dart';

import 'p2p.dart';

class ServerService with ChangeNotifier {
  Map<int, Node> allNodes = {};
  StreamController<MyDatagram> _mySock = StreamController<MyDatagram>();
  final SocketAddress _serverSocket;
  int _lastNodeTillNow;
  final String _roomKey;
  RawDatagramSocket _sock1;
  RawDatagramSocket _sock2;
  Map<String, List<MyDatagram>> _deadBacklog = {};

  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  ServerService(this._serverSocket, this._roomKey);

  initialize(SocketAddress clientSock, String uid, String username) async {
    _addNode(clientSock, uid, username);
    FirebaseDatabase.instance
        .reference()
        .child('rooms')
        .child(_roomKey)
        .onChildAdded
        .listen((event) async {
      if (event.snapshot.key != 'host') {
        SocketAddress address = SocketAddress.fromMap(event.snapshot.value);
        if (event.snapshot.key != uid) {
          if (!event.snapshot.value.containsKey('allowed')) {
            bool result = await showPopup(event.snapshot.value['username']);
            if (result) {
//              debugPrint('${event.snapshot.key} $address');
              _addNode(address, event.snapshot.key,
                  event.snapshot.value['username']);
              _sendDummy(address);
              FirebaseDatabase.instance
                  .reference()
                  .child('rooms')
                  .child(_roomKey)
                  .child(event.snapshot.key)
                  .child('allowed')
                  .set(true);
            } else
              FirebaseDatabase.instance
                  .reference()
                  .child('rooms')
                  .child(_roomKey)
                  .child(event.snapshot.key)
                  .child('allowed')
                  .set(false);
          }
        }
      }
    });
    _sock1 = await RawDatagramSocket.bind(
        '0.0.0.0', _serverSocket.external.port,
        reuseAddress: true, ttl: 255);
    _sock2 = await RawDatagramSocket.bind(
        '0.0.0.0', _serverSocket.internal.port,
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
  }

  _setupListener() {
    _mySock.stream.listen((datagram) async {
      debugPrint("Message from client ${String.fromCharCodes(datagram.data)}");
      if (String.fromCharCodes(datagram.data) == "PING") {
        _sendDatagramBuffer('PONG>-1'.codeUnits, datagram);
      } else if (String.fromCharCodes(datagram.data).startsWith('PONG>')) {
        int numbering =
            int.parse(String.fromCharCodes(datagram.data).split('>')[1]);
        if (_deadBacklog.containsKey(numbering)) {
          _deadBacklog[numbering].forEach((node) {
            _sendDatagramBuffer(
                'NOT_DEAD>${allNodes[numbering].user.uid}'.codeUnits, node);
          });
          allNodes[numbering].downCount = 0;
          allNodes[numbering].state = true;
          _deadBacklog.remove(allNodes[numbering].user.uid);
          //todo: inform [uid] routing peers
        }
      } else if (String.fromCharCodes(datagram.data)
          .startsWith("ROUTING_TABLE>")) {
        String uid = String.fromCharCodes(datagram.data).split('>')[1];
        String tables = _generateRoutingTable(uid);
        _sendDatagramBuffer(tables.codeUnits, datagram);
      } else if (String.fromCharCodes(datagram.data).startsWith('GET_')) {
        int numbering =
            int.parse(String.fromCharCodes(datagram.data).split('>')[1]);
        if (String.fromCharCodes(datagram.data)
            .split('>')[0]
            .startsWith('GET_INCOMING'))
          _sendDatagramBuffer(
              'USER_INCOMING>${allNodes[numbering]}'.codeUnits, datagram);
        else
          _sendDatagramBuffer(
              'USER_OUTGOING>${allNodes[numbering]}'.codeUnits, datagram);
      } else if (String.fromCharCodes(datagram.data).startsWith('QUIT>')) {
        int numbering =
            int.parse(String.fromCharCodes(datagram.data).split('>')[1]);
        _generateRoutingTable(allNodes[numbering].user.uid,
            sendDeadStatus: true);
        _removeNode(numbering);
        notifyListeners();
      } else if (String.fromCharCodes(datagram.data).startsWith('DEAD>')) {
        String uid = String.fromCharCodes(datagram.data).split('>')[1];
        User user = _getUser(uid);
        debugPrint('$user');
        allNodes[user.numbering].state = false;
        _sendBuffer('PING'.codeUnits, allNodes[user.numbering].socket);
        _deadBacklog[uid] = [];
        _deadBacklog[uid].add(datagram);
        Timer.periodic(Duration(seconds: 30), (timer) {
          if (!allNodes[user.numbering].state) {
            _generateRoutingTable(user.uid, sendDeadStatus: true);
            _removeNode(user.numbering);
            _sendDatagramBuffer(
                'DEAD_$_lastNodeTillNow>$user'.codeUnits, datagram);
          }
          timer.cancel();
        });
      }
    });
  }

  void _sendDummy(SocketAddress dest) {
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
    if (_serverSocket.external.address == dest.external.address)
      _sock2.send(buffer, dest.internal.address, dest.internal.port);
    else
      _sock1.send(buffer, dest.external.address, dest.external.port);
  }

  int _getAvailableID(SocketAddress address) {
    // check if state is not true
    int id = 0;
    bool flag = false;
    if (allNodes.length > 0) id = allNodes.keys.toList().last + 1;
    allNodes.values.any((v) {
      // todo:  test equals
      if (v.socket == address) {
        id = v.user.numbering;
        flag = true;
        return true;
      }
      return false;
    });

    if (!flag)
      allNodes.values.any((v) {
        if (v.state == false) {
          id = v.user.numbering;
          return true;
        }
        return false;
      });
    return id;
  }

  _addNode(SocketAddress ip, String uid, String username) {
    int id = _getAvailableID(ip);
    /*
    * returns first available id from disconnected list
    * otherwise give a next new ID
    */
    User user = User(id, uid, username);
    Node node = Node(ip, user);
    allNodes[id] = node;
    notifyListeners();
    _lastNodeTillNow = allNodes.keys.last;
  }

  _generateRoutingTable(String uid, {sendDeadStatus: false}) {
    User user = _getUser(uid);
    // returns map [int: node] of outbound connections for this node
    List<Map<int, Node>> peers = _connect(user.numbering);
    //     123>192.168.0.100|0@uid;192.168.0.101|1@uid&&&&
    String code = 'ROUTING_TABLE_$_lastNodeTillNow>$user>';
    peers[0].forEach((k, v) {
      if (v.state == true) {
        code += v.toString();
        if (sendDeadStatus)
          _sendBuffer('DEAD_$_lastNodeTillNow>$user'.codeUnits, v.socket);
        else
          _sendBuffer(
              'UPDATE_OUTGOING_$_lastNodeTillNow>$v'.codeUnits, v.socket);
      }
    });
    code += '&&&&';
    peers[1].forEach((k, v) {
      if (v.state == true) {
        code += v.toString();
        if (sendDeadStatus)
          _sendBuffer('DEAD_$_lastNodeTillNow>$user'.codeUnits, v.socket);
        else
          _sendBuffer(
              'UPDATE_INCOMING_$_lastNodeTillNow>$v'.codeUnits, v.socket);
      }
    });
    // removes semicolon at end of code
    if (code[code.length - 1] == ';') return code.substring(0, code.length - 1);
    return code;
  }

  _removeNode(int id) {
    allNodes[id].state = false;
  }

////  ---------------------function to get uid from ip---------------------
//  User getUID({InternetAddress ip, String username}) {
//    if (ip != null) {
//      int uid;
//      allNodes.forEach((k, v) {
//        if (v.ip == ip) {
//          uid = v.user.numbering;
//          return;
//        }
//      });
//      return allNodes[uid].user;
//    } else {
//      int uid;
//      allNodes.forEach((k, v) {
//        if (v.user.username == username) {
//          uid = v.user.numbering;
//          return;
//        }
//      });
//      if (uid != null) return allNodes[uid].user;
//      return null;
//    }
//  }

  User _getUser(String uid) {
    User user;
    allNodes.values.any((v) {
      if (v.user.uid == uid) {
        user = v.user;
        return true;
      }
      return false;
    });
    return user;
  }

  List<Map<int, Node>> _connect(int uid) {
    Map<int, Node> outgoing = {};
    Map<int, Node> incoming = {};
    int distanceFromMe = 1;
    // cycle for outgoing
    int till = _lastNodeTillNow + 1;
    while (distanceFromMe + uid < till) {
      if (allNodes[uid + distanceFromMe].state == true)
        outgoing[distanceFromMe + uid] = allNodes[uid + distanceFromMe];
      distanceFromMe *= 2;
    }
    // outgoing cycle
    while ((distanceFromMe + uid) - till < uid) {
      if (allNodes[(uid + distanceFromMe) % till].state == true)
        outgoing[(distanceFromMe + uid) % till] =
            allNodes[(uid + distanceFromMe) % till];
      distanceFromMe *= 2;
    }
    distanceFromMe = 1;
    while (uid - distanceFromMe >= 0) {
      if (allNodes[uid - distanceFromMe].state == true)
        incoming[uid - distanceFromMe] = allNodes[uid - distanceFromMe];
      distanceFromMe *= 2;
    }
    // cycle for incoming
    while (till + uid - distanceFromMe > uid) {
      if (allNodes[uid - distanceFromMe + till].state == true)
        incoming[uid - distanceFromMe + till] =
            allNodes[uid - distanceFromMe + till];
      distanceFromMe *= 2;
    }
    return [incoming, outgoing];
  }

  closeServer() async {
    _sock1.close();
    _sock2.close();
    Fluttertoast.showToast(msg: 'Socket closed');
    notifyListeners();
    P2P.navKey.currentState.pop();
  }

  showPopup(String message) {
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
                      'Allow chat from $message?',
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
                          onPressed: () => P2P.navKey.currentState.pop(true),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: MaterialButton(
                          child: Text('Deny'),
                          color: Colors.red,
                          onPressed: () => P2P.navKey.currentState.pop(false),
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
