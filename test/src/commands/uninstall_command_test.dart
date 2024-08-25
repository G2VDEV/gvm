import 'dart:io';

import 'package:gvm/src/command_runner.dart';
import 'package:gvm/src/models/godot_release.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

class _MockLogger extends Mock implements Logger {}

// ignore: unused_element
class _MockFile extends Mock implements File {}

class _MockDirectory extends Mock implements Directory {}

void main() {
  group('uninstall', () {
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

    test('uninstalls specified version', () async {
      final versionDir = _MockDirectory();
      when(() => versionDir.path).thenReturn('/home/user/.gvm/versions/4.0.0');
      when(versionDir.existsSync).thenReturn(true);
      when(() => versionDir.deleteSync(recursive: true)).thenReturn(null);

      when(
        () => Directory(path.join('/home/user', '.gvm', 'versions', '4.0.0')),
      ).thenReturn(versionDir);

      final result =
          await commandRunner.run(['uninstall', '--version', '4.0.0']);

      expect(result, equals(ExitCode.success.code));
      verify(() => versionDir.deleteSync(recursive: true)).called(1);
      verify(() => logger.success('Godot 4.0.0 uninstalled successfully'))
          .called(1);
    });

    test('handles version not installed', () async {
      final versionDir = _MockDirectory();
      when(() => versionDir.path).thenReturn('/home/user/.gvm/versions/4.0.0');
      when(versionDir.existsSync).thenReturn(false);

      when(
        () => Directory(path.join('/home/user', '.gvm', 'versions', '4.0.0')),
      ).thenReturn(versionDir);

      final result =
          await commandRunner.run(['uninstall', '--version', '4.0.0']);

      expect(result, equals(ExitCode.software.code));
      verify(() => logger.err('Godot version 4.0.0 is not installed'))
          .called(1);
    });

    test('prompts for version selection when no version specified', () async {
      final versionsDir = _MockDirectory();
      when(() => versionsDir.path).thenReturn('/home/user/.gvm/versions');
      when(versionsDir.existsSync).thenReturn(true);
      when(versionsDir.listSync).thenReturn([
        Directory('/home/user/.gvm/versions/4.0.0'),
        Directory('/home/user/.gvm/versions/3.5.1'),
      ]);

      when(() => Directory(path.join('/home/user', '.gvm', 'versions')))
          .thenReturn(versionsDir);

      when(
        () => logger.chooseOne<GodotRelease>(
          'Select Godot version to uninstall:',
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

      final versionDir = _MockDirectory();
      when(() => versionDir.path).thenReturn('/home/user/.gvm/versions/4.0.0');
      when(versionDir.existsSync).thenReturn(true);
      when(() => versionDir.deleteSync(recursive: true)).thenReturn(null);

      when(
        () => Directory(path.join('/home/user', '.gvm', 'versions', '4.0.0')),
      ).thenReturn(versionDir);

      final result = await commandRunner.run(['uninstall']);

      expect(result, equals(ExitCode.success.code));
      verify(() => versionDir.deleteSync(recursive: true)).called(1);
      verify(() => logger.success('Godot 4.0.0 uninstalled successfully'))
          .called(1);
    });

    test('handles no installed versions', () async {
      final versionsDir = _MockDirectory();
      when(() => versionsDir.path).thenReturn('/home/user/.gvm/versions');
      when(versionsDir.existsSync).thenReturn(false);

      when(() => Directory(path.join('/home/user', '.gvm', 'versions')))
          .thenReturn(versionsDir);

      final result = await commandRunner.run(['uninstall']);

      expect(result, equals(ExitCode.software.code));
      verify(() => logger.err('No Godot versions are currently installed.'))
          .called(1);
    });
  });
}
