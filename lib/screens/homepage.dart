import 'package:flutter/material.dart';
import 'package:flutter_screenshot/flutter_screenshot.dart';
import 'package:peer2peer/services/p2p.dart';
import 'package:provider/provider.dart';

class HomePage extends StatelessWidget {
  final TextEditingController _ip = TextEditingController();

  final TextEditingController _message = TextEditingController();

  final TextEditingController a = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final p2p = Provider.of<P2P>(context, listen: false);
    return Scaffold(
      appBar: AppBar(
        title: Text('P2P Implementation'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextFormField(
                  controller: a,
                  decoration: InputDecoration(labelText: 'from'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextFormField(
                  controller: _ip,
                  decoration: InputDecoration(labelText: 'to'),
                ),
              ),
//                  Padding(
//                    padding: const EdgeInsets.all(8.0),
//                    child: RaisedButton(
//                      child: Padding(
//                        padding: const EdgeInsets.all(8.0),
//                        child: Text(
//                          'Initialize Network',
//                          textScaleFactor: 1.1,
//                        ),
//                      ),
//                      elevation: 20,
//                      onPressed: () => p2p.initializer(ip: _ip.text),
//                      color: Color(0xff59C9A5),
//                    ),
//                  ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: RaisedButton(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Initialize',
                      textScaleFactor: 1.1,
                    ),
                  ),
                  elevation: 20,
                  onPressed: () => p2p.testingNatHolePunching(a.text, _ip.text),
                  color: Color(0xff59C9A5),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: RaisedButton(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Start Camera',
                      textScaleFactor: 1.1,
                    ),
                  ),
                  elevation: 20,
                  onPressed: () => p2p.startCamera(),
                  color: Color(0xff59C9A5),
                ),
              ),
//              Padding(
//                padding: const EdgeInsets.all(8.0),
//                child: RaisedButton(
//                  child: Padding(
//                    padding: const EdgeInsets.all(8.0),
//                    child: Text(
//                      'CApture frames',
//                      textScaleFactor: 1.1,
//                    ),
//                  ),
//                  elevation: 20,
//                  onPressed: () => p2p.captureFrames(),
//                  color: Color(0xff59C9A5),
//                ),
//              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: RaisedButton(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Send dummmy with NAT',
                      textScaleFactor: 1.1,
                    ),
                  ),
                  elevation: 20,
                  onPressed: () => p2p.sendEmpty(),
                  color: Color(0xff59C9A5),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: RaisedButton(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Send original message with nat',
                      textScaleFactor: 1.1,
                    ),
                  ),
                  elevation: 20,
                  onPressed: () => p2p.sender(_message.text),
                  color: Color(0xff59C9A5),
                ),
              ),
              ScreenshotContainer(
                child: Consumer<P2P>(
                  builder: (_, value, __) => Slider(
                    value: value.val,
                    onChanged: (v) => value.setValue(v),
                    max: 20,
                    min: 0,
                  ),
                ),
                controller: p2p.ssController,
              ),
//              if (p2p.cameraController.value.isInitialized)
//                Text('my cam'),
//              if (p2p.cameraController.value.isInitialized)
//                AspectRatio(
//                  child: ScreenshotContainer(
//                    controller: p2p.ssController,
//                    child: Container(
//                      child: CameraPreview(p2p.cameraController),
//                      color: Colors.blue,
//                    ),
//                  ),
//                  aspectRatio: p2p.cameraController.value.aspectRatio,
//                ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: RaisedButton(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Stop streaming',
                      textScaleFactor: 1.1,
                    ),
                  ),
                  elevation: 20,
                  onPressed: () => p2p.stop(),
                  color: Color(0xff59C9A5),
                ),
              ),
              Consumer<P2P>(builder: (_, value, __) {
                if (value.frame != null)
                  return Image.memory(
                    value.frame,
//                    height: value.image.height.toDouble(),
//                    width: value.image.width.toDouble(),
                  );
                return Container();
              }),
            ],
          ),
        ),
      ),
    );
  }
}
