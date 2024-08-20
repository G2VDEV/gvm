import 'dart:io';

import 'package:gvm/src/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

class _MockLogger extends Mock implements Logger {}

class _MockFile extends Mock implements File {}

class _MockDirectory extends Mock implements Directory {}

void main() {
  group('global', () {
    late Logger logger;
    late GvmCommandRunner commandRunner;
    late Directory homeDirectory;

    setUp(() {
      logger = _MockLogger();
      commandRunner = GvmCommandRunner(logger: logger);
      homeDirectory = _MockDirectory();
      when(() => homeDirectory.path).thenReturn('/home/user');
      // Set the HOME environment variable for testing
      final originalHome = Platform.environment['HOME'];
      try {
        Platform.environment['HOME'] = '/home/user';
      } finally {
        addTearDown(() {
          if (originalHome != null) {
            Platform.environment['HOME'] = originalHome;
          } else {
            Platform.environment.remove('HOME');
          }
        });
      }
    });

    test('sets global version', () async {
      final globalVersionFile = _MockFile();
      when(() => globalVersionFile.writeAsString(any()))
          .thenAnswer((_) async => globalVersionFile);
      when(() => File(path.join('/home/user', '.gvm', 'global_version')))
          .thenReturn(globalVersionFile);

      final result = await commandRunner.run(['global', '4.0.0']);

      expect(result, equals(ExitCode.success.code));
      verify(() => globalVersionFile.writeAsString('4.0.0')).called(1);
      verify(() => logger.success('Global Godot version set to 4.0.0'))
          .called(1);
    });

    test('gets current global version', () async {
      final globalVersionFile = _MockFile();
      when(globalVersionFile.existsSync).thenReturn(true);
      when(globalVersionFile.readAsString).thenAnswer((_) async => '3.5.1');
      when(() => File(path.join('/home/user', '.gvm', 'global_version')))
          .thenReturn(globalVersionFile);

      final result = await commandRunner.run(['global']);

      expect(result, equals(ExitCode.success.code));
      verify(() => logger.info('Current global Godot version: 3.5.1'))
          .called(1);
    });

    test('handles no global version set', () async {
      final globalVersionFile = _MockFile();
      when(globalVersionFile.existsSync).thenReturn(false);
      when(() => File(path.join('/home/user', '.gvm', 'global_version')))
          .thenReturn(globalVersionFile);

      final result = await commandRunner.run(['global']);

      expect(result, equals(ExitCode.success.code));
      verify(() => logger.warn('No global Godot version currently set'))
          .called(1);
    });
  });
}
