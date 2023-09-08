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
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_platform_alert/flutter_platform_alert.dart';
import 'package:flutter_vpn/state.dart';

import 'flutter_vpn_platform_interface.dart';

/// An implementation of [FlutterVpnPlatform] that uses method channels.
class MethodChannelFlutterVpn extends FlutterVpnPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_vpn');

  /// The method channel used to receive state change event.
  @visibleForTesting
  final eventChannel = const EventChannel('flutter_vpn_states');

  /// Receive state change from VPN service.
  ///
  /// Can only be listened once. If have more than one subscription, only the
  /// last subscription can receive events.
  @override
  Stream<FlutterVpnState> get onStateChanged => eventChannel.receiveBroadcastStream().map((e) => FlutterVpnState.values[e]);

  /// Get current state.
  @override
  Future<FlutterVpnState> get currentState async {
    final state = await methodChannel.invokeMethod<int>('getCurrentState');
    assert(state != null, 'Received a null state from `getCurrentState` call.');
    return FlutterVpnState.values[state!];
  }

  /// Get current error state from `VpnStateService`. (Android only)
  /// When [FlutterVpnState.error] is received, details of error can be
  /// inspected by [CharonErrorState]. Returns [null] on non-android platform.
  @override
  Future<CharonErrorState?> get charonErrorState async {
    if (!Platform.isAndroid) return null;
    var state = await methodChannel.invokeMethod<int>('getCharonErrorState');
    assert(
      state != null,
      'Received a null state from `getCharonErrorState` call.',
    );
    return CharonErrorState.values[state!];
  }

  /// Prepare for vpn connection.
  ///
  /// For first connection it will show a dialog to ask for permission.
  /// When your connection was interrupted by another VPN connection,
  /// you should prepare again before reconnect.
  @override
  Future<bool> prepare({Future<bool> Function()? platformAlert}) async {
    //if (!Platform.isAndroid) return true;
    if (await prepared) {
      checkState();
      return true;
    } else {
      return await (platformAlert?.call() ?? _platformAlert.call()).then((value) async {
        switch (value) {
          case false:
            return false;
          case true:
            var isPrepared = await methodChannel.invokeMethod<bool>('prepare') ?? false;
            if (!isPrepared) {
              if (await _platformAlert()) {
                return await prep();
              } else {
                return await prepare(platformAlert: platformAlert);
              }
            }
            return true;
          default:
            return false;
        }
      });
    }
  }

  /* Future<bool> _platformAlert() async {
    await FlutterPlatformAlert.playAlertSound();
    return await FlutterPlatformAlert.showCustomAlert(
      windowTitle: 'VPN Permission Instruction',
      text: 'Please accept in order for the VPN to enable connection.',
      positiveButtonTitle: "Enable VPN",
    ).then((value) async {
      return await prep();
    });
  } */

  Future<bool> _platformAlert() async {
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

  Future<bool> prep() async {
    var isPrepared = await methodChannel.invokeMethod<bool>('prepare') ?? false;
    return isPrepared;
  }

  /// Check if vpn connection has been prepared.
  @override
  Future<bool> get prepared async {
    //if (!Platform.isAndroid) return true;
    return (await methodChannel.invokeMethod<bool>('prepared'))!;
  }

  Future<void> checkState() async {
    await methodChannel.invokeMethod('checkState');
  }

  /// Disconnect and stop VPN service.
  @override
  Future<void> disconnect() async {
    await methodChannel.invokeMethod('disconnect');
  }

  /// Connect to VPN. (IKEv2-EAP)
  ///
  /// This will create a background VPN service.
  /// MTU is only available on android.
  @override
  Future<void> connectIkev2EAP({
    required String server,
    required String username,
    required String password,
    String? name,
    int? mtu,
    int? port,
  }) async {
    if (!(await prepared)) {
      prepare();
    }
    await methodChannel.invokeMethod('connect', {
      'Type': 'IKEv2',
      'Server': server,
      'Username': username,
      'Password': password,
      'Secret': '',
      'Name': name ?? server,
      if (mtu != null) 'mtu': mtu,
      if (port != null) 'port': port,
    });
  }

  /// Connect to VPN. (IPSec)
  ///
  /// This will create a background VPN service.
  /// Android implementation is not available.
  @override
  Future<void> connectIPSec({
    required String server,
    required String username,
    required String password,
    required String secret,
    String? name,
    int? mtu,
    int? port,
  }) async {
    if (!(await prepared)) {
      prepare();
    }
    await methodChannel.invokeMethod('connect', {
      'Type': 'IPSec',
      'Server': server,
      'Username': username,
      'Password': password,
      'Secret': secret,
      'Name': name ?? server,
      if (mtu != null) 'mtu': mtu,
      if (port != null) 'port': port,
    });
  }
}
