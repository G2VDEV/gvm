import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gvm/src/models/godot_release.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

class UninstallCommand extends Command<int> {
  UninstallCommand({required Logger logger}) : _logger = logger {
    argParser.addOption(
      'version',
      abbr: 'v',
      help: 'Specify the Godot version to uninstall',
    );
  }

  @override
  String get description => 'Uninstall a specific version of Godot';

  @override
  String get name => 'uninstall';

  final Logger _logger;

  @override
  Future<int> run() async {
    final version = argResults?['version'] as String?;
    final installedVersions = getInstalledVersions();

    GodotRelease? releaseToUninstall;
    if (version == null) {
      releaseToUninstall = await _selectVersion(installedVersions);
    } else {
      releaseToUninstall = installedVersions.firstWhere(
        (r) => r.name == version,
        orElse: () => throw Exception('Version $version not found'),
      );
    }

    if (releaseToUninstall == null) {
      _logger.err('No version selected. Uninstallation cancelled.');
      return ExitCode.success.code;
    }

    final confirmed = _logger.confirm(
      'Are you sure you want to uninstall Godot ${releaseToUninstall.name}?',
    );

    if (!confirmed) {
      _logger.info('Uninstallation cancelled.');
      return ExitCode.success.code;
    }

    final uninstallDir = _getInstallDir(releaseToUninstall.name);
    if (uninstallDir.existsSync()) {
      await uninstallDir.delete(recursive: true);
      _logger
          .success('Godot ${releaseToUninstall.name} uninstalled successfully');
    } else {
      _logger.err('Godot ${releaseToUninstall.name} is not installed');
    }

    return ExitCode.success.code;
  }

  Future<GodotRelease?> _selectVersion(List<GodotRelease> releases) async {
    if (releases.isEmpty) {
      _logger.err('No Godot versions are currently installed.');
      return null;
    }

    return _logger.chooseOne(
      'Select Godot version to uninstall:',
      choices: releases,
      // ignore: cast_nullable_to_non_nullable
      display: (release) => (release as GodotRelease).name,
    );
  }

  Directory _getInstallDir(String version) {
    final homeDir =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    return Directory(path.join(homeDir!, '.gvm', 'versions', version));
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
