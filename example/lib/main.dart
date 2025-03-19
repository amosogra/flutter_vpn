/// Copyright (C) 2018-2022 Jason C.H
///
/// This library is free software; you can redistribute it and/or
/// modify it under the terms of the GNU Lesser General Public
/// License as published by the Free Software Foundation; either
/// version 2.1 of the License, or (at your option) any later version.
///
/// This library is distributed in the hope that it will be useful,
/// but WITHOUT ANY WARRANTY; without even the implied warranty of
/// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
/// Lesser General Public License for more details.
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_alert/flutter_platform_alert.dart';
import 'package:flutter_vpn/flutter_vpn.dart';
import 'package:flutter_vpn/state.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  var vpnConnectionDuration = '00:00:00';
  final _addressController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  var state = FlutterVpnState.disconnected;
  CharonErrorState? charonState = CharonErrorState.NO_ERROR;

  @override
  void initState() {
    FlutterVpn.prepare(platformAlert: alert);
    FlutterVpn.onStateChanged.listen((s) => setState(() => state = s));

    // Update UI every second
    Timer.periodic(Duration(seconds: 1), (timer) async {
      final duration = await FlutterVpn.vpnConnectionDuration;
      var currentDuration = formatDuration(duration);
      setState(() {
        vpnConnectionDuration = currentDuration;
      });
    });
    super.initState();
  }

  static String formatDuration(Duration? duration) {
    if (duration == null || duration.inSeconds <= 0) return '00:00:00';

    return [
      duration.inHours.toString().padLeft(2, '0'),
      (duration.inMinutes.remainder(60)).toString().padLeft(2, '0'),
      (duration.inSeconds.remainder(60)).toString().padLeft(2, '0')
    ].join(':');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Flutter VPN'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(12),
          children: <Widget>[
            Text('Connection Duration: $vpnConnectionDuration'),
            Text('Current State: $state'),
            Text('Current Charon State: $charonState'),
            TextFormField(
              controller: _addressController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(icon: Icon(Icons.map_outlined)),
            ),
            TextFormField(
              controller: _usernameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                icon: Icon(Icons.person_outline),
              ),
            ),
            TextFormField(
              controller: _passwordController,
              textInputAction: TextInputAction.done,
              obscureText: true,
              decoration: const InputDecoration(icon: Icon(Icons.lock_outline)),
            ),
            ElevatedButton(
              child: const Text('Connect'),
              onPressed: () => FlutterVpn.connectIkev2EAP(
                server: _addressController.text,
                username: _usernameController.text,
                password: _passwordController.text,
              ),
            ),
            ElevatedButton(
              child: const Text('Disconnect'),
              onPressed: () => FlutterVpn.disconnect(),
            ),
            ElevatedButton(
              onPressed: getCurrentState,
              child: const Text('Update State'),
            ),
            ElevatedButton(
              onPressed: getCharonErrorState,
              child: const Text('Update Charon State'),
            ),
          ],
        ),
      ),
    );
  }

  getCharonErrorState() async {
    var newState = await FlutterVpn.charonErrorState;
    setState(() => charonState = newState);
  }

  getCurrentState() async {
    var newState = await FlutterVpn.currentState;
    setState(() => state = newState);
  }

  Widget adaptiveAction({required BuildContext context, required VoidCallback onPressed, required Widget child}) {
    final ThemeData theme = Theme.of(context);
    switch (theme.platform) {
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return TextButton(onPressed: onPressed, child: child);
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return CupertinoDialogAction(onPressed: onPressed, child: child);
    }
  }

  Future<bool> alert() async {
    var result = await showAdaptiveDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog.adaptive(
        title: const Text('VPN Permission Instruction'),
        content: const Text('Please accept in order for the VPN to enable connection.'),
        actions: <Widget>[
          adaptiveAction(
            context: context,
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          adaptiveAction(
            context: context,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<bool> platformAlert() async {
    await FlutterPlatformAlert.playAlertSound();
    return await FlutterPlatformAlert.showCustomAlert(
      windowTitle: 'VPN Permission Instruction',
      text: 'Please accept in order for the VPN to enable connection.',
      positiveButtonTitle: "Cancel",
      negativeButtonTitle: "Continue",
    ).then((value) async {
      switch (value.name) {
        case 'Cancel':
          return false;
        case 'Continue':
          return true;
        default:
          return false;
      }
    });
  }
}
