import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/cupertino.dart';
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

  listenToDatabaseChanges() async {
    _sock1 =
        await RawDatagramSocket.bind('0.0.0.0', _serverSocket.external.port);
    _sock2 =
        await RawDatagramSocket.bind('0.0.0.0', _serverSocket.internal.port);
    _sock1.listen((event) {
      if (event == RawSocketEvent.read)
        _mySock.add(MyDatagram(_sock1.receive(), _sock1.port));
    });
    _sock2.listen((event) {
      if (event == RawSocketEvent.read)
        _mySock.add(MyDatagram(_sock2.receive(), _sock2.port));
    });
    FirebaseDatabase.instance
        .reference()
        .child('rooms')
        .child(_roomKey)
        .onChildAdded
        .listen((event) async {
      SocketAddress address = SocketAddress.fromMap(event.snapshot.value);
      bool result = await showPopup(event.snapshot.value['username']);
      if (result) {
        addNode(address, event.snapshot.key, event.snapshot.value['username']);
        //todo: punching hole
      }
    });
  }

  addServerListener() {
    _mySock.stream.listen((datagram) async {
      debugPrint("Message from client ${String.fromCharCodes(datagram.data)}");
      if (String.fromCharCodes(datagram.data) == "PING") {
        sendDatagramBuffer('PONG>HOST'.codeUnits, datagram);
      } else if (String.fromCharCodes(datagram.data).startsWith('PONG>')) {
        String uid = String.fromCharCodes(datagram.data).split('>')[1];
        if (_deadBacklog.containsKey(uid)) {
          _deadBacklog[uid].forEach((node) {
            sendDatagramBuffer('NOT_DEAD>$uid'.codeUnits, node);
          });
          allNodes[uid].downCount = 0;
          allNodes[uid].state = true;
          _deadBacklog.remove(uid);
          //todo: inform [uid] routing peers
        }
      } else if (String.fromCharCodes(datagram.data)
          .startsWith("ROUTING_TABLE>")) {
        String uid = String.fromCharCodes(datagram.data).split('>')[1];
        String tables = generateRoutingTable(uid);
        sendDatagramBuffer(tables.codeUnits, datagram);
      } else if (String.fromCharCodes(datagram.data).startsWith('QUIT>')) {
        int numbering =
            int.parse(String.fromCharCodes(datagram.data).split('>')[1]);
        removeNode(numbering);
        notifyListeners();
      } else if (String.fromCharCodes(datagram.data).startsWith('DEAD>')) {
        String uid = String.fromCharCodes(datagram.data).split('>')[1];
        int numbering = _getNumbering(uid);
        allNodes[numbering].state = false;
        sendBuffer('PING'.codeUnits, allNodes[numbering].socket);
        _deadBacklog[uid].add(datagram);
        Timer.periodic(Duration(seconds: 1), (timer) {
          if (!allNodes[numbering].state) {
            removeNode(numbering);
            sendDatagramBuffer('DEAD>$uid'.codeUnits, datagram);
            notifyListeners();
          }
          timer.cancel();
        });

//      } else if (String.fromCharCodes(datagram.data)
//          .startsWith('UID_FROM_IP-')) {
//        //--------------------- get uid of given ip {'UID_FROM_IP-192.65.23.155}------
//        InternetAddress ip =
//            InternetAddress(String.fromCharCodes(datagram.data).substring(12));
//        User user = getUID(ip: ip);
//        sendDatagramBuffer('$user'.codeUnits, datagram);
//      } else if (String.fromCharCodes(datagram.data)
//          .startsWith('UID_FROM_USERNAME-')) {
//        //--------------------- get uid of given ip {'UID_FROM_USERNAME-abc}------
//        String username = String.fromCharCodes(datagram.data).substring(18);
//        User user = getUID(username: username);
//        sendDatagramBuffer('$user'.codeUnits, datagram);
//      } else if (String.fromCharCodes(datagram.data).startsWith('USERNAME-')) {
//        //--------------------- get uid of given ip {'USERNAME-abc}------
//        String result =
//            checkUsername(String.fromCharCodes(datagram.data).substring(9));
//        sendDatagramBuffer(result.codeUnits, datagram);
//      }
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
    if (_serverSocket.external == dest.external)
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

  addNode(SocketAddress ip, String uid, String username) {
    int id = _getAvailableID(ip); // to be done
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

  generateRoutingTable(String uid) {
    int number = _getNumbering(uid);
    // returns map [int: node] of outbound connections for this node
    List<Map<int, Node>> peers = _connect(number);
    //     123>192.168.0.100|0@uid;192.168.0.101|1@uid&&&&
    String code = '$number>';
    peers[0].forEach((k, v) {
      if (v.state == true) code += v.toString();
    });
    code += '&&&&';
    peers[1].forEach((k, v) {
      if (v.state == true) code += v.toString();
    });
    // removes semicolon at end of code
    return code.substring(0, code.length - 1);
  }

  removeNode(int id) {
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

  int _getNumbering(String uid) {
    int numbering;
    allNodes.values.any((v) {
      if (v.user.uid == uid) {
        numbering = v.user.numbering;
        return true;
      }
      return false;
    });
    return numbering;
  }

  List<Map<int, Node>> _connect(int uid) {
    Map<int, Node> outgoing = {};
    Map<int, Node> incoming = {};
    int distanceFromMe = 1;
    // cycle for outgoing
    int till = _lastNodeTillNow + 1;
    while (distanceFromMe + uid <= till) {
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
                          onPressed: () => P2P.navKey.currentState.pop(true),
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
