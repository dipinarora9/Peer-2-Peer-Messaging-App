import 'package:flutter/material.dart';
import 'package:peer2peer/screens/chat_screen.dart';
import 'package:peer2peer/services/client_service.dart';
import 'package:provider/provider.dart';

class ClientScreen extends StatelessWidget {
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
          return Text(value?.me?.username ?? '');
        }),
//        actions: <Widget>[
//          IconButton(
//            onPressed: () =>
//                ,
//            icon: Icon(
//              Icons.check,
//            ),
//          )
//        ],
      ),
      body: Center(
        child: Consumer<ClientService>(builder: (_, value, __) {
          return ListView.builder(
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(value.chats.keys.toList()[index].username ?? ''),
                subtitle: Text(value.chats.values
                        .toList()[index]
                        .chats
                        .values
                        .toList()
                        .last
                        .message ??
                    ''),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChangeNotifierProvider.value(
                        value: client,
                        child: ChatScreen(value.chats.keys.toList()[index]),
                      ),
                    ),
                  );
                },
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
    TextEditingController _message = TextEditingController();
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
                      controller: _message,
                      decoration: InputDecoration(labelText: 'Message'),
                    ),
                  ),
                OutlineButton(
                  child: Text('Send'),
                  color: Colors.blue,
                  onPressed: () async {
                    if (sendMessageRequest) {
                      client.createMessage(_message.text, _username.text);
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
