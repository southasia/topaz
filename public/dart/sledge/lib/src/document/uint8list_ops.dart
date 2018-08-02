// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:collection/collection.dart';

// TODO: consider short function names and importing with prefix.

/// Concatenate two byte arrays.
Uint8List concatUint8Lists(Uint8List a, Uint8List b) {
  return new Uint8List(a.length + b.length)..setAll(0, a)..setAll(a.length, b);
}

// TODO: consider using Iterable instead of List.
/// Concatenate list of byte arrays.
Uint8List concatListOfUint8Lists(List<Uint8List> list) {
  int sumLength = 0;
  for (final x in list) {
    sumLength += x.length;
  }
  final result = new Uint8List(sumLength);
  int pos = 0;
  for (final x in list) {
    result.setAll(pos, x);
    pos += x.length;
  }
  return result;
}

/// Returns the prefix of [x] of length [prefixLen].
Uint8List getUint8ListPrefix(Uint8List x, int prefixLen) {
  return new Uint8List(prefixLen)..setAll(0, x.getRange(0, prefixLen));
}

/// Returns the suffix of [x] starting from [prefixLen].
Uint8List getUint8ListSuffix(Uint8List x, int prefixLen) {
  return new Uint8List(x.length - prefixLen)
    ..setAll(0, x.getRange(prefixLen, x.length));
}

/// Returns a Uint8List created from the utf8 encoding of [string].
/// [string] must be non-null.
Uint8List getUint8ListFromString(String string) {
  assert(string != null);
  List<int> encodedString = new List<int>.from(utf8.encode(string));
  return new Uint8List.fromList(encodedString);
}

/// Returns a new HashMap with Uint8Lists as a keys.
/// Note: The type T is enforced only at compile time.
HashMap<Uint8List, T> newUint8ListMap<T>() {
  const listEquality = const ListEquality<int>();
  return new HashMap<Uint8List, T>(
      equals: listEquality.equals, hashCode: listEquality.hash);
}
