import 'package:peer2peer/services/p2p.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ServerScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p2p = Provider.of<P2P>(context, listen: false);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: RaisedButton(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text('Close Server'),
            ),
            elevation: 20,
            color: Color(0xffEF6F6C),
            onPressed: p2p.closeServer,
          ),
        ),
      ),
    );
  }
}
