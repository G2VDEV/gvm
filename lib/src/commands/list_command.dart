// ignore_for_file: lines_longer_than_80_chars

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gvm/src/models/godot_release.dart';
import 'package:http/http.dart' as http;
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

class ListCommand extends Command<int> {
  ListCommand({required Logger logger}) : _logger = logger {
    argParser
      ..addFlag(
        'remote',
        help: 'List remote versions instead of installed ones',
        negatable: false,
      )
      ..addFlag(
        'all',
        abbr: 'a',
        help: 'Show all versions instead of just the last 5',
        negatable: false,
      );
  }

  @override
  String get description => 'List installed or remote Godot versions';

  @override
  String get name => 'list';

  final Logger _logger;

  @override
  Future<int> run() async {
    final isRemote = argResults?['remote'] == true;
    final showAll = argResults?['all'] == true;
    final versions =
        isRemote ? await fetchRemoteVersions() : getInstalledVersions();

    final godot4Versions = versions.where((v) => v.id.startsWith('4.')).toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    final godot3Versions = versions.where((v) => v.id.startsWith('3.')).toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

    if (godot4Versions.isEmpty && godot3Versions.isEmpty) {
      _logger
          .info('No Godot versions ${isRemote ? 'available' : 'installed'}.');
      if (!isRemote) {
        _logger.info('Use the "install" command to install a Godot version.');
      }
      return ExitCode.success.code;
    }

    if (godot4Versions.isNotEmpty) {
      _logger.info('Godot 4.x Versions:');
      _displayVersions(godot4Versions, showAll);
    }

    if (godot3Versions.isNotEmpty) {
      if (godot4Versions.isNotEmpty) _logger.info('');
      _logger.info('Godot 3.x Versions:');
      _displayVersions(godot3Versions, showAll);
    }

    if (!showAll) {
      _logger.info('\nUse --all to see all versions');
    }

    return ExitCode.success.code;
  }

  void _displayVersions(List<GodotRelease> versions, bool showAll) {
    final displayVersions = showAll ? versions : versions.take(5).toList();
    for (final version in displayVersions) {
      _logger.info('- ${version.name} (${version.id})');
    }
    if (!showAll && versions.length > 5) {
      _logger.info('  ...');
    }
  }

  List<GodotRelease> getInstalledVersions() {
    final homeDir =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    final gvmDir = Directory(path.join(homeDir!, '.gvm', 'versions'));

    if (!gvmDir.existsSync()) {
      return [];
    }

    return gvmDir
        .listSync()
        .whereType<Directory>()
        .map((dir) {
          final versionString = path.basename(dir.path);
          return GodotRelease(
            id: versionString,
            name: versionString,
            publishedAt: dir.statSync().modified,
            body: '',
            assets: [],
          );
        })
        .where(
          (version) =>
              version.id.startsWith('3.') || version.id.startsWith('4.'),
        )
        .toList();
  }

  Future<List<GodotRelease>> fetchRemoteVersions() async {
    final progress = _logger.progress('Fetching available Godot versions');
    try {
      const url = 'https://api.github.com/repos/godotengine/godot/releases';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final releases = jsonDecode(response.body) as List;
        progress.complete('Fetched available versions');
        return releases
            .map(
              (release) => GodotRelease.fromJson(
                release as Map<String, dynamic>,
              ),
            )
            .where(
              (version) =>
                  version.id.startsWith('3.') || version.id.startsWith('4.'),
            )
            .toList();
      } else {
        progress.fail('Failed to fetch versions');
        throw Exception(
          'Failed to fetch remote versions. Status code: ${response.statusCode}',
        );
      }
    } catch (e) {
      progress.fail('Error fetching versions');
      rethrow;
    }
  }
}
