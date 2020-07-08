import 'package:flutter/material.dart';
import 'package:peer2peer/models/common_classes.dart';
import 'package:peer2peer/services/client_service.dart';
import 'package:provider/provider.dart';

class PrivateChat extends StatelessWidget {
  final User user;

  PrivateChat(this.user);

  @override
  Widget build(BuildContext context) {
    final client = Provider.of<ClientService>(context, listen: false);
    return Scaffold(
      backgroundColor: Color(0xffCDEAC0),
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
                    controller: client.chatController,
                    itemBuilder: (context, index) {
                      final chat = value.chats[user.toString()].chats.values
                          .toList()[index];
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
                                    child: Text(chat.message ?? ''),
                                  ),
                                  Row(
                                    children: <Widget>[
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                            '${DateTime.fromMillisecondsSinceEpoch(chat.timestamp).hour}:${DateTime.fromMillisecondsSinceEpoch(chat.timestamp).minute}'),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Icon(chat.status ==
                                                MessageStatus.SENDING
                                            ? Icons.access_time
                                            : chat.status == MessageStatus.SENT
                                                ? Icons.check
                                                : Icons.close),
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
                    itemCount: value.chats[user.toString()].chats.length,
                  );
                },
              ),
            ),
            Consumer<ClientService>(builder: (_, value, __) {
              return value.chats[user.toString()].allowed
                  ? Container(
                      color: Color(0xffAECFDF).withOpacity(0.8),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: TextFormField(
                                controller: value.chatBox,
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
                            onPressed: () =>
                                client.createMessage(user.username),
                          ),
                        ],
                      ),
                    )
                  : Padding(
                      padding: EdgeInsets.all(20),
                      child:
                          Text('Waiting for acceptance from the other user...'),
                    );
            }),
          ],
        ),
      ),
    );
  }
}
