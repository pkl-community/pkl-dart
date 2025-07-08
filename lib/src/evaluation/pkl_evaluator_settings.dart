// Copyright (c) 2025, the Pkl community authors. Please see the AUTHORS file
// for details. This source code is licensed under the MIT license found in the
// LICENSE file in the root directory of this source tree.

import 'dart:typed_data';
import 'package:equatable/equatable.dart';

import '../message.dart';
import '../serializer/pkl_data_model.dart';

/// The Dart representation of standard library module `pkl.EvaluatorSettings`.
class PklEvaluatorSettings extends Equatable {
  final Map<String, String>? externalProperties;
  final Map<String, String>? env;
  final List<String>? allowedModules;
  final List<String>? allowedResources;
  final bool? noCache;
  final List<String>? modulePath;
  final PklDuration? timeout;
  final String? moduleCacheDir;
  final String? rootDir;
  final Http? http;

  final Map<String, ExternalReader>? externalModuleReaders;

  final Map<String, ExternalReader>? externalResourceReaders;

  /// Whether to format messages and test results with ANSI color colors.
  final PklEvaluatorSettingsColor? color;

  const PklEvaluatorSettings({
    this.externalProperties,
    this.env,
    this.allowedModules,
    this.allowedResources,
    this.noCache,
    this.modulePath,
    this.timeout,
    this.moduleCacheDir,
    this.rootDir,
    this.http,
    this.externalModuleReaders,
    this.externalResourceReaders,
    this.color,
  });

  factory PklEvaluatorSettings.fromJson(Map<String, dynamic> json) {
    return PklEvaluatorSettings(
      externalProperties: json['externalProperties'] != null
          ? Map<String, String>.from(json['externalProperties'])
          : null,
      env: json['env'] != null ? Map<String, String>.from(json['env']) : null,
      allowedModules: json['allowedModules'] != null
          ? List<String>.from(json['allowedModules'])
          : null,
      allowedResources: json['allowedResources'] != null
          ? List<String>.from(json['allowedResources'])
          : null,
      noCache: json['noCache'] as bool?,
      modulePath: json['modulePath'] != null ? List<String>.from(json['modulePath']) : null,
      timeout: json['timeout'] != null ? PklDuration.fromPkl(json['timeout']) : null,
      moduleCacheDir: json['moduleCacheDir'] as String?,
      rootDir: json['rootDir'] as String?,
      http: json['http'] != null ? Http.fromJson(json['http']) : null,
      externalModuleReaders: json['externalModuleReaders'] != null
          ? (json['externalModuleReaders'] as Map<String, dynamic>).map(
              (k, v) => MapEntry(k, ExternalReader.fromJson(v)),
            )
          : null,
      externalResourceReaders: json['externalResourceReaders'] != null
          ? (json['externalResourceReaders'] as Map<String, dynamic>).map(
              (k, v) => MapEntry(k, ExternalReader.fromJson(v)),
            )
          : null,
      color: json['color'] != null ? PklEvaluatorSettingsColor.fromString(json['color']) : null,
    );
  }

  @override
  List<Object?> get props => [
    externalProperties,
    env,
    allowedModules,
    allowedResources,
    noCache,
    modulePath,
    timeout,
    moduleCacheDir,
    rootDir,
    http,
    externalModuleReaders,
    externalResourceReaders,
    color,
  ];

  Map<String, dynamic> toJson() {
    return {
      'externalProperties': externalProperties,
      'env': env,
      'allowedModules': allowedModules,
      'allowedResources': allowedResources,
      'noCache': noCache,
      'modulePath': modulePath,
      'timeout': timeout?.value,
      'moduleCacheDir': moduleCacheDir,
      'rootDir': rootDir,
      'http': http?.toJson(),
      'externalModuleReaders': externalModuleReaders?.map((k, v) => MapEntry(k, v.toJson())),
      'externalResourceReaders': externalResourceReaders?.map((k, v) => MapEntry(k, v.toJson())),
      'color': color?.value,
    };
  }
}

enum PklEvaluatorSettingsColor {
  /// Never format.
  never('never'),

  /// Format if the process' stdin, stdout, or stderr are connected to a console.
  auto('auto'),

  /// Always format.
  always('always');

  const PklEvaluatorSettingsColor(this.value);

  final String value;

  static PklEvaluatorSettingsColor? fromString(String value) {
    for (final color in PklEvaluatorSettingsColor.values) {
      if (color.value == value) return color;
    }
    return null;
  }

  @override
  String toString() => value;
}

/// Settings that control how Pkl talks to HTTP(S) servers.
class Http extends Equatable {
  /// PEM format certificates to trust when making HTTP requests.
  ///
  /// If empty, Pkl will trust its own built-in certificates.
  final Uint8List? caCertificates;

  /// Configuration of the HTTP proxy to use.
  ///
  /// If `null`, uses the operating system's proxy configuration.
  final Proxy? proxy;

  const Http({this.caCertificates, this.proxy});

  factory Http.fromJson(Map<String, dynamic> json) {
    return Http(
      caCertificates: json['caCertificates'] != null
          ? Uint8List.fromList(List<int>.from(json['caCertificates']))
          : null,
      proxy: json['proxy'] != null ? Proxy.fromJson(json['proxy']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {'caCertificates': caCertificates?.toList(), 'proxy': proxy?.toJson()};
  }

  @override
  List<Object?> get props => [caCertificates, proxy];

  Map<String, dynamic> propertiesMap() {
    final map = toJson();
    map.removeWhere((key, value) => value == null);

    return map;
  }
}

/// Settings that control how Pkl talks to HTTP proxies.
class Proxy extends Equatable {
  /// The proxy to use for HTTP(S) connections.
  ///
  /// Only HTTP proxies are supported.
  /// The address must start with `"http://"`, and cannot contain anything other than a host and an optional port.
  ///
  /// Example:
  /// ```
  /// "http://my.proxy.example.com:5080"
  /// ```
  final String? address;

  /// Hosts to which all connections should bypass a proxy.
  ///
  /// Values can be either hostnames, or IP addresses.
  /// IP addresses can optionally be provided using
  /// [CIDR notation](https://en.wikipedia.org/wiki/Classless_Inter-Domain_Routing#CIDR_notation).
  ///
  /// The value `"*"` is a wildcard that disables proxying for all hosts.
  ///
  /// A hostname matches all subdomains.
  /// For example, `example.com` matches `foo.example.com`, but not `fooexample.com`.
  /// A hostname that is prefixed with a dot matches the hostname itself,
  /// so `.example.com` matches `example.com`.
  ///
  /// Hostnames do not match their resolved IP addresses.
  /// For example, the hostname `localhost` will not match `127.0.0.1`.
  ///
  /// Optionally, a port can be specified.
  /// If a port is omitted, all ports are matched.
  ///
  /// Example:
  ///
  /// ```
  /// [ "127.0.0.1",
  ///   "169.254.0.0/16",
  ///   "example.com",
  ///   "localhost:5050" ]
  /// ```
  final List<String>? noProxy;

  const Proxy({this.address, this.noProxy});

  factory Proxy.fromJson(Map<String, dynamic> json) {
    return Proxy(
      address: json['address'] as String?,
      noProxy: json['noProxy'] != null ? List<String>.from(json['noProxy']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {'address': address, 'noProxy': noProxy};
  }

  @override
  List<Object?> get props => [address, noProxy];
}
