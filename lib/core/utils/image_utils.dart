import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

ImageProvider? getAvatarProvider(String? photoUrl) {
  if (photoUrl == null || photoUrl.isEmpty) return null;
  if (photoUrl.startsWith('data:image/')) {
    final base64Str = photoUrl.split(',').last;
    final Uint8List bytes = base64Decode(base64Str);
    return MemoryImage(bytes);
  }
  return NetworkImage(photoUrl);
}
