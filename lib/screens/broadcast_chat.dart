import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:peer2peer/services/client_service.dart';
import 'package:peer2peer/services/native_utils.dart';
import 'package:peer2peer/services/server_service.dart';
import 'package:provider/provider.dart';
import 'package:share/share.dart';

class BroadcastChat extends StatelessWidget {
  final bool _server;

  BroadcastChat(this._server);

  @override
  Widget build(BuildContext context) {
    final client = Provider.of<ClientService>(context, listen: false);
    globalClient = Provider.of<ClientService>(context, listen: false);
    return WillPopScope(
      onWillPop: () {
        client.sendQuitRequest();
        return Future(() => false);
      },
      child: Scaffold(
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
              onSelected: (item) {
                if (item == client.actions[0])
                  showDialog(
                    context: context,
                    builder: (context) => Dialog(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: <Widget>[
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text('My number'),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(client.me.numbering.toString()),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: <Widget>[
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text('My UID'),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Container(
                                      width:
                                          MediaQuery.of(context).size.width / 2,
                                      child: Text(client.me.uid),
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: <Widget>[
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text('My Username'),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(client.me.username.toString()),
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text('incoming table'),
                              ),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columns: [
                                    DataColumn(label: Text('Numbering')),
                                    DataColumn(label: Text('Username')),
                                    DataColumn(label: Text('Down count')),
                                    DataColumn(label: Text('UID')),
                                  ],
                                  rows: [
                                    for (var a in client.incomingNodes.entries)
                                      DataRow(
                                        cells: [
                                          DataCell(Text(a.key.toString())),
                                          DataCell(Text(a.value.user.username
                                              .toString())),
                                          DataCell(Text(
                                              a.value.downCount.toString())),
                                          DataCell(Text(
                                              a.value.user.uid.toString())),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text('outgoing table'),
                              ),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columns: [
                                    DataColumn(label: Text('Numbering')),
                                    DataColumn(label: Text('Username')),
                                    DataColumn(label: Text('Down count')),
                                    DataColumn(label: Text('UID')),
                                  ],
                                  rows: [
                                    for (var a in client.outgoingNodes.entries)
                                      DataRow(
                                        cells: [
                                          DataCell(Text(a.key.toString())),
                                          DataCell(Text(a.value.user.username
                                              .toString())),
                                          DataCell(Text(
                                              a.value.downCount.toString())),
                                          DataCell(Text(
                                              a.value.user.uid.toString())),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                else if (item == client.actions[1])
                  Share.share(
                      'https://peer2peer.page.link/${client.meetingId}');
                else
                  client.sendQuitRequest();
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
                            if (chat.sender.uid == value.me.uid)
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
                                              'by ${value.broadcastChat.values.toList()[index].sender.username}'),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(
                                              'at ${DateTime.fromMillisecondsSinceEpoch(chat.timestamp).hour}:${DateTime.fromMillisecondsSinceEpoch(chat.timestamp).minute}'),
                                        ),
                                      ],
                                      mainAxisAlignment: MainAxisAlignment.end,
                                    ),
                                  ],
                                  crossAxisAlignment:
                                      chat.sender.uid == value.me.uid
                                          ? CrossAxisAlignment.end
                                          : CrossAxisAlignment.start,
                                ),
                              ),
                              color: chat.sender.uid == value.me.uid
                                  ? Color(0xffFF928B)
                                  : Color(0xffffdbb5),
                            ),
                            if (chat.sender.uid != value.me.uid)
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
                    IconButton(
                      icon: Builder(builder: (c) {
                        final v =
                            c.select((ClientService value) => value.recording);
                        return Icon(
                          Icons.mic,
                          color: v ? Colors.red : Colors.green,
                        );
                      }),
                      onPressed: () => client.record(),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TextFormField(
                          focusNode: client.chatFocus,
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
      ),
    );
  }
}
