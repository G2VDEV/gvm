import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gvm/src/models/godot_release.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

class UseCommand extends Command<int> {
  UseCommand({required Logger logger}) : _logger = logger {
    argParser.addOption(
      'version',
      abbr: 'v',
      help: 'Specify the Godot version to use',
    );
  }

  @override
  String get description =>
      'Set a Godot version to use in the current directory';

  @override
  String get name => 'use';

  final Logger _logger;

  @override
  Future<int> run() async {
    final version = argResults?['version'] as String?;
    final installedVersions = getInstalledVersions();

    GodotRelease? releaseToUse;
    if (version == null) {
      releaseToUse = await _selectVersion(installedVersions);
    } else {
      releaseToUse = installedVersions.firstWhere(
        (r) => r.name == version,
        orElse: () => throw Exception('Version $version not found'),
      );
    }

    if (releaseToUse == null) {
      _logger.err('No version selected. Use command cancelled.');
      return ExitCode.success.code;
    }

    await _setLocalVersion(releaseToUse.name);
    _logger.success('Godot ${releaseToUse.name} set for use in this directory');

    return ExitCode.success.code;
  }

  Future<GodotRelease?> _selectVersion(List<GodotRelease> releases) async {
    if (releases.isEmpty) {
      _logger.err('No Godot versions are currently installed.');
      return null;
    }

    return _logger.chooseOne(
      'Select Godot version to use:',
      choices: releases,
      // ignore: cast_nullable_to_non_nullable
      display: (release) => (release as GodotRelease).name,
    );
  }

  Future<void> _setLocalVersion(String version) async {
    final currentDir = Directory.current;
    final versionFile = File(path.join(currentDir.path, '.gvmrc'));
    await versionFile.writeAsString(version);
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
}
