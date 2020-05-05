
import 'package:flutter/material.dart';
import 'package:lightrixapp/engines/node.dart';
import 'package:lightrixapp/engines/nodeengine.dart';

class BrightnessSlider extends StatefulWidget {
  BrightnessSlider({this.node}) : super();

  final Node node;
  
  @override
  _BrightnessSliderState createState() => _BrightnessSliderState();
}

class _BrightnessSliderState extends State<BrightnessSlider> {
 
  @override void initState() {
    super.initState();
    NodeEngine.instance.brightnessChanged = brightnessChanged;
  }

  void brightnessChanged(double value) {
     setState(() {
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: <Widget>[
      Text("Brightness"),
      Expanded(
          child: Slider(
        min: 0,
        max: 8,
        divisions: 8,
        value: widget.node == null?NodeEngine.instance.currentBrightness:widget.node.currentBrightness,
        onChanged: (value){ NodeEngine.instance.setGlobalBrightness(value, nodes:widget.node == null?[]:[widget.node]);}
        //activeColor: value > 0 ? widget.activeColor : Colors.grey,
        //inactiveColor: value > 0 ? HSLColor.fromColor(widget.activeColor).withLightness(.9).toColor(): Colors.grey[200])
      )),

      Padding(
          padding: EdgeInsets.fromLTRB(0, 0, 10, 0),
          child: Text((widget.node == null?NodeEngine.instance.currentBrightness:widget.node.currentBrightness).round().toString())),
    ]);
  }
}