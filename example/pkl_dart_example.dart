import 'dart:io';

import 'package:pkl_dart/pkl_dart.dart';

import 'database_config.dart';

Future<void> main() async {
  /// Decoding to custom dart objects
  await Evaluator.run((evaluator) async {
    final configUri = Directory.current.uri.resolve('example/config.pkl');
    final config = await evaluator.evaluateModuleAs<ServerConfig>(
      source: ModuleSource.uri(configUri),
      fromPkl: ServerConfig.fromPkl,
    );

    print('Server will run on ${config.host}:${config.port}');
    print('Database user: ${config.database.user}');
  });

  final classes = await Evaluator.run((e) {
    final module = ModuleSource.text("""
     module Classes

         animals: Listing<Animal> = new {
         new { name = "Uni" }
         new { name = "Wally" }
         new { name = "Mouse" }
         }
         
         age = 23

         class Animal {
         name: String
         }""");

    return e.evaluateModuleAs<Classes>(source: module, fromPkl: Classes.fromPkl);
  });

  print(classes);

  /// Decoding to standard Dart types.
  await Evaluator.run((evaluator) async {
    final module = ModuleSource.text('''
      name = "Pkl-Dart"
      version = 1
      features = List("Evaluation", "Deserialization")
    ''');

    // Evaluate the entire module into a Map
    final config = await evaluator.evaluateModule(module) as Map<String, dynamic>;
    print(config['name']); // Pkl-Dart

    // Evaluate a single expression
    final features =
        await evaluator.evaluateExpression(source: module, expression: 'features') as List;
    print(features.first); // Evaluation
  });

  final manager = await EvaluatorManager.spawn();
  final evaluator = await manager.newEvaluator();
  final module = ModuleSource.text("age = 30; hobbies = List(\"swimming\", \"surfing\")");
  final result = await evaluator.evaluateModule(module);
  print(result);
  manager.close();

  final m = await Evaluator.run((e) {
    final module = ModuleSource.text("""
      module MyModule

      // Type Aliases
      typealias City = "San Francisco"|"Tokyo"|"Zurich"

      // Inheritance
      abstract class Being {
        exists: Boolean = true
      }

      open class Animal extends Being {
        name: String
      }

      open class Dog extends Animal {
        barks: Boolean
      }
      
      // Top-level properties and complex types
      res1: List<List<Int>> = List(List(1), List(2))
      res2: Mapping<String, Dog> = new {
        ["rex"] = new Dog {
          name = "Rex"
          barks = true
        }
      }
      """);

    return e.evaluateModule(module);
  });

  print(m);
}

class Animal implements PklDecodable {
  final String name;

  Animal({required this.name});

  factory Animal.fromPkl(Map<String, dynamic> map) {
    final decoder = PklObjectDecoder(map);

    return Animal(name: decoder.decode('name'));
  }

  @override
  String toString() {
    return 'Animal(name: $name)';
  }
}

class Classes extends PklDecodable {
  final List<Animal> animals;

  Classes({required this.animals});

  factory Classes.fromPkl(Map<String, dynamic> map) {
    final decoder = PklObjectDecoder(map);
    final decodedAnimals = decoder.decodeList<Map<dynamic, dynamic>>('animals');
    final animals = decodedAnimals.map((e) => Animal.fromPkl(e.cast())).toList();

    return Classes(animals: animals);
  }

  @override
  String toString() {
    return 'Classes(animals: $animals)';
  }
}
