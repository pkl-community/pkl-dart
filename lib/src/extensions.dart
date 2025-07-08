// Copyright (c) 2025, the Pkl community authors. Please see the AUTHORS file
// for details. This source code is licensed under the MIT license found in the
// LICENSE file in the root directory of this source tree.

extension MapExtension on Map<String, dynamic> {
  /// Add key/value to map if value is not null.
  /// Return the modified map.
  Map<String, dynamic> addIfNotNull(String key, dynamic value) {
    if (value != null) {
      this[key] = value;
    }
    return this;
  }
}
