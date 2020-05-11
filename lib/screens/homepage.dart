import 'package:flutter/material.dart';
import 'package:peer2peer/services/p2p.dart';
import 'package:provider/provider.dart';

class HomePage extends StatelessWidget {
  final TextEditingController _ip = TextEditingController();

  final TextEditingController a = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final p2p = Provider.of<P2P>(context, listen: false);
    return Scaffold(
      appBar: AppBar(
        title: Text('P2P Implementation'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Consumer<P2P>(builder: (_, value, __) {
            if (!value.searching)
              return Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextFormField(
                      controller: a,
                      decoration: InputDecoration(labelText: 'from'),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextFormField(
                      controller: _ip,
                      decoration: InputDecoration(
                          labelText:
                              'Subnet Mask (192.168.0.), start port(100), end port(255)'),
                    ),
                  ),
//                  Padding(
//                    padding: const EdgeInsets.all(8.0),
//                    child: RaisedButton(
//                      child: Padding(
//                        padding: const EdgeInsets.all(8.0),
//                        child: Text(
//                          'Initialize Network',
//                          textScaleFactor: 1.1,
//                        ),
//                      ),
//                      elevation: 20,
//                      onPressed: () => p2p.initializer(ip: _ip.text),
//                      color: Color(0xff59C9A5),
//                    ),
//                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: RaisedButton(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          'Initialize',
                          textScaleFactor: 1.1,
                        ),
                      ),
                      elevation: 20,
                      onPressed: () =>
                          p2p.testingNatHolePunching(a.text, _ip.text),
                      color: Color(0xff59C9A5),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: RaisedButton(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          'Send dummmy without NAT',
                          textScaleFactor: 1.1,
                        ),
                      ),
                      elevation: 20,
                      onPressed: () => p2p.sendEmpty(false),
                      color: Color(0xff59C9A5),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: RaisedButton(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          'Send dummmy with NAT',
                          textScaleFactor: 1.1,
                        ),
                      ),
                      elevation: 20,
                      onPressed: () => p2p.sendEmpty(true),
                      color: Color(0xff59C9A5),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: RaisedButton(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          'Send original message without nat',
                          textScaleFactor: 1.1,
                        ),
                      ),
                      elevation: 20,
                      onPressed: () => p2p.sender(false),
                      color: Color(0xff59C9A5),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: RaisedButton(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          'Send original message with nat',
                          textScaleFactor: 1.1,
                        ),
                      ),
                      elevation: 20,
                      onPressed: () => p2p.sender(true),
                      color: Color(0xff59C9A5),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: RaisedButton(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          'Receiver',
                          textScaleFactor: 1.1,
                        ),
                      ),
                      elevation: 20,
                      onPressed: () => p2p.receiver(),
                      color: Color(0xff59C9A5),
                    ),
                  ),
                  Consumer<P2P>(
                    builder: (_, value, __) => Text(value.te),
                  )
                ],
              );
            return CircularProgressIndicator();
          }),
        ),
      ),
    );
  }
}
