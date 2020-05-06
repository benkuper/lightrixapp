import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:ltxremote/common/effects.dart';
import 'package:ltxremote/engines/nodeengine.dart';
import '../common/colorpicker.dart';
import '../common/brightness.dart';

enum ColorControlMode { SWATCH, PICKER }

class LiveControlPage extends StatefulWidget {
  LiveControlPage({Key key}) : super(key: key);

  @override
  _LiveControlPageState createState() => _LiveControlPageState();
}

class _LiveControlPageState extends State<LiveControlPage> {
  double strobeValue = 0;
  double fadeValue = 0;

  ColorControlMode colorControlMode = ColorControlMode.SWATCH;

 final colorPickerKey = GlobalKey<CircleColorPickerState>();

  var swatchColors = new List<ColorSwatch>();

  @override
  void initState() {
    super.initState();

    for (var c in [
      Colors.white,
      Colors.black,
      Color(0xff00ff00),
      Color(0xffff0000),
      Color(0xff0000ff),
      Colors.grey[400],
      Colors.grey[800],
      Colors.green,
      Colors.red,
      Colors.blue,
      Colors.cyan,
      Colors.yellow,
      Colors.orange,
      Colors.pink,
      Colors.purple
    ]) {
      var m = new Map<dynamic, Color>();
      m[0] = c;
      var s = new ColorSwatch(c.value, m);
      swatchColors.add(s);
    }
  }

  void setColorControlMode(ColorControlMode m) {
    setState(() {
      colorControlMode = m;
    });
  }

  static Widget blockPickerLayoutBuilder(
      BuildContext context, List<Color> colors, PickerItem child) {
   
    return Container(
      width: 300.0,
      height: 360.0,
      child: GridView.count(
        crossAxisCount: 5,
        crossAxisSpacing: 5.0,
        mainAxisSpacing: 5.0,
        children: colors.map((Color color) => child(color)).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
           Padding(
              padding: EdgeInsets.fromLTRB(10,10,0,0),
              child:Text("COLOR CONTROL :",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
           ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              RaisedButton(
                  color: colorControlMode == ColorControlMode.SWATCH
                      ? Colors.blue
                      : Colors.grey[200],
                  child: Text("Simple",
                      style: TextStyle(
                        color: colorControlMode == ColorControlMode.SWATCH
                            ? Colors.lightBlue[100]
                            : Colors.grey[800],
                      )),
                  onPressed: () {
                    setColorControlMode(ColorControlMode.SWATCH);
                  }),
              RaisedButton(
                  color: colorControlMode == ColorControlMode.PICKER
                      ? Colors.blue
                      : Colors.grey[200],
                  child: Text("Advanced",
                      style: TextStyle(
                        color: colorControlMode == ColorControlMode.PICKER
                            ? Colors.lightBlue[100]
                            : Colors.grey[800],
                      )),
                  onPressed: () {
                    setColorControlMode(ColorControlMode.PICKER);
                  }),
            ],
          ),
          if (colorControlMode == ColorControlMode.PICKER)
            Expanded(
              child: CircleColorPicker(
                key: colorPickerKey,
                initialColor: Colors.blue,
                onChanged: NodeEngine.instance.sendColor,
                strokeWidth: 10,
                thumbSize: 20,
              ),
            ),
          if (colorControlMode == ColorControlMode.SWATCH)
            Expanded(
              child: Center(
                  child: BlockPicker(
                pickerColor: Colors.black,
                onColorChanged: NodeEngine.instance.sendColor,
                availableColors: swatchColors,
                layoutBuilder: blockPickerLayoutBuilder,
              )),
            ),
          Divider(thickness: 1),
          Padding(
              padding: EdgeInsets.fromLTRB(10,0,0,0),
              child: Text("EFFECTS :",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
          Padding(
              padding: EdgeInsets.fromLTRB(10,0,0,0),
              child: BrightnessSlider()),
          Padding(
              padding: EdgeInsets.fromLTRB(10,0,0,0),
              child: StrobeSlider()),
        ]);
  }
}
