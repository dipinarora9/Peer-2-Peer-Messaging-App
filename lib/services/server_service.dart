import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:peer2peer/models/common_classes.dart';

import 'p2p.dart';

class ServerService with ChangeNotifier {
  Map<int, Node> allNodes = {};

  final ServerSocket _serverSocket;
  int _lastNodeTillNow;

  ServerService(this._serverSocket);

  int _getAvailableID(InternetAddress ip) {
    // check if state is not true
    int id = 0;
    bool flag = false;
    if (allNodes.length > 0) id = allNodes.keys.toList().last + 1;
    allNodes.values.any((v) {
      if (v.ip == ip) {
        id = v.user.uid;
        flag = true;
        return true;
      }
      return false;
    });

    if (!flag)
      allNodes.values.any((v) {
        if (v.state == false) {
          id = v.user.uid;
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
    // returns map [int: node] of outbound connections for this node---------------------
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
          uid = v.user.uid;
          return;
        }
      });
      return allNodes[uid].user;
    } else {
      int uid;
      allNodes.forEach((k, v) {
        if (v.user.username == username) {
          uid = v.user.uid;
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
