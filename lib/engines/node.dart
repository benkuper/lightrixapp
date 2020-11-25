import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path/path.dart' as path;

enum NodeEventType {
  NodeAdded,
  NodeUpdated,
  NodeRemoved,
  NodeConnected,
  NodeDisconnected
}

class NodeEvent {
  NodeEvent(this.type, this.node);
  NodeEventType type;
  Node node;
}

enum NodeType { UNKNOWN, STICK, HOOP, BALL }
final nodeTypeNames = ["Unknown", "Stick", "Hoop", "Ball"];
final nodeImageNames = ["node", "stick", "hoop", "ball"];

class Node {
  Node(this.ip, this.id, this.name, this.bank, this.curItemInSequence,
      this.showName, this.localTime, this.numPixels) {
    isConnected = true;
    timeAtLastPing = DateTime.now().millisecondsSinceEpoch;
  }

  int id = 0;
  String name = "";
  NodeType type = NodeType.UNKNOWN;
  InternetAddress ip;
  bool isPlaying = false;
  String showName;
  int bank = 0;
  int curItemInSequence = 0;
  int localTime = 0;
  int numPixels = 0;
  String lastMessage = "";

  bool isConnected = true;
  int timeAtLastPing = 0;
  int timeAtDisconnected = 0;

  Socket tcp; //for upload firmware and wifiCredentials

  final int magicPRGByte = 0;
  File prgFileToUpload;
  bool isUploading = false;

  StreamController<NodeEvent> nodeStream =
      StreamController<NodeEvent>.broadcast();

  double currentBrightness = 8;
  double currentStrobe = 0;

  void setUploading(bool value) {
    if (isUploading == value) return;
    isUploading = value;

    nodeStream.add(NodeEvent(NodeEventType.NodeUpdated, this));
  }

  void setMessage(String msg) {
    if (lastMessage == msg) return;

    lastMessage = msg;

    print("[" + name + "] New message : " + msg);

    if (isUploading) {
      if (msg == "upload ok") {
        Fluttertoast.showToast(
            msg: "[" + name + "] Upload complete",
            backgroundColor: Colors.green[500],
            textColor: Colors.green[100]);
        setUploading(false);
      } else
        Fluttertoast.showToast(msg: "[" + name + "] " + lastMessage);
    }
  }

  void uploadFirmware(File f) async {
    if (f == null) return;

    if (!isConnected) {
      Fluttertoast.showToast(
          msg: "[" + name + "] Node is not connected, not uploading.",
          backgroundColor: Colors.orange[500],
          textColor: Colors.orange[100]);
      setUploading(false);
    }

    prgFileToUpload = f;

    tcp?.close();
    print("Connecting to " + ip.address.toString() + "...");
    Socket.connect(ip, 8888).then(socketConnectedForUpload).catchError((error) {
      toastError("Error connecting to node : " + error.toString());
      tcp?.close();
    });
  }

  void socketConnectedForUpload(Socket socket) async {
    tcp = socket;

    var prgBytes = prgFileToUpload.readAsBytesSync();

    String filename = path.basename(prgFileToUpload.path);
    List<int> packetStartBytes = getBytesFromInt32(magicPRGByte);
    List<int> dataLength = getBytesFromInt32(prgBytes.length);
    List<int> crc = getBytesFromInt32(getCrc32(prgBytes));
    List<int> addr =
        getBytesFromInt32(16 + filename.length); //4xint32 + filename length
    List<int> filenameBytes = Utf8Codec().encode(filename);

    var bytes = List<int>();
    bytes.addAll(packetStartBytes);
    bytes.addAll(dataLength);
    bytes.addAll(crc);
    bytes.addAll(addr);
    bytes.addAll(filenameBytes);
    bytes.addAll(prgBytes);

    try {
      Fluttertoast.showToast(msg: "Uploading...");
      setUploading(true);
      lastMessage = "";
      tcp.add(bytes);
    } catch (error) {
      toastError("Error uploading firmware : " + error.toString());
      setUploading(false);
    }

    tcp.close();
  }

  void uploadComplete(result) {
    print("Upload complete : " + result);
    Fluttertoast.showToast(
        msg: "Upload complete",
        backgroundColor: Colors.green[700],
        textColor: Colors.green[50]);
    tcp?.close();
  }

  void sendWifiCredentials(String ssid, String pass) {
    if (!isConnected) return;

    if (ssid.isEmpty) {
      print("SSID can not be empty !");
      return;
    }

    if (pass.isEmpty) {
      print("Pass can not be empty !");
      return;
    }

    tcp?.close();
    print("Connecting to " + ip.address.toString() + "...");
    Socket.connect(ip, 8888).then((Socket socket) {
      tcp = socket;
      tcp.write("\r");
      tcp.write("CS" + ssid + "\r");
      tcp.write("CP" + pass + "\r");
      tcp.write("CT\r");

      Fluttertoast.showToast(
          msg: "[" + name + "] set to " + ssid + " : " + pass);
    }).catchError((error) {
      toastError("Error connecting to node : " + error.toString());
      tcp?.close();
    });
  }

  void toastError(msg) {
    Fluttertoast.showToast(
        msg: "[" + name + "] " + msg,
        backgroundColor: Colors.red,
        textColor: Colors.red[100]);
  }

  List<int> getBytesFromInt32(
    int data,
  ) {
    return [
      data & 0xFF,
      (data >> 8) & 0xFF,
      (data >> 16) & 0xFF,
      (data >> 24) & 0xFF
    ];
  }
}
