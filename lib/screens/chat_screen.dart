import 'package:flutter/material.dart';
import 'package:peer2peer/models/common_classes.dart';
import 'package:peer2peer/services/client_service.dart';
import 'package:provider/provider.dart';

class ChatScreen extends StatelessWidget {
  final User user;

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
                      return Container(
                        alignment: chat.sender.username != client.me.username
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        width: MediaQuery.of(context).size.width / 2,
                        child: ListTile(
                          title: Text(chat.message ?? ''),
                          subtitle: Text(
                              'at ${DateTime.fromMillisecondsSinceEpoch(chat.timestamp).toIso8601String()} by ${chat.sender.username}'),
                          trailing: Icon(chat.status == MessageStatus.SENDING
                              ? Icons.access_time
                              : chat.status == MessageStatus.SENT
                                  ? Icons.check
                                  : Icons.close),
                        ),
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
                              controller: value.chatBox,
                              decoration: InputDecoration(
                                  labelText: 'Type your message here.'),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.send),
                          onPressed: () => client.createMessage(user.username),
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
