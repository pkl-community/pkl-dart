# Pkl Dart Bindings (`pkl-dart`)

A Dart library for interacting with the [Pkl configuration language](https://github.com/apple/pkl). This project is
inspired by the official Pkl
language bindings, particularly [pkl-swift](https://github.com/apple/pkl) and [pkl-go](https://github.com/apple/pkl),
and aims to provide a similarly robust and ergonomic
experience for Dart.

> [!WARNING]
> This library is currently in an early, experimental stage and is not yet recommended for production use. The API is
> subject to change.

This package provides a high-level API to evaluate Pkl modules and deserialize them into strongly-typed Dart objects. It
communicates with the native Pkl command-line interface to perform evaluations.

## Features

- **Evaluate Pkl Modules**: Parse and evaluate Pkl modules from text, files, or URIs.
- **Type-Safe Deserialization**: Convert Pkl objects into your custom Dart classes with compile-time safety and helpful
  error messages.
- **Standard Type Support**: Automatically decodes Pkl primitives, collections, and standard library types (like
  `Duration` and `DataSize`) into their Dart equivalents.
- **Render Standard Outputs**: Easily evaluate a module's `output.text` and `output.files` for common rendering tasks.
- **Extensible**: Supports custom `ModuleReader` and `ResourceReader` implementations for advanced use cases.

## Getting Started

1. Make sure you have [Pkl cli](https://pkl-lang.org/main/current/pkl-cli/index.html#installation) installed.
2. Clone this repository.
3. Add it as dependency in your `pubspec.yaml`
   ```yaml 
   dependencies:
   pkl_dart: 
     path: <path to cloned repo>
   ```

4. Then, import the library in your Dart code:

```dart
import 'package:pkl_dart/pkl_dart.dart';
```

## Usage

The primary entry point to the library is the `Evaluator`. It's recommended to use the `withEvaluatorPreconfigured`
helper, which automatically manages the lifecycle of the underlying Pkl process.

### Basic Evaluation

You can evaluate a Pkl module and get back standard Dart types like `String`, `int`, `List`, and `Map`.

```dart
import 'package:pkl_dart/pkl_dart.dart';

Future<void> main() async {
  await withEvaluatorPreconfigured((evaluator) async {
    final module = ModuleSource.text('''
      name = "Pkl-Dart"
      version = 1
      features = List("Evaluation", "Deserialization")
    ''');

    // Evaluate the entire module into a Map
    final config = await evaluator.evaluateModule(module) as Map<String, dynamic>;
    print(config['name']); // Pkl-Dart

    // Evaluate a single expression
    final features = await evaluator.evaluateExpression(
      source: module,
      expression: 'features',
    ) as List;
    print(features.first); // Evaluation
  });
}
```

### Decoding to Custom Dart Objects

The most powerful feature is the ability to deserialize Pkl configurations directly into your own type-safe Dart
classes.

**1. Define your Pkl configuration (`config.pkl`)**

```pkl
// config.pkl
host = "localhost"
port = 8080

database {
  user = "admin"
  poolSize = 10
}
```

**2. Create corresponding Dart classes**

Your Dart classes must implement `PklDecodable` and provide a `fromPkl` factory. Use `PklObjectDecoder` for safe,
type-checked property access.

```dart
import 'package:pkl_dart/pkl_dart.dart';

// Nested object
class DatabaseConfig implements PklDecodable {
  final String user;
  final int poolSize;

  DatabaseConfig({required this.user, required this.poolSize});

  factory DatabaseConfig.fromPkl(Map<String, dynamic> map) {
    final decoder = PklObjectDecoder(map);
    return DatabaseConfig(
      user: decoder.decode('user'),
      poolSize: decoder.decode('poolSize'),
    );
  }
}

// Top-level object
class ServerConfig implements PklDecodable {
  final String host;
  final int port;
  final DatabaseConfig database;

  ServerConfig({
    required this.host,
    required this.port,
    required this.database,
  });

  factory ServerConfig.fromPkl(Map<String, dynamic> map) {
    final decoder = PklObjectDecoder(map);
    return ServerConfig(
      host: decoder.decode('host'),
      port: decoder.decode('port'),
      database: decoder.decodeObject('database', DatabaseConfig.fromPkl),
    );
  }
}
```

**3. Evaluate and deserialize**

Use `evaluateModuleAs` and pass your class's factory constructor. The library handles the rest.

```dart
import 'package:pkl_dart/pkl_dart.dart';
// Import your ServerConfig class...

Future<void> main() async {
  await withEvaluatorPreconfigured((evaluator) async {
    final config = await evaluator.evaluateModuleAs<ServerConfig>(
      source: ModuleSource.uri(Uri.parse('config.pkl')),
      fromPkl: ServerConfig.fromPkl,
    );

    print('Server will run on ${config.host}:${config.port}');
    print('Database user: ${config.database.user}');
  });
}
```

### Evaluating Module Output

Pkl modules can define standard `output` properties for rendering. You can evaluate these.

**Given `template.pkl`:**

```pkl
// template.pkl
name = "World"

output {
  text = "Hello, \(name)!"

  files {
    ["greeting.txt"] {
      text = "A greeting for \(name)."
    }
  }
}
```

**Evaluate `output.text` and `output.files`:**

```dart
Future<void> main() async {
  await withEvaluatorPreconfigured((evaluator) async {
    final source = ModuleSource.uri(Uri.parse('template.pkl'));

    // Evaluate the main text output
    final textOutput = await evaluator.evaluateOutputText(source);
    print(textOutput); // Hello, World!

    // Evaluate the file outputs
    final fileOutputs = await evaluator.evaluateOutputFiles(source);
    print(fileOutputs['greeting.txt']); // A greeting for World.
  });
}
```

## Error Handling

The library throws specific exceptions for different failure modes:

- **PklError**: A general error during Pkl evaluation (e.g., syntax error, validation failure).
- **PklDecodingException**: An error during deserialization into a Dart object (e.g., missing key, type mismatch).

## Upcoming Features

Future enhancements include:

- [ ] **Publish**: Add this package to [official dart/flutter package repository](https://pub.dev/)
- [ ]  **Project-Aware Evaluation**: Seamlessly evaluate modules within a Pkl Project, automatically handling
  dependencies and project-specific settings.
- [ ] **Code Generation**: Automatically generate type-safe Dart classes from your Pkl modules, reducing boilerplate and
  ensuring your Dart models are always in sync with your configuration.
- [ ] **CLI Command Integration**: Direct integration with more pkl CLI commands, such as pkl test for running project
  tests.

*Contributions for these and other features are welcome!*

## Contributing

Contributions are welcome! Please feel free to open an issue or submit a pull request.

## License

This project is licensed under the MIT License. See the LICENSE file for details.