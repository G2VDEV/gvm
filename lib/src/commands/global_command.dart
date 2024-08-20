import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gvm/src/models/godot_release.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

class GlobalCommand extends Command<int> {
  GlobalCommand({required Logger logger}) : _logger = logger {
    argParser.addOption(
      'version',
      abbr: 'v',
      help: 'Specify the Godot version to set as global',
    );
  }

  @override
  String get description => 'Set a Godot version as global';

  @override
  String get name => 'global';

  final Logger _logger;

  @override
  Future<int> run() async {
    final version = argResults?['version'] as String?;
    final installedVersions = getInstalledVersions();

    GodotRelease? releaseToSetGlobal;
    if (version == null) {
      releaseToSetGlobal = await _selectVersion(installedVersions);
    } else {
      releaseToSetGlobal = installedVersions.firstWhere(
        (r) => r.name == version,
        orElse: () => throw Exception('Version $version not found'),
      );
    }

    if (releaseToSetGlobal == null) {
      _logger.err('No version selected. Global setting cancelled.');
      return ExitCode.success.code;
    }

    await _setGlobalVersion(releaseToSetGlobal.name);
    _logger.success('Godot ${releaseToSetGlobal.name} set as global version');

    return ExitCode.success.code;
  }

  Future<GodotRelease?> _selectVersion(List<GodotRelease> releases) async {
    if (releases.isEmpty) {
      _logger.err('No Godot versions are currently installed.');
      return null;
    }

    return _logger.chooseOne(
      'Select Godot version to set as global:',
      choices: releases,
      // ignore: cast_nullable_to_non_nullable
      display: (release) => (release as GodotRelease).name,
    );
  }

  Future<void> _setGlobalVersion(String version) async {
    final homeDir =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    final gvmDir = Directory(path.join(homeDir!, '.gvm'));
    final globalVersionFile = File(path.join(gvmDir.path, 'global_version'));

    await globalVersionFile.writeAsString(version);

    // Create symlink or update PATH based on the operating system
    if (Platform.isWindows) {
      await _updateWindowsPath(version);
    } else {
      await _createUnixSymlink(version);
    }
  }

  Future<void> _createUnixSymlink(String version) async {
    final homeDir = Platform.environment['HOME']!;
    final versionDir =
        Directory(path.join(homeDir, '.gvm', 'versions', version));
    final globalBinDir = Directory(path.join(homeDir, '.gvm', 'bin'));

    await globalBinDir.create(recursive: true);
    final godotExecutable = File(path.join(versionDir.path, 'godot'));
    final symlinkPath = path.join(globalBinDir.path, 'godot');

    if (File(symlinkPath).existsSync()) {
      await File(symlinkPath).delete();
    }
    await Link(symlinkPath).create(godotExecutable.path);
  }

  Future<void> _updateWindowsPath(String version) async {
    // Implementation for updating Windows PATH
    // This is a placeholder and needs to be implemented
    _logger.warn('Updating Windows PATH is not implemented yet.');
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
