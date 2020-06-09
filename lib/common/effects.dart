
import 'package:flutter/material.dart';
import 'package:ltxremote/engines/node.dart';
import 'package:ltxremote/engines/nodeengine.dart';

class StrobeSlider extends StatefulWidget {
  StrobeSlider({this.node}) : super();

  final Node node;
  
  @override
  _StrobeSliderState createState() => _StrobeSliderState();
}

class _StrobeSliderState extends State<StrobeSlider> {
 
  @override void initState() {
    super.initState();
    NodeEngine.instance.strobeChanged = strobeChanged;
  }

  void strobeChanged(double value) {
     setState(() {
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: <Widget>[
      Text("Strobe"),
      Expanded(
        child: Slider(
        min: 0,
        max: 9,
        divisions: 10,
        activeColor: (widget.node == null?NodeEngine.instance.currentStrobe:widget.node.currentStrobe) > 0 ? Colors.orange : Colors.grey,
        inactiveColor: (widget.node == null?NodeEngine.instance.currentStrobe:widget.node.currentStrobe) > 0
            ? Colors.orange[100] : Colors.grey[200],
        value: widget.node == null?NodeEngine.instance.currentStrobe:widget.node.currentStrobe,
        onChanged: (value){ NodeEngine.instance.setStrobe(value, nodes:widget.node == null?[]:[widget.node]);}
      )),
      Padding(
          padding: EdgeInsets.fromLTRB(0, 0, 10, 0),
          child: Text((widget.node == null?NodeEngine.instance.currentStrobe:widget.node.currentStrobe).round().toString())),
    ]);
  }
}