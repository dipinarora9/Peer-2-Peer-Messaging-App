import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:peer2peer/screens/homepage.dart';
import 'package:provider/provider.dart';

import 'services/p2p.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => P2P()
        ..setUpConfig()
        ..joinMeetingViaUrl(),
      child: MaterialApp(
        title: 'P2P',
        theme: ThemeData(
          primaryColor: Color(0xff465775),
        ),
        navigatorKey: P2P.navKey,
        home: HomePage(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
