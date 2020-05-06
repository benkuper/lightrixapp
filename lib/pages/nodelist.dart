import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:ltxremote/common/effects.dart';
import 'package:ltxremote/engines/node.dart';
import 'package:ltxremote/engines/nodeengine.dart';
import '../common/colorpicker.dart';
import '../common/brightness.dart';

class NodeListPage extends StatefulWidget {
  NodeListPage({Key key}) : super(key: key);

  @override
  _NodeListPageState createState() => _NodeListPageState();
}

class _NodeListPageState extends State<NodeListPage> {
  StreamSubscription<NodeEvent> nodeSubscription;

  Node testNode;

  @override
  initState() {
    super.initState();

    testNode = new Node(
        InternetAddress.loopbackIPv4, 0, "PLAYLTXBALL", 0, 0, "TestShow", 0, 6);

    nodeSubscription = NodeEngine.instance.nodeManager.nodeStream.stream
        .listen(nodeEventReceived);
  }

  @override
  dispose() {
    nodeSubscription.cancel();
    super.dispose();
  }

  void nodeEventReceived(NodeEvent e) {
    switch (e.type) {
      case NodeEventType.NodeAdded:
      case NodeEventType.NodeRemoved:
      case NodeEventType.NodeDisconnected:
      case NodeEventType.NodeConnected:
        {
          setState(() {
            //update nodes
          });
        }
        break;

      default:
        break;
    }
  }

  void batchUploadPressed() async {
    File f = await FilePicker.getFile(
        type: FileType.custom, allowedExtensions: ["prg"]);
    for (var n in NodeEngine.instance.nodeManager.nodes) {
      n.uploadFirmware(f);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: EdgeInsets.fromLTRB(10, 0, 10, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <
            Widget>[
          Padding(
              padding: EdgeInsets.all(10),
              child: Text("PROPS :",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
          Expanded(
              child: GridView.count(
            padding: EdgeInsets.fromLTRB(10, 0, 10, 0),
            mainAxisSpacing: 20,
            crossAxisSpacing: 8,
            crossAxisCount: 3,
            children: <Widget>[
              /*NodeTile(node: testNode),
              NodeTile(node: testNode),
              NodeTile(node: testNode),
              NodeTile(node: testNode),
              NodeTile(node: testNode),
              NodeTile(node: testNode),
              NodeTile(node: testNode),
              NodeTile(node: testNode),
              NodeTile(node: testNode),
              NodeTile(node: testNode),
              NodeTile(node: testNode),*/
              for (Node n in NodeEngine.instance.nodeManager.nodes)
                NodeTile(node: n)
            ],
          )),
          Divider(thickness: 1),
          Padding(
              padding: EdgeInsets.all(10),
              child: Text("GLOBAL CONTROL :",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
          FittedBox(
              fit: BoxFit.fitWidth,
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    RaisedButton(
                        child: Text("Upload Sequence"),
                        color: Colors.grey[200],
                        onPressed: batchUploadPressed),
                    SizedBox(width: 10),
                    RaisedButton(
                        child: Text("Blackout All"),
                        color: Colors.grey[200],
                        onPressed: () {
                          NodeEngine.instance.sendColor(Colors.black);
                        }),
                    SizedBox(width: 10),
                    RaisedButton(
                      child: Text("Power Off All"),
                      color: Colors.grey[200],
                      onPressed: NodeEngine.instance.powerOff,
                    )
                  ])),
        ]));
  }
}

class NodeTile extends StatefulWidget {
  NodeTile({Key key, this.node}) : super(key: key);

  final Node node;

  @override
  _NodeTileState createState() => _NodeTileState();
}

class _NodeTileState extends State<NodeTile> {
  void showNodeWindow(BuildContext context, Node node) {
    var dialog = Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: NodeControlDialog(node: node));

    showDialog(context: context, builder: (BuildContext context) => dialog);
  }

  StreamSubscription<NodeEvent> nodeSubscription;

  @override
  void initState() {
    nodeSubscription = widget.node.nodeStream.stream.listen((e) {
      if (e.type == NodeEventType.NodeUpdated) setState(() {});
    });
    super.initState();
  }

  @override
  void dispose() {
    nodeSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onLongPress: () {
          print("Flash this prop " + widget.node.name);
        },
        onTap: () {
          showNodeWindow(context, widget.node);
        },
        child: Column(
          children: <Widget>[
            Expanded(
                child: Image(
                    image: AssetImage("assets/props/" +
                        nodeImageNames[widget.node.type.index] +
                        (widget.node.isConnected
                            ? (widget.node.isUploading ? "_uploading" : "_on")
                            : "_off") +
                        ".png"))),
            Text(
              widget.node.name /*+ " (" + widget.node.ip + ")"*/,
              style: TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            )
          ],
        ));
  }
}

// *************************************************************   NODE CONTROL

class NodeControlDialog extends StatefulWidget {
  NodeControlDialog({Key key, this.node}) : super(key: key);

  final Node node;
  @override
  _NodeControlDialogState createState() => _NodeControlDialogState();
}

class _NodeControlDialogState extends State<NodeControlDialog> {
  _NodeBankButtonState curBT;

  StreamSubscription<NodeEvent> nodeManagerSubscription;
  final infoBoxKey = GlobalKey<_NodeInfoBoxState>();
  final colorPickerKey = GlobalKey<CircleColorPickerState>();

  static Widget blockPickerLayoutBuilder(
      BuildContext context, List<Color> colors, PickerItem child) {
    return Container(
      width: 300.0,
      height: 200.0,
      child: GridView.count(
        crossAxisCount: 5,
        crossAxisSpacing: 5.0,
        mainAxisSpacing: 5.0,
        children: colors.map((Color color) => child(color)).toList(),
      ),
    );
  }

  @override
  initState() {
    super.initState();
    nodeManagerSubscription = NodeEngine.instance.nodeManager.nodeStream.stream
        .listen(nodeEventReceived);
  }

  @override
  dispose() {
    nodeManagerSubscription.cancel();
    super.dispose();
  }

  void nodeEventReceived(NodeEvent e) {
    switch (e.type) {
      case NodeEventType.NodeUpdated:
      case NodeEventType.NodeConnected:
      case NodeEventType.NodeDisconnected:
        infoBoxKey.currentState.setState(() {});
        break;
      default:
        break;
    }
  }

  void flashFirmwarePressed() async {
    File fwFile = await FilePicker.getFile(
        type: FileType.custom, allowedExtensions: ["prg"]);
    widget.node.uploadFirmware(fwFile);
  }

  void bankButtonPressed(_NodeBankButtonState bt) {
    if (curBT != null) curBT.setSelected(false);
    curBT = bt;
    if (curBT != null) curBT.setSelected(true);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: <Widget>[
      Padding(
          padding: EdgeInsets.all(10),
          child: Column(children: <Widget>[
            Text(
              widget.node.name,
              style: TextStyle(fontSize: 20),
            ),
            NodeInfoBox(key: infoBoxKey, node: widget.node),
            SizedBox(height: 20),
            Expanded(
                child: CircleColorPicker(
              key: colorPickerKey,
              initialColor: Colors.blue,
              onChanged: (color) {
                NodeEngine.instance.sendColor(color, nodes: [widget.node]);
              },
              strokeWidth: 10,
              thumbSize: 20,
            )),
            BrightnessSlider(node: widget.node),
            StrobeSlider(node: widget.node),
            SizedBox(height: 20),
            TimeTransport(
              onPrevPressed: () {
                NodeEngine.instance.selectPrevBank(nodes: [widget.node]);
              },
              onNextPressed: () {
                NodeEngine.instance.selectNextBank(nodes: [widget.node]);
              },
              onPlayPressed: () {
                NodeEngine.instance.startShowNoSync(nodes: [widget.node]);
              },
              onStopPressed: () {
                NodeEngine.instance.stopShowNoSync(nodes: [widget.node]);
              },
            ),
            FittedBox(
              fit: BoxFit.fitWidth,
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    RaisedButton(
                        child: Text("Upload Sequence"),
                        onPressed: flashFirmwarePressed),
                    SizedBox(width: 10),
                    RaisedButton(
                        child: Text("Blackout"),
                        color: Colors.grey[200],
                        onPressed: () {
                          NodeEngine.instance
                              .sendColor(Colors.black, nodes: [widget.node]);
                        }),
                    SizedBox(width: 10),
                    RaisedButton(
                      child: Text("Power Off"),
                      color: Colors.grey[200],
                      onPressed: () {
                        NodeEngine.instance.powerOff(nodes: [widget.node]);
                      },
                    )
                  ]),
            ),
          ])),
      Positioned(
        right: 2,
        top:2,
        child: GestureDetector(
          onTap: () {
            Navigator.of(context).pop();
          },
          child: Align(
            alignment: Alignment.topRight,
            child: CircleAvatar(
              radius: 16.0,
              backgroundColor: Colors.grey[800],
              child: Icon(Icons.close, color: Colors.grey[300],size: 16),
            ),
          ),
        ),
      ),
    ]);
  }
}

class NodeBankButton extends StatefulWidget {
  NodeBankButton({Key key, this.id, this.onPressed}) : super(key: key);

  final int id;

  final Function(_NodeBankButtonState bt) onPressed;

  @override
  _NodeBankButtonState createState() => _NodeBankButtonState();
}

class _NodeBankButtonState extends State<NodeBankButton> {
  bool isSelected = false;

  void setSelected(bool value) {
    setState(() {
      isSelected = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return RaisedButton(
        padding: EdgeInsets.all(0),
        child: Text((widget.id + 1).toString()),
        color: isSelected ? Colors.blue.shade400 : Color(0xffeeeeee),
        textColor: isSelected ? Colors.blue.shade100 : Color(0xffaaaaaa),
        onPressed: () {
          widget.onPressed(this);
        });
  }
}

// NODE TIME TRANSPORT

class TimeTransport extends StatefulWidget {
  TimeTransport(
      {Key key,
      this.onPlayPressed,
      this.onStopPressed,
      this.onPrevPressed,
      this.onNextPressed,
      this.onSeek})
      : super(key: key);

  final Function() onPlayPressed;
  final Function() onStopPressed;
  final Function() onPrevPressed;
  final Function() onNextPressed;
  final Function(double time) onSeek;

  @override
  _TimeTransportState createState() => _TimeTransportState();
}

class _TimeTransportState extends State<TimeTransport> {
  bool isPlaying = false;

  void setPlaying(bool value) {
    setState(() {
      isPlaying = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FittedBox(
        fit: BoxFit.fitWidth,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Listener(
                onPointerDown: (event) {
                  widget.onPrevPressed();
                },
                child: Image(
                    height: 30, image: AssetImage("assets/icons/prev.png"))),
            SizedBox(width: 10),
            Listener(
                onPointerDown: (event) {
                  widget.onPlayPressed();
                },
                child: Image(
                    height: 50,
                    image: AssetImage(isPlaying
                        ? "assets/icons/play_on.png"
                        : "assets/icons/play_off.png"))),
            SizedBox(width: 10),
            Listener(
              onPointerDown: (event) {
                widget.onStopPressed();
              },
              child:
                  Image(height: 50, image: AssetImage("assets/icons/stop.png")),
            ),
            SizedBox(width: 10),
            Listener(
              onPointerDown: (event) {
                widget.onNextPressed();
              },
              child:
                  Image(height: 30, image: AssetImage("assets/icons/next.png")),
            ),
          ],
        ));
  }
}

class NodeInfoBox extends StatefulWidget {
  NodeInfoBox({Key key, this.node}) : super(key: key);

  final Node node;
  @override
  _NodeInfoBoxState createState() => _NodeInfoBoxState();
}

class _NodeInfoBoxState extends State<NodeInfoBox> {
  bool isPlaying = false;

  void setPlaying(bool value) {
    setState(() {
      isPlaying = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        width: 200,
        color: Colors.grey[100],
        child: Padding(
            padding: EdgeInsets.all(5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text("Information"),
                Text("IP : " + widget.node.ip.address),
                Text("Bank : " + widget.node.bank.toString()),
                Text("Item : " + widget.node.curItemInSequence.toString()),
                Text("File : " + widget.node.showName.toString()),

                /*
            Row(children: <Widget>[
              Text("Name : "),
              Expanded(child: TextField(onChanged: (value) {
                setState(() {
                  widget.node.name = value;
                });
              })),
            ]),*/
              ],
            )));
  }
}
