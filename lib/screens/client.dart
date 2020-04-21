import 'package:flutter/material.dart';
import 'package:peer2peer/services/p2p.dart';
import 'package:provider/provider.dart';

class ClientScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p2p = Provider.of<P2P>(context, listen: false);
    return Scaffold(
      body: Center(
        child: Text('Server address - ${p2p.serverAddress}'),
      ),
    );
  }
}
