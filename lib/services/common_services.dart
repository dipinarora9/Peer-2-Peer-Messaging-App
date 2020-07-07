import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:peer2peer/models/common_classes.dart';

sendDiff(RawDatagramSocket sock, SocketAddress device_in, SocketAddress device_out) {
  var dest_ip = device_out.external.address;
  var dest_port = device_out.external.port;
  var nat_port = device_in.external.port;
  var s_ip = device_in.external.address;
  var s_port = device_in.external.port;

  // server.sendto(f"{dest_ip}:{dest_port}-{nat_port}".encode(), (s_ip, s_port))
  var send = "$dest_ip:$dest_port--$nat_port".codeUnits;
}

sendSame(RawDatagramSocket sock, SocketAddress device_in, SocketAddress device_out) {
  var dest_ip = device_out.internal.address;
  var dest_port = device_out.internal.port;
  var nat_port = device_in.internal.port;
  var s_ip = device_in.external.address;
  var s_port = device_in.external.port;

  // server.sendto(f"{dest_ip}:{dest_port}-{nat_port}".encode(), (s_ip, s_port))
  var send = "$dest_ip:$dest_port--$nat_port".codeUnits;
}

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
