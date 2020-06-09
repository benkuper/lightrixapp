import 'dart:math';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:ltxremote/engines/nodeengine.dart';
import 'package:ltxremote/engines/showengine.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import '../common/brightness.dart';

class ShowControlPage extends StatefulWidget {
  ShowControlPage({Key key}) : super(key: key);

  final ShowControlEngine engine = new ShowControlEngine();

  @override
  _ShowControlPageState createState() => _ShowControlPageState();
}

class _ShowControlPageState extends State<ShowControlPage> {
  _BankButtonState selectedBank;

  final transportKey = GlobalKey<_TimeTransportState>();
  final audioChooserKey = GlobalKey<_AudioChooserState>();

  @override
  void initState() {
    super.initState();

    widget.engine.playStateChanged = playStateChanged;
    widget.engine.currentTimeChanged = currentTimeChanged;
    widget.engine.totalTimeChanged = totalTimeChanged;
    widget.engine.audioFileChanged = audioFileChanged;

    //init values
    if (transportKey.currentState != null) {}

    WidgetsBinding.instance
        .addPostFrameCallback((_) => afterFirstLayout(context));
  }

  void afterFirstLayout(BuildContext context) {
    if (transportKey.currentState == null) return;

    transportKey.currentState.timelineKey.currentState
        .setTotalTime(widget.engine.totalTime);

    transportKey.currentState.timelineKey.currentState
        .setCurrentTime(widget.engine.currentTime);

    transportKey.currentState.setPlaying(widget.engine.isPlaying);

    audioChooserKey.currentState?.setFileName(
        widget.engine.currentAudioFile != null
            ? path.basename(widget.engine.currentAudioFile.path)
            : "No audio file selected");

    setState(() {});
  }

  void bankButtonPressed(_BankButtonState bt) {
    if (selectedBank != null) selectedBank.setSelected(false);

    selectedBank = bt;

    if (selectedBank != null) {
      widget.engine.setBank(selectedBank.widget.id);
      if (!widget.engine.hasAudio)
        widget.engine.setTotalTime(selectedBank.widget.totalTime);
      selectedBank.setSelected(true);
      widget.engine.stopPlaying();
    } else {
      widget.engine.setBank(-1);
    }
  }

  //EVENTS
  void audioFileChanged(File file) {
    audioChooserKey.currentState
        ?.setFileName(file != null ? path.basename(file.path) : "");
  }

  void playStateChanged(bool play) {
    transportKey.currentState..setPlaying(widget.engine.isPlaying);
  }

  void currentTimeChanged(double time) {
    transportKey.currentState?.setCurrentTime(time);
  }

  void totalTimeChanged(double time) {
    transportKey.currentState?.setTotalTime(time);
  }

  @override
  void dispose() {
    widget.engine.playStateChanged = null;
    widget.engine.currentTimeChanged = null;
    widget.engine.totalTimeChanged = null;
    widget.engine.audioFileChanged = null;

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: EdgeInsets.fromLTRB(10, 10, 10, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          /*Padding(
          padding: EdgeInsets.all(10),
          child: Text("Select Bank", style: TextStyle(fontSize: 16))),
      SizedBox(
          width: 200,
          child: GridView.count(
            padding: EdgeInsets.fromLTRB(0, 10, 0, 10),
            shrinkWrap: true,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            crossAxisCount: 5,
            children: <Widget>[
              for (int i = 0; i < 10; i++)
                BankButton(id: i, onPressed: bankButtonPressed)
            ],
          )),
      Divider(),
      */
          Text("MAIN CONTROL :",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          TimeTransport(
            key: transportKey,
            onPlayPressed: widget.engine.togglePlaying,
            onStopPressed: widget.engine.stopPlaying,
            onPrevPressed: NodeEngine.instance.selectPrevBank,
            onNextPressed: NodeEngine.instance.selectNextBank,
            onSeek: widget.engine.seek,
          ),
          SizedBox(height: 10),
          Divider(thickness: 1),
          Text("AUDIO :",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          AudioChooser(
              key: audioChooserKey,
              onFileChanged: (file) {
                widget.engine.setAudioFile(file);
              }),
          SizedBox(height: 10),
          Divider(thickness: 1),
          Text("ADJUSTMENTS :",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          BrightnessSlider()
        ]));
  }
}
//********************************************************************** BANK BUTTON

class BankButton extends StatefulWidget {
  BankButton({Key key, this.id, this.onPressed}) : super(key: key);

  final int id;
  final double totalTime = 120;

  final Function(_BankButtonState bt) onPressed;

  @override
  _BankButtonState createState() => _BankButtonState();
}

class _BankButtonState extends State<BankButton> {
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

//********************************************************************** TIME TRANSPORT

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

  final timelineKey = GlobalKey<_TimelineState>();

  void setPlaying(bool value) {
    setState(() {
      isPlaying = value;
    });
  }

  void setCurrentTime(double time) {
    timelineKey.currentState.setCurrentTime(time);
  }

  void setTotalTime(double time) {
    timelineKey.currentState.setTotalTime(time);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          Timeline(key: timelineKey, onSeek: widget.onSeek),
          FittedBox(
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
                          height: 30,
                          image: AssetImage("assets/icons/prev.png"))),
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
                    child: Image(
                        height: 50, image: AssetImage("assets/icons/stop.png")),
                  ),
                  SizedBox(width: 10),
                  Listener(
                    onPointerDown: (event) {
                      widget.onNextPressed();
                    },
                    child: Image(
                        height: 30, image: AssetImage("assets/icons/next.png")),
                  ),
                ],
              )),
        ]);
  }
}

//********************************************************************** TIMELINE

class Timeline extends StatefulWidget {
  Timeline({Key key, this.onSeek}) : super(key: key);

  final Function(double time) onSeek;

  @override
  _TimelineState createState() => _TimelineState();
}

class _TimelineState extends State<Timeline> {
  double currentTime = 0;
  double totalTime = 600;
  String timeString = "";
  String totalTimeString = "";

  _TimelineState() {
    timeString = getTimeString(0);
    timeString = getTimeString(1);
  }

  void sliderChanged(double value) {
    setCurrentTime(currentTime = value);
    widget.onSeek(value);
  }

  void setTotalTime(double time) {
    setState(() {
      totalTime = time;
      totalTimeString = getTimeString(totalTime);
    });
  }

  void setCurrentTime(double time) {
    setState(() {
      currentTime = min(time, totalTime);
      timeString = getTimeString(time);
    });
  }

  String getTimeString(double time) {
    String s = Duration(milliseconds: (time * 1000).toInt()).toString();
    return s.substring(
        0, s.length - 4); //remove 4 of the trailing milliseconds number
  }

  @override
  Widget build(BuildContext context) {
    return Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[
                Text(timeString, style: TextStyle(fontSize: 30)),
                Padding(
                    padding: EdgeInsets.fromLTRB(10, 0, 0, 0),
                    child: Text("/ " + totalTimeString)),
              ]),
          Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Slider(
                  value: currentTime,
                  min: 0,
                  max: totalTime,
                  onChanged: sliderChanged)),
        ]);
  }
}

//********************************************************************** MUSIC LOADING

class AudioChooser extends StatefulWidget {
  AudioChooser({Key key, this.onFileChanged}) : super(key: key);

  final Function(File file) onFileChanged;

  @override
  _AudioChooserState createState() => _AudioChooserState();
}

class _AudioChooserState extends State<AudioChooser> {
  String fileName = "";

  void chooseAudioFile() async {
    //add the wtf file to force using generic picker and not media picker
    FilePicker.getFile(type: FileType.any).then((file){
      if(file == null) 
      {
      }else
      {
        widget.onFileChanged(file);
      }
      
    }).catchError((error)
    {
      Fluttertoast.showToast(
        msg:"[FilePicker] Error selecting audio file : "+error.toString(), backgroundColor: Colors.red, textColor: Colors.red[100]);
    });
  }

  void clearAudioFile() {
    widget.onFileChanged(null);
  }

  void setFileName(String value) {
    setState(() {
      fileName = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FittedBox(
        fit: BoxFit.fitWidth,
        child: Row(children: <Widget>[
          LimitedBox(
              maxHeight: 24,
              child: FlatButton(
                padding: EdgeInsets.fromLTRB(0, 0, 10, 0),
                child: Image(
                    image: const AssetImage("assets/icons/select_audio.png")),
                onPressed: chooseAudioFile,
              )),
          Text(fileName.isEmpty ? "No audio selected." : fileName),
          if (fileName.isNotEmpty)
            FlatButton(
              child: Text("CLEAR"),
              onPressed: clearAudioFile,
            )
        ]));
  }
}

// *************************************************************   ADVANCED GROUP
/*
class AdvancedBankDialog extends StatefulWidget {
  AdvancedBankDialog({Key key}) : super(key: key);

  @override
  _AdvancedBankDialogState createState() => _AdvancedBankDialogState();
}

class _AdvancedBankDialogState extends State<AdvancedBankDialog> {

  BankButton curBT = null;

  void bankButtonPressed(BankButton bt)
  {
      if(curBT != null) curBT.setSelected(false);
      curBT = bt;
      if(curBT != null) curBT.setSelected(true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
            padding: EdgeInsets.all(10),
            child: Text(
              widget.node.name,
              style: TextStyle(fontSize: 20),
            )),
        Padding(
          padding: EdgeInsets.all(10),
          child:Container(
          color:Colors.grey[100],
          child:Column(children: <Widget>[
            Text("Informations"),
            Row(
              children:<Widget>[
                  Text("Name : "),
                  Expanded(child:TextField(onChanged: (value){ setState((){widget.node.name = value;});})),
              ]),
              Text("IP : "+widget.node.ip),

          ],)
        ),
        ),
        Container(
          child:CircleColorPicker(size: Size(250,250), strokeWidth: 4,
                thumbSize: 40,)
        ),
        SizedBox(
          width: 200,
          child: GridView.count(
            padding: EdgeInsets.fromLTRB(0, 10, 0, 10),
            shrinkWrap: true,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            crossAxisCount: 5,
            children: <Widget>[
              for (int i = 0; i < 10; i++)
                NodeBankButton(id: i, onPressed: bankButtonPressed)
            ],
          )),
        Expanded(child:Container()),
        Padding(padding:EdgeInsets.all(20), child:RaisedButton(child:Text("Flash Firmware"),onPressed: flashFirmwarePressed))
      ],
    );
  }
}



class NodeBankButton extends StatefulWidget {
  NodeBankButton({Key key, this.id, this.onPressed}) : super(key: key);

  final int id;
  double totalTime = 120;

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
*/
