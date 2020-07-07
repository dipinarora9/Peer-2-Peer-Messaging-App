import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/cupertino.dart';
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

  ServerService(this._serverSocket, this._roomKey);

  listenToDatabaseChanges() async {
    _sock1 =
        await RawDatagramSocket.bind('0.0.0.0', _serverSocket.external.port);
    _sock2 =
        await RawDatagramSocket.bind('0.0.0.0', _serverSocket.internal.port);
    _sock1.listen((event) {
      if (event == RawSocketEvent.read) _mySock.add(_sock1.receive());
    });
    _sock2.listen((event) {
      if (event == RawSocketEvent.read) _mySock.add(_sock1.receive());
    });
    FirebaseDatabase.instance
        .reference()
        .child('rooms')
        .child(_roomKey)
        .onChildAdded
        .listen((event) {
      //todo: add in allnodes of server service
      SocketAddress.fromMap(event.snapshot.value);
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

  addServerListener() {
    _mySock.stream.listen((datagram) async {
      debugPrint("Message from client ${String.fromCharCodes(datagram.data)}");
      if (String.fromCharCodes(datagram.data) == "PING") {
        sendDatagramBuffer('PONG'.codeUnits, datagram);
      } else if (String.fromCharCodes(datagram.data)
          .startsWith("ROUTING_TABLE-")) {
        String tables = addNode(datagram.address,
            String.fromCharCodes(datagram.data).substring(14));
        sendDatagramBuffer(tables.codeUnits, datagram);
        // send routing tables
      } else if (String.fromCharCodes(datagram.data) == "QUIT") {
        //--------------------- change state of that ip who quits------------
        InternetAddress ip = datagram.address;
        User user = getUID(ip: ip);
        removeNode(user.numbering);
        notifyListeners();
      } else if (String.fromCharCodes(datagram.data).startsWith('DEAD-')) {
        //--------------------- change state of that ip to dead--------------
        InternetAddress ip =
            InternetAddress(String.fromCharCodes(datagram.data).substring(5));
        User user = getUID(ip: ip);
        bool dead;
        try {
          Socket _clientSock =
              await Socket.connect(allNodes[user.uid].ip, clientPort);
          dead = await ping(_clientSock, allNodes[user.uid].ip);
          _clientSock.close();
        } on Exception {
          dead = true;
        }
        if (dead) {
          removeNode(user.numbering);
          sendDatagramBuffer('DEAD'.codeUnits, datagram);
        } else
          sendDatagramBuffer('NOT_DEAD'.codeUnits, datagram);
        notifyListeners();
      }
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

  int _getAvailableID(InternetAddress ip) {
    // check if state is not true
    int id = 0;
    bool flag = false;
    if (allNodes.length > 0) id = allNodes.keys.toList().last + 1;
    allNodes.values.any((v) {
      if (v.ip == ip) {
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

  String addNode(InternetAddress ip, String username) {
    int id = _getAvailableID(ip); // to be done
    /*
    * returns first available id from disconnected list
    * otherwise give a next new ID
    */
    User user = User(id, username);
    Node node = Node(ip, user);
    allNodes[id] = node;
    notifyListeners();
    _lastNodeTillNow = allNodes.keys.last;
    // returns map [int: node] of outbound connections for this node
    Map<int, Node> peers = _connect(id);
    //     123@username>192.168.0.100|0@username;192.168.0.101|1@username2
    String code = '$id@$username>';
    peers.forEach((k, v) {
      if (v.state == true) code += v.toString();
    });
    // removes semicolon at end of code
    return code.substring(0, code.length - 1);
  }

  removeNode(int id) {
    // updating state of this node as dead {false}---------------------
    allNodes[id].state = false;
  }

//  ---------------------function to get uid from ip---------------------
  User getUID({InternetAddress ip, String username}) {
    if (ip != null) {
      int uid;
      allNodes.forEach((k, v) {
        if (v.ip == ip) {
          uid = v.user.numbering;
          return;
        }
      });
      return allNodes[uid].user;
    } else {
      int uid;
      allNodes.forEach((k, v) {
        if (v.user.username == username) {
          uid = v.user.numbering;
          return;
        }
      });
      if (uid != null) return allNodes[uid].user;
      return null;
    }
  }

//  checkUsername(String username) {
//    bool flag = true;
//    allNodes.values.any((v) {
//      if (v.user.username == username) {
//        flag = false;
//        return true;
//      }
//      return false;
//    });
//    if (flag)
//      return 'ACCEPTED>$username';
//    else
//      return 'DENIED>$username';
//  }

  Map<int, Node> _connect(int uid) {
    Map<int, Node> mp = {};
    int distanceFromMe = 1;
    // for connecting 255 nodes only
    // cycle for outgoing
    int till = (_lastNodeTillNow + 1);
    while (distanceFromMe + uid <= till) {
      if (allNodes[uid + distanceFromMe].state == true)
        mp[distanceFromMe + uid] =
            allNodes[uid + distanceFromMe]; // assuming always present
      distanceFromMe *= 2;
    }
    // outgoing cycle
    while ((distanceFromMe + uid) % till < uid) {
      if (allNodes[(uid + distanceFromMe) % till].state == true)
        mp[(distanceFromMe + uid) % till] =
            allNodes[(uid + distanceFromMe) % till]; // assuming always present
      distanceFromMe *= 2;
    }
    distanceFromMe = 1;
    while (uid - distanceFromMe >= 0) {
      if (allNodes[uid - distanceFromMe].state == true)
        mp[uid - distanceFromMe] =
            allNodes[uid - distanceFromMe]; // assuming always present
      distanceFromMe *= 2;
    }
    // cycle for incoming
    while (till + uid - distanceFromMe > uid) {
      if (allNodes[uid - distanceFromMe + till].state == true)
        mp[uid - distanceFromMe + till] =
            allNodes[uid - distanceFromMe + till]; // assuming always present
      distanceFromMe *= 2;
    }
    return mp;
  }

// calculates incoming and outgoing nodes of newNode
  smartNode(int myId, int lastNode) {
    var outgoingNodes = [];
    var incomingNodes = [];
    int distance = 1, till = lastNode + 1;
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

// adds and delete incoming outgoing nodes when encounters new node in connection
  updateRoutingTable(int myId, int newNodeId) {
    double difference = log(newNodeId - myId) / log(e);
    if (difference != (newNodeId - myId as double)) return;
    // traverse in all connection
    // discard
  }

  send(int node, List<int> feed) {
    // convert to msg and forward to node
  }

  closeServer() async {
    await _serverSocket.close();
    Fluttertoast.showToast(msg: 'Socket closed');
    notifyListeners();
    P2P.navKey.currentState.pop();
  }
}
