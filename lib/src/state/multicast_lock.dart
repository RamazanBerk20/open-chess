import 'dart:io';

import 'package:flutter/services.dart';

const _channel = MethodChannel('open_chess/multicast');
int _holders = 0;

/// Hold Android's Wi-Fi multicast lock only while LAN discovery is active
/// (browsing, or a lobby waiting to be found). Reference-counted; a no-op on
/// other platforms.
void acquireMulticast() {
  if (!Platform.isAndroid) return;
  if (_holders++ == 0) _channel.invokeMethod<void>('acquire').ignore();
}

void releaseMulticast() {
  if (!Platform.isAndroid || _holders == 0) return;
  if (--_holders == 0) _channel.invokeMethod<void>('release').ignore();
}
