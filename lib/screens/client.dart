import 'package:flutter/material.dart';
import 'package:peer2peer/services/client_service.dart';
import 'package:provider/provider.dart';

class ClientScreen extends StatelessWidget {
  final TextEditingController _uid = TextEditingController();
  final TextEditingController _message = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final p2p = Provider.of<ClientService>(context, listen: false);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            TextFormField(
              controller: _uid,
              decoration: InputDecoration(labelText: ''),
            ),
            TextFormField(
              controller: _message,
            ),
            RaisedButton(
              onPressed: () =>
                  p2p.createMessage(_message.text, int.parse(_uid.text)),
              child: Text('Send Message'),
            ),
            Consumer<ClientService>(
              builder: (_, value, __) {
                return Text(value.text);
              },
            ),
          ],
        ),
      ),
    );
  }
}
