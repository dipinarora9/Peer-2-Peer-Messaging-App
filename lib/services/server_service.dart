import 'dart:io';
import 'dart:math';

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

  generateRoutingTables(Map<int, List<int>> feed) {
    // assume myID is given
    int myID = 0, p = 1, x = 1;
    for (int i = myID + p; i < feed.length; p *= 2) {
//      if (i == myID) continue;
      if (allNodes[i].state == true) {
        int itemToBeSent = max(0, myID - x);
        for (int j = myID; j > itemToBeSent; --j) {
          // send feed[j] to ith node
          send(i, feed[j]);
        }
        ++x;
      }
    }
  }

  closeServer() async {
    await _serverSocket.close();
    Fluttertoast.showToast(msg: 'Socket closed');
    notifyListeners();
    P2P.navKey.currentState.pop();
  }
}
