// Copyright (c) 2025, the Pkl community authors. Please see the AUTHORS file
// for details. This source code is licensed under the MIT license found in the
// LICENSE file in the root directory of this source tree.

import 'package:pkl_dart/src/serializer/pkl_decodable.dart';

class OpenModule implements PklDecodable {
  final int bar;

  OpenModule({required this.bar});

  factory OpenModule.fromMap(Map<String, dynamic> map) {
    return OpenModule(bar: map['bar'] as int);
  }
}

class ExtendsOpenModule extends OpenModule {
  final String foo;

  ExtendsOpenModule({required this.foo, required super.bar});

  factory ExtendsOpenModule.fromMap(Map<String, dynamic> map) {
    return ExtendsOpenModule(foo: map['foo'] as String, bar: map['bar'] as int);
  }
}
