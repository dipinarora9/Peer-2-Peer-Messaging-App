import 'package:flutter/material.dart';
import 'package:peer2peer/screens/homepage.dart';
import 'package:provider/provider.dart';

import 'services/p2p.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => P2P(),
      child: MaterialApp(
        title: 'P2P',
        theme: ThemeData(
          primaryColor: Color(0xff465775),
        ),
        navigatorKey: P2P.navKey,
        home: HomePage(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

/// Server :
///
/// 1. unique url generate + generate record sheet against that id (dipin)
/// 2. server incoming + outgoing routing tables send (for punching) (kaneki)
/// 3. host needs to be updated
/// 4. each peer should have two connections - one with server just for regularly updating its routing table..
/// other connections will be with 19 other peers.
/// 5. connection to the server will have two types...
/// i) Peer connection
/// ii) Server connection
///
/// Client:
///
/// 1. Send dummy messages to incoming.
/// 2. Send actual message to outgoing.
/// 3. Create a separate connection with the server to update routing tables.

/*
* Creation of meeting
*
* Register user on firebase
*
* Server port
* Client port
*
* database ->  create new unique room and add host details
* generate url -> containing uuid of room and host details
*
* join room -> members will add their details in db and setup connection with the host at server port

* Server  (uid) -> routing
* client ()-> routing table
*/
