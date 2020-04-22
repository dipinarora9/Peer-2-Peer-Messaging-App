import 'dart:io';

import 'package:peer2peer/models/node.dart';

class ServerService {
  static Map<int, Node> allNodes;

  /*
  * key: uid
  * value: Node (class)
  */
  int _lastNodeTillNow;

  int getAvailableID() {
    // check if state is not true

    return 0;
  }

  addNode(InternetAddress ip) {
    int id = getAvailableID(); // to be done
    /*
    * returns first available id from disconnected list
    * otherwise give a next new ID
    */
    Node node = Node(id, ip, true);
    allNodes[id] = node;
    _lastNodeTillNow = allNodes.keys.last;
  }

  removeNode(int id){


    allNodes[id].state=false;
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
}
