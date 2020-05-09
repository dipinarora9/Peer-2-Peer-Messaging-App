import 'package:flutter/material.dart';
import 'package:peer2peer/models/common_classes.dart';
import 'package:peer2peer/services/client_service.dart';
import 'package:provider/provider.dart';

class AllChatsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final client = Provider.of<ClientService>(context, listen: false);
    if (client.me == null)
      WidgetsBinding.instance.addPostFrameCallback((a) {
        Dialogs().showPopup(context, client, sendMessageRequest: false);
      });
    return Scaffold(
      key: client.scaffoldKey,
      appBar: AppBar(
        title: Consumer<ClientService>(builder: (_, value, __) {
          return Text("Chats of ${value?.me?.username}" ?? '');
        }),
        actions: <Widget>[
          IconButton(
            onPressed: client.deleteChats,
            icon: Icon(
              Icons.delete,
            ),
          )
        ],
      ),
      drawer: Drawer(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ListTile(
                  title: Text('Quit network'),
                  onTap: () => client.sendQuitRequest(),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Center(
        child: Consumer<ClientService>(builder: (_, value, __) {
          return ListView.builder(
            itemBuilder: (context, index) {
              final User user =
                  User.fromString(value.chats.keys.toList()[index]);
              return ListTile(
                title: Text(user.username ?? ''),
                subtitle: Text(value.chats.values
                        .toList()[index]
                        .chats
                        .values
                        .toList()
                        .last
                        .message ??
                    ''),
                onTap: () => client.openChat(user),
              );
            },
            itemCount: value.chats.length,
          );
        }),
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () => Dialogs().showPopup(context, client),
      ),
    );
  }
}

class Dialogs {
  showPopup(BuildContext context, ClientService client,
      {bool sendMessageRequest: true}) {
    TextEditingController _username = TextEditingController();
    return showDialog(
      context: context,
      barrierDismissible: sendMessageRequest ? true : false,
      builder: (context) {
        return Dialog(
          child: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: _username,
                    decoration: InputDecoration(labelText: 'Username'),
                  ),
                ),
                if (sendMessageRequest)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      controller: client.chatBox,
                      decoration: InputDecoration(labelText: 'Message'),
                    ),
                  ),
                MaterialButton(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text('Send'),
                  ),
                  color: Colors.blue,
                  onPressed: () async {
                    if (sendMessageRequest) {
                      await client.startNewChat(_username.text);
                      Navigator.of(context).pop();
                    } else {
                      bool result =
                          await client.requestUsername(_username.text);
                      if (result) Navigator.of(context).pop();
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
