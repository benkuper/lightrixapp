import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:ltxremote/engines/node.dart';

import 'package:multicast_lock/multicast_lock.dart';
import 'package:udp/udp.dart';
import 'nodemanager.dart';

class CommandIDs {
  //Commands
  static final int startShow = 0x01;
  static final int stopShow = 0x02;
  static final int setGroupMask = 0x03;
  static final int nextShowItem = 0x05;
  static final int prevShowItem = 0x06;
  static final int nextShow = 0x07;
  static final int prevShow = 0x08;
  static final int brightness = 0x10;
  static final int singleRGB = 0x0A;
  static final int fade = 0x0C;
  static final int strobe = 0x12;
  static final int multiRGB = 0x0e;
  static final int multiRGBLoop = 0x0f;
  static final int powerOff = 0x51;
}

class NodeEngine {
  static NodeEngine instance;
  NodeManager nodeManager = new NodeManager();

  InternetAddress ip;
  InternetAddress broadcastIP;
  UDP sender;
  UDP receiver;
  final bool useMulticastLock = true;
  final multicastLock = new MulticastLock(); //for receiving broadcast
  final bool useBroadcastForGlobalCommands = false;

  final bool useTestNode = false;

  bool globalStateIsPlaying = false;
  double globalStateTime = 0;
  Timer globalStateTimer;

  Timer connectivityTimer;

  //Packet
  final int eventMagicByte = 0x42; // 'B'
  final int globalStateMagicByte = 0x61; // 'a'

  int packetSeqID = 0; //should always increment
  int globalStateSeqID = 0; //should always increment

  //sync
  int timestampAtSync = 0;
  int showStartTimestamp;

  double currentBrightness = 8;
  double currentStrobe = 0;
  Function(double value) brightnessChanged;
  Function(double value) strobeChanged;

  NodeEngine() {
    instance = this;

    WidgetsFlutterBinding.ensureInitialized();
    init();

    if (useTestNode) {
      nodeManager.updateNode(InternetAddress("192.168.1.74"), 0, "PLAYLTXBALL",
          0, 0, "TestShow", 0, 1, "testMessage");
    }

    globalStateTimer =
        Timer.periodic(Duration(milliseconds: 10), globalStateTimerCallback);

    connectivityTimer =
        Timer.periodic(Duration(seconds: 200), connectivityTimerCallback);
  }

  void init() async {
    if (useMulticastLock) multicastLock.acquire();

    ip = await getFirstIP();
    Endpoint ep = Endpoint.unicast(ip, port: Port(41413));

    sender = await UDP.bind(ep);
    sender.socket.broadcastEnabled = true;
    print("UDP sender bound to " + ep.address.toString());

    var ipSplit = ep.address.address.split(".");
    ipSplit[3] = "255";
    broadcastIP = InternetAddress(ipSplit.join("."));

    receiver = await UDP
        .bind(Endpoint.unicast(InternetAddress("0.0.0.0"), port: Port(41412)));
    receiver.socket.broadcastEnabled = true;

    print("Is receiver broadcast ? " + receiver.socket.isBroadcast.toString());

    // receiving\listening
    await receiver.listen(packetReceived);
  }

  void clear() //should be call at app exit
  {
    // we should release lock after listening
    if (useMulticastLock) multicastLock.release();
  }

  //SET PARAMS
  void setGlobalBrightness(double value, {List<Node> nodes}) {
    if (nodes == null || nodes.length == 0) {
      for (Node n in nodeManager.nodes) n.currentBrightness = value;
      currentBrightness = value;
    } else {
      for (Node n in nodes) n.currentBrightness = value;
    }

    brightnessChanged(value);
    sendBrightness(value.toInt(), nodes: nodes);
  }

  void setStrobe(double value, {List<Node> nodes}) {
    if (nodes == null || nodes.length == 0) {
      for (Node n in nodeManager.nodes) n.currentStrobe = value;
      currentStrobe = value;
    } else {
      for (Node n in nodes) n.currentStrobe = value;
    }

    strobeChanged(value);
    sendStrobe(value.toInt(), nodes: nodes);
  }

  // NODES COMMANDS
  void sendColor(Color color, {List<Node> nodes}) {
    sendEventCommand(CommandIDs.singleRGB,
        data: [color.red, color.green, color.blue], nodes: nodes);
  }

  void sendBrightness(int value, {List<Node> nodes}) {
    sendEventCommand(CommandIDs.brightness, data: [8 - value], nodes: nodes);
  }

  void sendFade(double value, {List<Node> nodes}) {
    List<int> data = getBytesFromInt32((value * 1000).toInt());
    sendEventCommand(CommandIDs.fade, data: data, nodes: nodes);
  }

  void sendStrobe(int value, {List<Node> nodes}) {
    //List<int> data = getBytesFromInt32((value*1000).toInt());
    sendEventCommand(CommandIDs.strobe,
        data: [value == 0 ? 0 : 10 - value], nodes: nodes);
  }

  void powerOff({List<Node> nodes}) {
    sendEventCommand(CommandIDs.powerOff, nodes: nodes);
  }

  //Show
  void updateShowState(bool isPlaying, double time,
      [bool forceSending = false]) {
    if (globalStateIsPlaying != isPlaying || forceSending) {
      globalStateIsPlaying = isPlaying;
      if (globalStateIsPlaying || forceSending) {
        //startShowNoSync();
        sendShowCommand(globalStateTime);
      }
    }

    globalStateTime = time;
  }

  void selectPrevBank({List<Node> nodes}) {
    sendEventCommand(CommandIDs.prevShow, nodes: nodes);
  }

  void selectNextBank({List<Node> nodes}) {
    sendEventCommand(CommandIDs.nextShow, nodes: nodes);
  }

  void startShowNoSync({List<Node> nodes}) {
    sendEventCommand(CommandIDs.startShow, nodes: nodes);
  }

  void stopShowNoSync({List<Node> nodes}) {
    sendEventCommand(CommandIDs.stopShow, nodes: nodes);
  }

  //TIMER
  void globalStateTimerCallback(Timer t) {
    if (globalStateIsPlaying) {
      //sendShowCommand(globalStateTime); //always sending makes glitches
    } else {
      //sendStopShow();
    }
  }

  void connectivityTimerCallback(Timer t) {
    getFirstIP().then((InternetAddress newIP) {
      if (newIP != ip) {
        print("IP Changed, reinit !");
        init();
      }
    });
  }

  // GENERIC SEND COMMAND (internal)
  void sendEventCommand(int commandID,
      {List<int> data, List<Node> nodes}) async {
    var bytes = [eventMagicByte, 0, 0, 0, 0, packetSeqID++, 0, 0, commandID];
    if (data != null) bytes.addAll(data);
    sendPacket(bytes, nodes: nodes);
  }

  void sendShowCommand(double time) {
    showStartTimestamp = timestampAtSync -
        (time * 1000).round(); //node sync time + diff since sync with node

    sendGlobalStateCommand(showStartTimestamp);
    //print("show time / node time : "+showStartTimestamp.toString()+" / "+timestampAtSync.toString());
  }

  void sendStopShow() {
    stopShowNoSync();
    sendGlobalStateCommand(0);
  }

  void sendGlobalStateCommand(int timestamp) {
    //  if (nodeManager.getNumConnectedNode() == 0) {
    //no connected node, return
    //    return;
    //  }

    var bytes = [globalStateMagicByte];
    var seqIdBytes = getBytesFromInt32(globalStateSeqID++);
    var timestampBytes = getBytesFromInt32(timestamp);
    bytes.addAll(seqIdBytes);
    bytes.addAll(timestampBytes);
    //print("Send byte for show : "+bytes.toString()+" / "+timestampBytes.length.toString()+" / "+bytes.length.toString());
    sendPacket(bytes);
  }

  void sendPacket(List<int> bytes, {List<Node> nodes}) async {
    try {
      if (useBroadcastForGlobalCommands) {
        //BROADCAST
        //print("Send broadcast IP");
        Endpoint ep = Endpoint.unicast(broadcastIP, port: Port(41412));
        await sender.send(bytes, ep); //
      } else {
        //SEPARATE IP
        if ((nodes == null || nodes.isEmpty)) {
          nodes = nodeManager.nodes;
        }
        //print("Send separate IP");
        for (var n in nodes) {
          //print("Send to IP " + n.ip.toString());
          Endpoint ep = Endpoint.unicast(n.ip, port: Port(41412));
          await sender.send(bytes, ep); //
        }
      }
    } catch (error) {
      print("Error : " + error.toString());
      return;
    }
  }

  //RECEIVE

  void packetReceived(Datagram packet) {
    //print("Received  packet received from " + packet.address.address.toString());
    if (packet.address == ip) {
      //print("received local packet " + packet.data.length.toString());
      return; //do not listen to own packets
    }

    int packetStart = packet.data[0];
    switch (packetStart) {
      case 0x42:
        print(
            "Event packet received from " + packet.address.address.toString());
        break;

      case 0x61:
        {
          globalStateSeqID =
              max(globalStateSeqID, getInt32FromBytes(packet.data, 1));
          // int nodeStartPlaytimestamp = getInt32FromBytes(packet.data, 5);
          /*
          print("Global state packet received  " +
              packet.data.toString() +
              ", seqId : " +
              globalStateSeqID.toString() +
              ", nodeStartPlaytime : " +
              nodeStartPlaytimestamp.toString());
              */
        }
        break;

      case 0x01: //node status
        {
          int nodeID = getInt32FromBytes(packet.data, 1);
          //int nodeGroupMask = getInt32FromBytes(packet.data, 5);
          int lastCommandID = packet.data[9];
          //int lastCommandIDCount = packet.data[10];
          //int nodeOn = packet.data[11];
          int nodeBank = packet.data[12];
          int nodeLocalTime = getInt32FromBytes(packet.data, 13);
          int nodeCurItemInSequence = getInt32FromBytes(packet.data, 17);
          int nodePixels = getInt32FromBytes(packet.data, 25);
          timestampAtSync = nodeLocalTime;
          //print("sync node with timestamp "+timestampAtSync.toString()+" / "+localtimestampAtSync.toString());
          packetSeqID = max(packetSeqID, lastCommandID + 1);

          String nodeName = "";
          String nodeShowName = "";
          String nodeMessage = "";

          int strIndex = 29;
          while (strIndex < packet.data.length - 1) {
            var infoName = String.fromCharCode(packet.data[strIndex]);
            int charIndex = strIndex + 1;
            String value = "";
            while (packet.data[charIndex] != 0) {
              value += String.fromCharCode(packet.data[charIndex]);
              charIndex++;
            }
            if (infoName == "N")
              nodeName = value;
            else if (infoName == "F")
              nodeShowName = value;
            else if (infoName == "M") nodeMessage = value;
            strIndex = charIndex + 1;
          }

          nodeManager.updateNode(
              packet.address,
              nodeID,
              nodeName,
              nodeBank,
              nodeCurItemInSequence,
              nodeShowName,
              nodeLocalTime,
              nodePixels,
              nodeMessage);
        }
        break;

      default:
        print("Unknown packet " +
            packetStart.toString() +
            " received from " +
            packet.address.address.toString());
        break;
    }
  }

  int getInt32FromBytes(Uint8List data, int startByte) {
    return data[startByte] |
        data[startByte + 1] << 8 |
        data[startByte + 2] << 16 |
        data[startByte + 3] << 24;
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

  List<int> getBytesFromDouble(
    double data,
  ) {
    var buffer = new Uint8List(8).buffer;
    var bdata = new ByteData.view(buffer);
    bdata.setFloat64(0, data);
    return buffer.asUint8List();
  }

  // HELPERS
  Future<List<InternetAddress>> getIPs() async {
    var result = new List<InternetAddress>();
    List<NetworkInterface> interfaces = await NetworkInterface.list(
        includeLoopback: false, type: InternetAddressType.any);
    interfaces.forEach((interface) {
      interface.addresses.forEach((address) {
        result.add(address);
      });
    });

    return result;
  }

  Future<InternetAddress> getFirstIP() async {
    List<InternetAddress> ips = await getIPs();
    if (ips.length == 0) return InternetAddress.loopbackIPv4;
    return ips[0];
  }
}
