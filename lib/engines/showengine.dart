import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:just_audio/just_audio.dart';
import 'package:ltxremote/engines/nodeengine.dart';
import 'package:path/path.dart' as path;

class ShowControlEngine {
  ShowControlEngine() {
    audioPlayer = new AudioPlayer();
    // playerId: "main", mode: PlayerMode.MEDIA_PLAYER);
    //audioPlayer.onDurationChanged.listen(audioDurationChanged);
    //audioPlayer.onAudioPositionChanged.listen(audioPositionChanged);

    //audioPlayer.isPlayingNotifier.addListener(() => setState(() {}));
    audioPlayer.getPositionStream().listen(audioPositionChanged);
    //audioPlayer.durationFuture.asStream().listen(audioDurationChanged);
  }

  int selectedBankID = 0;

  File currentAudioFile;
  AudioPlayer audioPlayer;
  bool hasAudio = false;

  bool isPlaying = false;
  double currentTime = 0;
  double totalTime = 600;

  final int playUpdateRate = 50; //ms
  Timer playTimer;

  double currentBrightness = 8;

  Function(bool isPlaying) playStateChanged;
  Function(double time) currentTimeChanged;
  Function(double time) totalTimeChanged;
  Function(File file) audioFileChanged;

  void selectPrevBank() {
    stopPlaying();
    NodeEngine.instance.selectPrevBank();
    Fluttertoast.cancel();
    Fluttertoast.showToast(msg: "Previous bank");
  }

  void selectNextBank() {
    stopPlaying();
    NodeEngine.instance.selectNextBank();
    Fluttertoast.cancel();
    Fluttertoast.showToast(msg: "Next bank");
  }

  void seek(double time) {
    setCurrentTime(time);

    //force sending message here
    if (isPlaying) {
      NodeEngine.instance.sendShowCommand(currentTime, true);
    }

    if (hasAudio)
      audioPlayer.seek(Duration(milliseconds: (time * 1000).round()));
  }

  void setCurrentTime(double time) {
    currentTime = time;
    NodeEngine.instance.globalStateTime = currentTime;
    currentTimeChanged(currentTime);
  }

  void setTotalTime(double time) {
    totalTime = time;
    totalTimeChanged(totalTime);
  }

  void togglePlaying() {
    setPlaying(!isPlaying);
  }

  void stopPlaying() {
    setPlaying(false);
    if (hasAudio) {
      audioPlayer.stop();
      audioPlayer.seek(Duration(seconds: 0));
    }
    setCurrentTime(0);
  }

  void setPlaying(bool value) {
    bool hasChanged = isPlaying != value;

    if (!hasChanged) return;
    isPlaying = value;

    if (isPlaying) {
      NodeEngine.instance.sendShowCommand(currentTime, true);

      if (hasAudio) {
        audioPlayer.play();
      }

      playTimer =
          Timer.periodic(Duration(milliseconds: playUpdateRate), onTimerTick);

      Fluttertoast.cancel();
      Fluttertoast.showToast(
          msg: hasChanged ? "Show started" : "Show resumed.");
    } else {
      NodeEngine.instance.sendStopShow();

      if (hasAudio) audioPlayer.pause();
      playTimer?.cancel();

      Fluttertoast.cancel();
      Fluttertoast.showToast(msg: "Show stopped.");
    }

    playStateChanged(isPlaying);
  }

  void onTimerTick(Timer t) {
    if (isPlaying) setCurrentTime(currentTime + playUpdateRate * 1.0 / 1000);
  }

  void setAudioFile(File file) async {
    currentAudioFile = file;

    if (file != null) {
      audioPlayer.setFilePath(file.path).then((Duration totalTime) {
        print("Audio set to file " +
            file.path +
            ", duration :" +
            totalTime.inMilliseconds.toString() +
            " ms");
        audioPlayer.stop();

        hasAudio = true;
        setTotalTime(totalTime.inMilliseconds / 1000.0);
      }).catchError((error) {
        hasAudio = false;
        Fluttertoast.showToast(
            msg: "Error playing file " +
                path.basename(file.path) +
                " : " +
                error.toString(),
            backgroundColor: Colors.red,
            textColor: Colors.red[100]);
      });
    }

    audioFileChanged(currentAudioFile);
  }

  void audioDurationChanged(Duration duration) {
    setTotalTime(duration.inMilliseconds / 1000.0);
  }

  void audioPositionChanged(Duration position) {
    setCurrentTime((position.inMilliseconds / 1000.0));
  }
}
