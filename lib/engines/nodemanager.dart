import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'node.dart';

class NodeManager {
  List<Node> nodes = new List<Node>();
  StreamController<NodeEvent> nodeStream =
      StreamController<NodeEvent>.broadcast();

  Timer managerTimer;
  final int nodeTimeout =
      4000; //10 seconds to timeout, broadcast if fucking up latency

  NodeManager() {
    managerTimer = Timer.periodic(Duration(seconds: 1), managerTimerCallback);
  }

  Node updateNode(
      InternetAddress nodeIP,
      int id,
      String name,
      int bank,
      int curItemInSequence,
      String showName,
      int localTime,
      int numPixels,
      String message) {
    Node n = getNodeWithID(id);
    bool nodeAlreadyExists = n != null;
    //print("Update node " + name.toString());
    if (!nodeAlreadyExists) {
      n = new Node(nodeIP, id, name, bank, curItemInSequence, showName,
          localTime, numPixels);
      nodes.add(n);
      nodeStream.add(NodeEvent(NodeEventType.NodeAdded, n));
    } else {
      n.name = name;
      n.ip = nodeIP;
      n.showName = showName;
      n.bank = bank;
      n.curItemInSequence = curItemInSequence;
      n.localTime = localTime;
      n.numPixels = numPixels;
      n.setMessage(message);

      if (!n.isConnected) {
        n.isConnected = true;
        nodeStream.add(NodeEvent(NodeEventType.NodeConnected, n));
      }

      n.timeAtLastPing = DateTime.now().millisecondsSinceEpoch;
      nodeStream.add(NodeEvent(NodeEventType.NodeUpdated, n));
    }

    return n;
  }

  void removeNode(Node node) {
    nodes.remove(node);
    nodeStream.add(NodeEvent(NodeEventType.NodeRemoved, node));
  }

  Node getNodeWithID(id) {
    for (var n in nodes) if (n.id == id) return n;
    return null;
  }

  int getNumConnectedNode() {
    int result = 0;
    for (var n in nodes) if (n.isConnected) result++;
    return result;
  }

  void managerTimerCallback(Timer t) {
    int curTime = DateTime.now().millisecondsSinceEpoch;
    for (var n in nodes) {
      if (n.isConnected) {
        if (curTime > n.timeAtLastPing + nodeTimeout) {
          n.isConnected = false;
          n.timeAtDisconnected = curTime;
          nodeStream.add(NodeEvent(NodeEventType.NodeDisconnected, n));
        }
      }
    }
  }

  void sendWifiCredentials(String ssid, String pass) {
    if (ssid.isEmpty) {
      toastError("SSID can not be empty !");
      return;
    }

    if (pass.isEmpty) {
      toastError("Pass can not be empty !");
      return;
    }

    Fluttertoast.showToast(
        msg:
            "Sending Wifi settings : " + ssid + " : " + pass + " to all nodes");
    for (var n in nodes) n.sendWifiCredentials(ssid, pass);
  }

  void toastError(msg) {
    Fluttertoast.showToast(
        msg: msg, backgroundColor: Colors.red, textColor: Colors.red[100]);
  }
}
