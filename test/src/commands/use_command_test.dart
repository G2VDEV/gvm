import 'dart:io';

import 'package:gvm/src/command_runner.dart';
import 'package:gvm/src/models/godot_release.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

class _MockLogger extends Mock implements Logger {}

class _MockFile extends Mock implements File {}

class _MockDirectory extends Mock implements Directory {}

void main() {
  group('use', () {
    late Logger logger;
    late GvmCommandRunner commandRunner;
    late Directory homeDirectory;
    late Directory currentDirectory;

    setUp(() {
      logger = _MockLogger();
      commandRunner = GvmCommandRunner(logger: logger);
      homeDirectory = _MockDirectory();
      currentDirectory = _MockDirectory();

      when(() => homeDirectory.path).thenReturn('/home/user');
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
      Directory.current = currentDirectory;
    });

    test('sets specified version for local use', () async {
      final versionFile = _MockFile();
      when(() => versionFile.writeAsString(any()))
          .thenAnswer((_) async => versionFile);
      when(() => File(path.join('/current/path', '.gvmrc')))
          .thenReturn(versionFile);

      final versionsDir = _MockDirectory();
      when(versionsDir.existsSync).thenReturn(true);
      when(versionsDir.listSync).thenReturn([
        Directory('/home/user/.gvm/versions/4.0.0'),
      ]);
      when(() => Directory(path.join('/home/user', '.gvm', 'versions')))
          .thenReturn(versionsDir);

      final result = await commandRunner.run(['use', '--version', '4.0.0']);

      expect(result, equals(ExitCode.success.code));
      verify(() => versionFile.writeAsString('4.0.0')).called(1);
      verify(() => logger.success('Godot 4.0.0 set for use in this directory'))
          .called(1);
    });

    test('prompts for version selection when no version specified', () async {
      final versionFile = _MockFile();
      when(() => versionFile.writeAsString(any()))
          .thenAnswer((_) async => versionFile);
      when(() => File(path.join('/current/path', '.gvmrc')))
          .thenReturn(versionFile);

      final versionsDir = _MockDirectory();
      when(versionsDir.existsSync).thenReturn(true);
      when(versionsDir.listSync).thenReturn([
        Directory('/home/user/.gvm/versions/4.0.0'),
        Directory('/home/user/.gvm/versions/3.5.1'),
      ]);
      when(() => Directory(path.join('/home/user', '.gvm', 'versions')))
          .thenReturn(versionsDir);

      when(
        () => logger.chooseOne<GodotRelease>(
          'Select Godot version to use:',
          choices: any(named: 'choices'),
          display: any(named: 'display'),
        ),
      ).thenReturn(
        GodotRelease(
          id: '4.0.0',
          name: '4.0.0',
          publishedAt: DateTime.now(),
          body: '',
          assets: [],
        ),
      );

      final result = await commandRunner.run(['use']);

      expect(result, equals(ExitCode.success.code));
      verify(() => versionFile.writeAsString('4.0.0')).called(1);
      verify(() => logger.success('Godot 4.0.0 set for use in this directory'))
          .called(1);
    });

    test('handles no installed versions', () async {
      final versionsDir = _MockDirectory();
      when(versionsDir.existsSync).thenReturn(false);
      when(() => Directory(path.join('/home/user', '.gvm', 'versions')))
          .thenReturn(versionsDir);

      final result = await commandRunner.run(['use']);

      expect(result, equals(ExitCode.success.code));
      verify(() => logger.err('No Godot versions are currently installed.'))
          .called(1);
    });

    test('handles version not found', () async {
      final versionsDir = _MockDirectory();
      when(versionsDir.existsSync).thenReturn(true);
      when(versionsDir.listSync).thenReturn([
        Directory('/home/user/.gvm/versions/3.5.1'),
      ]);
      when(() => Directory(path.join('/home/user', '.gvm', 'versions')))
          .thenReturn(versionsDir);

      expect(
        () => commandRunner.run(['use', '--version', '4.0.0']),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Version 4.0.0 not found'),
          ),
        ),
      );
    });
  });
}
