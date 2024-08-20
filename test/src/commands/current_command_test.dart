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
  group('current', () {
    late Logger logger;
    late GvmCommandRunner commandRunner;
    late Directory currentDirectory;
    late Directory homeDirectory;

    setUp(() {
      logger = _MockLogger();
      commandRunner = GvmCommandRunner(logger: logger);
      currentDirectory = _MockDirectory();
      homeDirectory = _MockDirectory();

      when(() => currentDirectory.path).thenReturn('/current/path');
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

    test('outputs local version when .gvmrc exists', () async {
      final versionFile = _MockFile();
      when(versionFile.existsSync).thenReturn(true);
      when(versionFile.readAsString).thenAnswer((_) async => '4.0.0');
      when(() => File(path.join('/current/path', '.gvmrc')))
          .thenReturn(versionFile);

      final result = await commandRunner.run(['current']);

      expect(result, equals(ExitCode.success.code));
      verify(() => logger.info('Current local Godot version: 4.0.0')).called(1);
    });

    test(
        'outputs global version when .gvmrc does not exist but global version is set',
        () async {
      final localVersionFile = _MockFile();
      when(localVersionFile.existsSync).thenReturn(false);
      when(() => File(path.join('/current/path', '.gvmrc')))
          .thenReturn(localVersionFile);

      final globalVersionFile = _MockFile();
      when(globalVersionFile.existsSync).thenReturn(true);
      when(globalVersionFile.readAsString).thenAnswer((_) async => '3.5.1');
      when(() => File(path.join('/home/user', '.gvm', 'global_version')))
          .thenReturn(globalVersionFile);

      final result = await commandRunner.run(['current']);

      expect(result, equals(ExitCode.success.code));
      verify(() => logger.info('Current global Godot version: 3.5.1'))
          .called(1);
    });

    test('outputs warning when no version is set', () async {
      final localVersionFile = _MockFile();
      when(localVersionFile.existsSync).thenReturn(false);
      when(() => File(path.join('/current/path', '.gvmrc')))
          .thenReturn(localVersionFile);

      final globalVersionFile = _MockFile();
      when(globalVersionFile.existsSync).thenReturn(false);
      when(() => File(path.join('/home/user', '.gvm', 'global_version')))
          .thenReturn(globalVersionFile);

      final result = await commandRunner.run(['current']);

      expect(result, equals(ExitCode.success.code));
      verify(
        () => logger.warn(
          'No Godot version currently set (neither local nor global)',
        ),
      ).called(1);
    });
  });
}
