import 'package:flutter/material.dart';
import 'package:peer2peer/services/client_service.dart';
import 'package:peer2peer/services/server_service.dart';
import 'package:provider/provider.dart';
import 'package:share/share.dart';

class BroadcastChat extends StatelessWidget {
  final bool _server;
  BroadcastChat(this._server);

  @override
  Widget build(BuildContext context) {
    final client = Provider.of<ClientService>(context, listen: false);
    return Scaffold(
      key: _server
          ? Provider.of<ServerService>(context, listen: false).scaffoldKey
          : null,
      backgroundColor: Color(0xffCDEAC0),
      appBar: AppBar(
        title: Text('Meeting id - ${client.meetingId}'),
        actions: <Widget>[
          PopupMenuButton<String>(
            itemBuilder: (context) {
              return client.actions
                  .map(
                    (action) => PopupMenuItem(
                      child: Text(action),
                      value: action,
                    ),
                  )
                  .toList();
            },
            onSelected: (item) async {
              if (item == client.actions[0]) {
                Share.share('https://peer2peer.page.link/${client.meetingId}');
              }
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: Consumer<ClientService>(
                builder: (_, value, __) {
                  return ListView.builder(
                    controller: client.chatController,
                    itemBuilder: (context, index) {
                      final chat = value.broadcastChat.values.toList()[index];
                      return Row(
                        children: <Widget>[
                          if (chat.sender.username == value.me.username)
                            SizedBox(
                              width: MediaQuery.of(context).size.width -
                                  MediaQuery.of(context).size.width / 1.1,
                            ),
                          Card(
                            child: Container(
                              width: MediaQuery.of(context).size.width / 1.3,
                              child: Column(
                                children: <Widget>[
                                  Padding(
                                    padding: const EdgeInsets.all(15.0)
                                        .copyWith(bottom: 0),
                                    child: Text(value.broadcastChat.values
                                            .toList()[index]
                                            .message ??
                                        ''),
                                  ),
                                  Row(
                                    children: <Widget>[
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                            '${DateTime.fromMillisecondsSinceEpoch(chat.timestamp).hour}:${DateTime.fromMillisecondsSinceEpoch(chat.timestamp).minute}'),
                                      ),
                                    ],
                                    mainAxisAlignment: MainAxisAlignment.end,
                                  ),
                                ],
                                crossAxisAlignment:
                                    chat.sender.username == value.me.username
                                        ? CrossAxisAlignment.end
                                        : CrossAxisAlignment.start,
                              ),
                            ),
                            color: chat.sender.username == value.me.username
                                ? Color(0xffFF928B)
                                : Color(0xffffdbb5),
                          ),
                          if (chat.sender.username != value.me.username)
                            SizedBox(
                              width: MediaQuery.of(context).size.width -
                                  MediaQuery.of(context).size.width / 1.1,
                            ),
                        ],
                      );
                    },
                    shrinkWrap: true,
                    itemCount: value.broadcastChat.length,
                  );
                },
              ),
            ),
            Container(
              color: Color(0xffAECFDF).withOpacity(0.8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextFormField(
                        controller: client.chatBox,
                        decoration: InputDecoration(
                            labelText: 'Type your message here'),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.send,
                      color: Colors.blue..withOpacity(0.8),
                    ),
                    onPressed: () => client.createBroadcastMessage(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
