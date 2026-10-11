import 'dart:convert';
import 'package:flutter/material.dart';

// Profile photos are stored inline as base64. Decoding one and wrapping it
// in a new MemoryImage on every rebuild made each build decode the picture
// again (a new MemoryImage never hits the image cache), so keep one provider
// per photo.
final _avatars = <String, ImageProvider>{};

ImageProvider? getAvatarProvider(String? photoUrl) {
  if (photoUrl == null || photoUrl.isEmpty) return null;
  final cached = _avatars[photoUrl];
  if (cached != null) return cached;
  final ImageProvider provider;
  if (photoUrl.startsWith('data:image/')) {
    try {
      provider = MemoryImage(base64Decode(photoUrl.split(',').last));
    } catch (_) {
      return null;
    }
  } else {
    provider = NetworkImage(photoUrl);
  }
  // Family photos are few; a small cap keeps memory in check.
  if (_avatars.length >= 32) _avatars.remove(_avatars.keys.first);
  _avatars[photoUrl] = provider;
  return provider;
}
