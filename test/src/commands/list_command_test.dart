import 'dart:io';

import 'package:gvm/src/command_runner.dart';
import 'package:http/http.dart' as http;
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

class _MockLogger extends Mock implements Logger {}

class _MockHttpClient extends Mock implements http.Client {}

class _MockResponse extends Mock implements http.Response {}

class _MockDirectory extends Mock implements Directory {}

void main() {
  group('list', () {
    late Logger logger;
    late GvmCommandRunner commandRunner;
    late http.Client httpClient;
    late Directory homeDirectory;

    setUp(() {
      logger = _MockLogger();
      httpClient = _MockHttpClient();
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

    test('lists installed versions', () async {
      final versionsDir = _MockDirectory();
      when(versionsDir.existsSync).thenReturn(true);
      when(versionsDir.listSync).thenReturn([
        Directory('/home/user/.gvm/versions/4.0.0'),
        Directory('/home/user/.gvm/versions/3.5.1'),
      ]);
      when(() => Directory(path.join('/home/user', '.gvm', 'versions')))
          .thenReturn(versionsDir);

      final result = await commandRunner.run(['list']);

      expect(result, equals(ExitCode.success.code));
      verify(() => logger.info('Installed Godot versions:')).called(1);
      verify(() => logger.info('  4.0.0')).called(1);
      verify(() => logger.info('  3.5.1')).called(1);
    });

    test('handles no installed versions', () async {
      final versionsDir = _MockDirectory();
      when(versionsDir.existsSync).thenReturn(false);
      when(() => Directory(path.join('/home/user', '.gvm', 'versions')))
          .thenReturn(versionsDir);

      final result = await commandRunner.run(['list']);

      expect(result, equals(ExitCode.success.code));
      verify(() => logger.info('No Godot versions are currently installed.'))
          .called(1);
    });

    test('lists remote versions', () async {
      when(() => httpClient.get(any())).thenAnswer((_) async {
        final response = _MockResponse();
        when(() => response.statusCode).thenReturn(200);
        when(() => response.body).thenReturn('''
          [
            {
              "tag_name": "4.0.0",
              "name": "4.0.0",
              "published_at": "2023-03-01T00:00:00Z",
              "body": "Release notes",
              "assets": []
            },
            {
              "tag_name": "3.5.1",
              "name": "3.5.1",
              "published_at": "2022-09-01T00:00:00Z",
              "body": "Release notes",
              "assets": []
            }
          ]
        ''');
        return response;
      });

      final result = await commandRunner.run(['list', '--remote']);

      expect(result, equals(ExitCode.success.code));
      verify(() => logger.info('Available Godot versions:')).called(1);
      verify(() => logger.info('  4.0.0')).called(1);
      verify(() => logger.info('  3.5.1')).called(1);
    });

    test('handles network error when listing remote versions', () async {
      when(() => httpClient.get(any())).thenThrow(Exception('Network error'));

      final result = await commandRunner.run(['list', '--remote']);

      expect(result, equals(ExitCode.software.code));
      verify(() => logger.err('Failed to fetch remote versions: Network error'))
          .called(1);
    });
  });
}
