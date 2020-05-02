import 'package:flutter/material.dart';
import 'package:peer2peer/models/common_classes.dart';
import 'package:peer2peer/services/client_service.dart';
import 'package:provider/provider.dart';

class ChatScreen extends StatelessWidget {
  final User user;
  final TextEditingController _c = TextEditingController();

  ChatScreen(this.user);

  @override
  Widget build(BuildContext context) {
    final client = Provider.of<ClientService>(context, listen: false);
    return Scaffold(
      appBar: AppBar(
        title: Text(user.username),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: Consumer<ClientService>(
                builder: (_, value, __) {
                  return ListView.builder(
                    itemBuilder: (context, index) {
                      final chat = value.chats[user.toString()].chats.values
                          .toList()[index];
                      return ListTile(
                        title: Text(chat.message ?? ''),
                        subtitle: Text(
                            DateTime.fromMillisecondsSinceEpoch(chat.timestamp)
                                .toIso8601String()),
                        trailing: Icon(chat.status == MessageStatus.SENDING
                            ? Icons.access_time
                            : chat.status == MessageStatus.SENT
                                ? Icons.check
                                : Icons.close),
                      );
                    },
                    shrinkWrap: true,
                    itemCount: value.chats[user.toString()].chats.length,
                  );
                },
              ),
            ),
            Consumer<ClientService>(builder: (_, value, __) {
              return value.chats[user.toString()].allowed
                  ? Row(
                      children: <Widget>[
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: TextFormField(
                              controller: _c,
                              decoration: InputDecoration(
                                  labelText: 'Type your message here.'),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.send),
                          onPressed: () =>
                              client.createMessage(_c.text, user.username),
                        ),
                      ],
                    )
                  : Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                          'Waiting for acceptance from the other user...'));
            }),
          ],
        ),
      ),
    );
  }
}
