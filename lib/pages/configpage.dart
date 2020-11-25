import 'package:flutter/material.dart';
import 'package:ltxremote/engines/nodeengine.dart';

class ConfigPage extends StatefulWidget {
  ConfigPage({Key key}) : super(key: key);

  @override
  _ConfigPageState createState() => _ConfigPageState();
}

class _ConfigPageState extends State<ConfigPage> {
  TextEditingController ssidController;
  TextEditingController passController;

  void initState() {
    super.initState();
    ssidController = TextEditingController();
    passController = TextEditingController();
  }

  void dispose() {
    ssidController.dispose();
    passController.dispose();
    super.dispose();
  }

  void sendWifiCredentials() {
    NodeEngine.instance.nodeManager
        .sendWifiCredentials(ssidController.text, passController.text);
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
          padding: EdgeInsets.fromLTRB(10, 10, 10, 0),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
                padding: EdgeInsets.fromLTRB(0, 0, 0, 10),
                child: Text("WIFI CREDENTIALS",
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
            TextField(
              controller: ssidController,
              decoration: InputDecoration(
                  border: OutlineInputBorder(), labelText: 'SSID'),
            ),
            SizedBox(height: 10),
            TextField(
              controller: passController,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Password',
              ),
            ),
            Center(
                child: RaisedButton(
                    padding: EdgeInsets.all(10),
                    child: Text("Send Wifi Setup"),
                    onPressed: () {
                      sendWifiCredentials();
                    })),
            Divider(thickness: 1),
          ]))
    ]);
  }
}

// Elements
