import 'package:flutter/material.dart';
import 'package:peer2peer/services/server_service.dart';
import 'package:provider/provider.dart';

class ServerScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p2p = Provider.of<ServerService>(context, listen: false);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Consumer<ServerService>(builder: (_, value, __) {
              return ListView.builder(
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(value.allNodes.keys.toList()[index].toString()),
                    trailing: Icon(value.allNodes.values.toList()[index].state
                        ? Icons.check
                        : Icons.not_interested),
                  );
                },
                itemCount: value.allNodes.length,
                shrinkWrap: true,
              );
            }),
            Padding(
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
          ],
        ),
      ),
    );
  }
}
