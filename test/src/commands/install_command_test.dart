import 'dart:io';

import 'package:gvm/src/command_runner.dart';
import 'package:gvm/src/models/godot_release.dart';
import 'package:http/http.dart' as http;
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockLogger extends Mock implements Logger {}

class _MockHttpClient extends Mock implements http.Client {}

class _MockResponse extends Mock implements http.Response {}

class _MockDirectory extends Mock implements Directory {}

class _MockFile extends Mock implements File {}

void main() {
  group('install', () {
    late Logger logger;
    late GvmCommandRunner commandRunner;
    late http.Client httpClient;

    setUp(() {
      logger = _MockLogger();
      httpClient = _MockHttpClient();
      commandRunner = GvmCommandRunner(logger: logger);

      // Mock HTTP responses
      when(() => httpClient.get(any())).thenAnswer((_) async {
        final response = _MockResponse();
        when(() => response.statusCode).thenReturn(200);
        when(() => response.body).thenReturn('[]');
        return response;
      });

      // Mock directory and file operations
      when(() => Directory(any()).create(recursive: true))
          .thenAnswer((_) async => _MockDirectory());
      when(() => File(any()).writeAsBytes(any()))
          .thenAnswer((_) async => _MockFile());
    });

    test('prompts for branch and version when no version is specified',
        () async {
      when(
        () => logger.chooseOne<String>(
          any(),
          choices: any(named: 'choices'),
          defaultValue: any(named: 'defaultValue'),
        ),
      ).thenReturn('4.x');

      when(
        () => logger.chooseOne<GodotRelease>(
          any(),
          choices: any(named: 'choices'),
          display: any(named: 'display'),
        ),
      ).thenReturn(
        GodotRelease(
          id: '1',
          name: '4.0.0',
          publishedAt: DateTime.now(),
          body: '',
          assets: [],
        ),
      );

      final result = await commandRunner.run(['install']);
      expect(
        result,
        equals(ExitCode.software.code),
      ); // No compatible build found

      verify(
        () => logger.chooseOne<String>(
          'Select Godot branch:',
          choices: ['3.x', '4.x'],
          defaultValue: '4.x',
        ),
      ).called(1);

      verify(
        () => logger.chooseOne<GodotRelease>(
          'Select Godot version to install:',
          choices: any(named: 'choices'),
          display: any(named: 'display'),
        ),
      ).called(1);
    });

    test('installs specified version', () async {
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
              "assets": [
                {
                  "name": "Godot_v4.0.0-stable_win64.exe.zip",
                  "browser_download_url": "https://example.com/godot.zip"
                }
              ]
            }
          ]
        ''');
        return response;
      });

      final result = await commandRunner.run(['install', '--version', '4.0.0']);
      expect(result, equals(ExitCode.success.code));

      verify(() => logger.success('Godot 4.0.0 installed successfully'))
          .called(1);
    });

    test('handles version not found', () async {
      final result =
          await commandRunner.run(['install', '--version', '999.0.0']);
      expect(result, equals(ExitCode.software.code));

      verify(() => logger.err('Version 999.0.0 not found')).called(1);
    });
  });
}
