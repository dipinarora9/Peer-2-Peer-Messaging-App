import 'package:flutter/material.dart';
import 'package:peer2peer/services/p2p.dart';
import 'package:provider/provider.dart';

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p2p = Provider.of<P2P>(context, listen: false);
    return Scaffold(
      appBar: AppBar(
        title: Text('P2P Implementation'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextFormField(
                  controller: p2p.name,
                  decoration: InputDecoration(labelText: 'Name'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: RaisedButton(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Create meeting',
                      textScaleFactor: 1.1,
                    ),
                  ),
                  elevation: 20,
                  onPressed: () => p2p.createMeeting(),
                  color: Color(0xff59C9A5),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextFormField(
                  controller: p2p.meetingId,
                  decoration: InputDecoration(labelText: 'Meeting id'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: RaisedButton(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Create meeting',
                      textScaleFactor: 1.1,
                    ),
                  ),
                  elevation: 20,
                  onPressed: () => p2p.joinMeeting(),
                  color: Color(0xff59C9A5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
