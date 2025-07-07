import 'dart:io';

import 'package:pkl_dart/pkl_dart.dart';
import 'package:pkl_dart/src/serializer/pkl_data_model.dart';
import 'package:test/test.dart';

import 'models/animal.dart';
import 'models/module.dart';
import 'models/poly.dart' as poly;
import 'models/unions.dart' as unions;

void main() {
  final fixturesUri = Directory.current.uri.resolve('test/fixtures/');

  group('Pkl Evaluation Tests', () {
    test('decodes classes and primitives from classes.pkl', () async {
      await withEvaluatorPreconfigured((evaluator) async {
        final source = ModuleSource.uri(fixturesUri.resolve('classes.pkl'));

        final age = await evaluator.evaluateExpression(source: source, expression: 'age');
        expect(age, 23);

        final animals = await evaluator.evaluateExpression(source: source, expression: 'animals');
        expect(animals, isA<List>());
        final animalList = (animals as List)
            .map((it) => Animal.fromPkl(it as Map<String, dynamic>))
            .toList();
        expect(animalList, [
          const Animal(name: 'Uni'),
          const Animal(name: 'Wally'),
          const Animal(name: 'Mouse'),
        ]);
      });
    });

    test('decodes various Any types from any.pkl', () async {
      await withEvaluatorPreconfigured((evaluator) async {
        final source = ModuleSource.uri(fixturesUri.resolve('any.pkl'));

        expect(await evaluator.evaluateExpression(source: source, expression: 'bird'), {
          'species': 'Owl',
        });
        expect(await evaluator.evaluateExpression(source: source, expression: 'primitive'), 'foo');
        expect(await evaluator.evaluateExpression(source: source, expression: 'primitive2'), 12);
        expect(await evaluator.evaluateExpression(source: source, expression: 'array'), [1, 2]);
        expect(await evaluator.evaluateExpression(source: source, expression: 'set'), {5, 6});
        expect(await evaluator.evaluateExpression(source: source, expression: 'mapping'), {
          '1': 12,
          12: '1',
        });
        expect(await evaluator.evaluateExpression(source: source, expression: 'nullable'), isNull);
        expect(
          await evaluator.evaluateModuleAs<PklDuration>(
            source: source,
            fromPkl: PklDuration.fromPkl,
            expression: 'duration',
          ),
          PklDuration.minutes(5),
        );

        expect(await evaluator.evaluateExpression(source: source, expression: 'duration'), {
          'value': 5.0,
          'unit': 'min',
        });

        expect(await evaluator.evaluateExpression(source: source, expression: 'dataSize'), {
          'value': 10.0,
          'unit': 'mb',
        });
        expect(
          await evaluator.evaluateModuleAs<DataSize>(
            source: source,
            fromPkl: DataSize.fromPkl,
            expression: 'dataSize',
          ),
          DataSize.megabytes(10.0),
        );
      });
    });

    test('decodes various collection types from collections.pkl', () async {
      await withEvaluatorPreconfigured((evaluator) async {
        final source = ModuleSource.uri(fixturesUri.resolve('collections.pkl'));

        expect(await evaluator.evaluateExpression(source: source, expression: 'res1'), [1, 2, 3]);
        expect(await evaluator.evaluateExpression(source: source, expression: 'res2'), [2, 3, 4]);
        expect(await evaluator.evaluateExpression(source: source, expression: 'res3'), [
          [1],
          [2],
          [3],
        ]);
        expect(await evaluator.evaluateExpression(source: source, expression: 'res4'), [
          [1],
          [2],
          [3],
        ]);
        expect(await evaluator.evaluateExpression(source: source, expression: 'res5'), {
          1: true,
          2: false,
        });
        expect(await evaluator.evaluateExpression(source: source, expression: 'res6'), {
          1: {1: true},
          2: {2: true},
          3: {3: true},
        });
        expect(await evaluator.evaluateExpression(source: source, expression: 'res7'), {
          1: true,
          2: false,
        });
        expect(await evaluator.evaluateExpression(source: source, expression: 'res8'), {
          1: {1: true},
          2: {2: false},
        });
        expect(await evaluator.evaluateExpression(source: source, expression: 'res9'), {
          'one',
          'two',
          'three',
        });
        expect(await evaluator.evaluateExpression(source: source, expression: 'res10'), {1, 2, 3});
      });
    });

    test('evaluates a module that extends an open module', () async {
      await withEvaluatorPreconfigured((evaluator) async {
        final source = ModuleSource.uri(fixturesUri.resolve('openModule.pkl'));
        final result = await evaluator.evaluateModule(source) as Map<String, dynamic>;
        expect(result['bar'], 0);
        final mod = await evaluator.evaluateModuleAs<OpenModule>(
          source: source,
          fromPkl: OpenModule.fromMap,
        );
        expect(mod.bar, 0);
      });
      await withEvaluatorPreconfigured((evaluator) async {
        final source = ModuleSource.uri(fixturesUri.resolve('extendsOpenModule.pkl'));
        final result = await evaluator.evaluateModule(source) as Map<String, dynamic>;
        expect(result['foo'], 'foo');
        expect(result['bar'], 10);

        final exMod = await evaluator.evaluateModuleAs<ExtendsOpenModule>(
          source: source,
          fromPkl: ExtendsOpenModule.fromMap,
        );
        expect(exMod.foo, 'foo');
        expect(exMod.bar, 10);
      });
    });

    test('decodes polymorphic objects from poly.pkl', () async {
      await withEvaluatorPreconfigured((evaluator) async {
        final source = ModuleSource.uri(fixturesUri.resolve('poly.pkl'));

        final beingsResult =
            await evaluator.evaluateExpression(source: source, expression: 'beings') as List;
        final beings = beingsResult
            .map((it) => poly.Being.fromPkl(it as Map<String, dynamic>))
            .toList();
        expect(beings, [
          const poly.Animal(name: 'Lion'),
          const poly.Dog(name: 'Ruuf', barks: true, hates: null),
          const poly.Bird(name: 'Duck', flies: false),
        ]);

        final rex = await evaluator.evaluateExpressionAs<poly.Dog>(
          source: source,
          expression: 'rex',
          fromPkl: poly.Dog.fromPkl,
        );
        expect(rex, const poly.Dog(name: 'Rex', barks: false, hates: null));

        // Decode  mapping of polymorphic objects
        final moreBeingsResult =
            await evaluator.evaluateExpression(source: source, expression: 'moreBeings') as Map;
        final moreBeings = moreBeingsResult.map(
          (k, v) => MapEntry(k, poly.Being.fromPkl(v as Map<String, dynamic>)),
        );
        expect(moreBeings['duck'], const poly.Bird(name: 'Ducky', flies: true));
        expect(
          moreBeings['dog'],
          const poly.Dog(
            name: 'TRex',
            barks: false,
            hates: poly.Animal(name: 'Rex'),
          ),
        );
      });
    });

    test('decodes union types from unions.pkl', () async {
      await withEvaluatorPreconfigured((evaluator) async {
        final source = ModuleSource.uri(fixturesUri.resolve('unions.pkl'));

        // Test class-based unions
        expect(
          await evaluator.evaluateExpressionAs<unions.Fruit>(
            source: source,
            expression: 'fruit1',
            fromPkl: unions.Fruit.fromPkl,
          ),
          const unions.Banana(isRipe: true),
        );
        expect(
          await evaluator.evaluateExpressionAs<unions.Fruit>(
            source: source,
            expression: 'fruit2',
            fromPkl: unions.Fruit.fromPkl,
          ),
          const unions.Grape(isUsedForWine: true),
        );
        expect(
          await evaluator.evaluateExpressionAs<unions.Fruit>(
            source: source,
            expression: 'fruit3',
            fromPkl: unions.Fruit.fromPkl,
          ),
          const unions.Apple(isRed: false),
        );

        // Test string literal unions
        expect(
          await evaluator.evaluateExpression(source: source, expression: 'city1'),
          'San Francisco',
        );
        expect(await evaluator.evaluateExpression(source: source, expression: 'city4'), 'London');

        // Test unions of different kinds (class and primitive)
        final animalOrString1 = await evaluator.evaluateExpression(
          source: source,
          expression: 'animalOrString1',
        );
        expect(
          unions.UnionAnimal.fromPkl(animalOrString1 as Map<String, dynamic>),
          const unions.Zebra(),
        );

        final animalOrString2 = await evaluator.evaluateExpression(
          source: source,
          expression: 'animalOrString2',
        );
        expect(animalOrString2, 'Zebra');

        // Test numeric unions
        expect(await evaluator.evaluateExpression(source: source, expression: 'intOrFloat1'), 5);
        expect(await evaluator.evaluateExpression(source: source, expression: 'intOrFloat2'), 5.5);
      });
    });

    test('evaluates output.text and output.files from outputs.pkl', () async {
      await withEvaluatorPreconfigured((evaluator) async {
        final source = ModuleSource.uri(fixturesUri.resolve('outputs.pkl'));

        final text = await evaluator.evaluateOutputText(source);
        expect(text, 'Hello from Pkl!');

        final files = await evaluator.evaluateOutputFiles(source);
        expect(files, isA<Map<String, String>>());
        expect(files, {
          'file1.txt': 'This is the content of file 1.',
          'config/app.json': '''
{
  "name": "Pkl App",
  "version": "1.0.0"
}
''',
        });
      });
    });
  });
}
