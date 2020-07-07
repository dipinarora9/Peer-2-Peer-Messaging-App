import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/cupertino.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:peer2peer/models/common_classes.dart';

import 'p2p.dart';

class ServerService with ChangeNotifier {
  Map<int, Node> allNodes = {};
  StreamController<Datagram> _mySock;
  final SocketAddress _serverSocket;
  int _lastNodeTillNow;
  final String _roomKey;

  ServerService(this._serverSocket, this._roomKey);

  listenToDatabaseChanges() async {
    RawDatagramSocket sock1 =
        await RawDatagramSocket.bind('0.0.0.0', _serverSocket.externalPort);
    RawDatagramSocket sock2 =
        await RawDatagramSocket.bind('0.0.0.0', _serverSocket.internalPort);
    sock1.listen((event) {
      if (event == RawSocketEvent.read) _mySock.add(sock1.receive());
    });
    sock2.listen((event) {
      if (event == RawSocketEvent.read) _mySock.add(sock1.receive());
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

  addServerListener() {
    _mySock.stream.listen((datagram) async {
      debugPrint("Message from client ${String.fromCharCodes(datagram.data)}");
      if (String.fromCharCodes(datagram.data) == "PING") {
        sock.add('PONG'.codeUnits);
      } else if (String.fromCharCodes(datagram.data)
          .startsWith("ROUTING_TABLE-")) {
        String tables = _serverService.addNode(sock.remoteAddress,
            String.fromCharCodes(datagram.data).substring(14));
        sock.add(tables.codeUnits);
        // send routing tables
      } else if (String.fromCharCodes(datagram.data) == "QUIT") {
        //--------------------- change state of that ip who quits------------
        InternetAddress ip = sock.remoteAddress;
        User user = _serverService.getUID(ip: ip);
        _serverService.removeNode(user.uid);
        notifyListeners();
      } else if (String.fromCharCodes(datagram.data).startsWith('DEAD-')) {
        //--------------------- change state of that ip to dead--------------
        InternetAddress ip =
            InternetAddress(String.fromCharCodes(datagram.data).substring(5));
        User user = _serverService.getUID(ip: ip);
        bool dead;
        try {
          Socket _clientSock = await Socket.connect(
              _serverService.allNodes[user.uid].ip, clientPort);
          dead = await ping(_clientSock, _serverService.allNodes[user.uid].ip);
          _clientSock.close();
        } on Exception {
          dead = true;
        }
        if (dead) {
          _serverService.removeNode(user.uid);
          sock.add('DEAD'.codeUnits);
        } else
          sock.add('NOT_DEAD'.codeUnits);
        notifyListeners();
      } else if (String.fromCharCodes(datagram.data)
          .startsWith('UID_FROM_IP-')) {
        //--------------------- get uid of given ip {'UID_FROM_IP-192.65.23.155}------
        InternetAddress ip =
            InternetAddress(String.fromCharCodes(datagram.data).substring(12));
        User user = _serverService.getUID(ip: ip);
        sock.add('$user'.codeUnits);
      } else if (String.fromCharCodes(data).startsWith('UID_FROM_USERNAME-')) {
        //--------------------- get uid of given ip {'UID_FROM_USERNAME-abc}------
        String username = String.fromCharCodes(datagram.data).substring(18);
        User user = _serverService.getUID(username: username);
        sock.add('$user'.codeUnits);
      } else if (String.fromCharCodes(datagram.data).startsWith('USERNAME-')) {
        //--------------------- get uid of given ip {'USERNAME-abc}------
        String result = _serverService
            .checkUsername(String.fromCharCodes(datagram.data).substring(9));
        sock.add(result.codeUnits);
      }
    });
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

  checkUsername(String username) {
    bool flag = true;
    allNodes.values.any((v) {
      if (v.user.username == username) {
        flag = false;
        return true;
      }
      return false;
    });
    if (flag)
      return 'ACCEPTED>$username';
    else
      return 'DENIED>$username';
  }

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
