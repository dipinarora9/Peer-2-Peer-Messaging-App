import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:peer2peer/models/common_classes.dart';

sender(RawDatagramSocket sock, IpAddress ip) async {
  sock.send('PING'.codeUnits, ip.address, ip.port);
  debugPrint('message sent');
}

sendEmpty(RawDatagramSocket sock, IpAddress ip) async {
  sock.send([], ip.address, ip.port);
  sock.send([], ip.address, ip.port);
  sock.send([], ip.address, ip.port);
  sock.send([], ip.address, ip.port);
  debugPrint('trying to punch hole');
  sock.close();
}
