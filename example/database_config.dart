import 'package:pkl_dart/pkl_dart.dart';

class DatabaseConfig implements PklDecodable {
  final String user;
  final int poolSize;

  DatabaseConfig({required this.user, required this.poolSize});

  factory DatabaseConfig.fromPkl(Map<String, dynamic> map) {
    final decoder = PklObjectDecoder(map);
    return DatabaseConfig(user: decoder.decode('user'), poolSize: decoder.decode('poolSize'));
  }
}

class ServerConfig implements PklDecodable {
  final String host;
  final int port;
  final DatabaseConfig database;

  ServerConfig({required this.host, required this.port, required this.database});

  factory ServerConfig.fromPkl(Map<String, dynamic> map) {
    final decoder = PklObjectDecoder(map);
    return ServerConfig(
      host: decoder.decode('host'),
      port: decoder.decode('port'),
      database: decoder.decodeObject('database', DatabaseConfig.fromPkl),
    );
  }
}
