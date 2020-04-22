import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:peer2peer/models/common_classes.dart';

import 'p2p.dart';

class ServerService with ChangeNotifier {
  static Map<int, Node> allNodes;

  final ServerSocket _serverSocket;
  int _lastNodeTillNow;

  ServerService(this._serverSocket);

  int getAvailableID() {
    // check if state is not true
    int id = allNodes.keys.last + 1;
    allNodes.values.any((v) {
      if (v.state == false) {
        id = v.id;
        return true;
      }
      return false;
    });
    return id;
  }

  Uint8List addNode(InternetAddress ip) {
    int id = getAvailableID(); // to be done
    /*
    * returns first available id from disconnected list
    * otherwise give a next new ID
    */
    Node node = Node(id, ip);
    allNodes[id] = node;
    _lastNodeTillNow = allNodes.keys.last;
    // returns map [int: node] of outbound connections for this node---------------------
    Map<int, Node> peers = connect(id);
    //     123>0|192.168.0.100|1;1|192.168.0.101|1
    String code = '$id>';
    peers.forEach((k, v) {
      if (v.state == true) code += v.toString();
    });
    // removes semicolon at end of code
    code = code.substring(0, code.length - 1);
    return code.codeUnits;
  }

  removeNode(int id) {
    // updating state of this node as dead {false}---------------------
    allNodes[id].state = false;
  }

//  ---------------------function to get uid from ip---------------------
  int getUID(InternetAddress ip) {
    int uid;
    allNodes.forEach((k, v) {
      if (v.ip == ip) {
        uid = v.id;
        return;
      }
    });
    return uid;
  }

  Map<int, Node> connect(int uid) {
    Map<int, Node> mp;
    int distanceFromMe = 1;
    // for connecting 255 nodes only
    while (distanceFromMe + uid <= _lastNodeTillNow) {
      if (allNodes[uid + distanceFromMe].state == true)
        mp[distanceFromMe + uid] =
            allNodes[uid + distanceFromMe]; // assuming always present
      distanceFromMe *= 2;
    }
    distanceFromMe = 1;
    while (uid - distanceFromMe >= 0) {
      if (allNodes[uid - distanceFromMe].state == true)
        mp[distanceFromMe - uid] =
            allNodes[uid - distanceFromMe]; // assuming always present
      distanceFromMe *= 2;
    }
    return mp;
  }

  closeServer() async {
    await _serverSocket.close();
    Fluttertoast.showToast(msg: 'Socket closed');
    notifyListeners();
    P2P.navKey.currentState.pop();
  }
}
