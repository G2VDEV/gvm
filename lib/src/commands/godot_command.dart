import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

class GodotCommand extends Command<int> {
  GodotCommand({required Logger logger}) : _logger = logger;

  @override
  String get description =>
      'Godot proxy command with the current or specified version';

  @override
  String get name => 'godot';

  final Logger _logger;

  @override
  Future<int> run() async {
    final godotPath = await _getGodotPath();
    if (godotPath == null) {
      _logger.err(
        'No Godot version set. Use "gvm use" or "gvm global" to set a version.',
      );
      return ExitCode.software.code;
    }

    final args = argResults!.rest;
    final godotArgs = <String>[];

    if (args.isNotEmpty) {
      // If a project path is provided, open it in the editor
      godotArgs.addAll(['--editor', args.first]);
    } else {
      // If no project path is provided, open the project manager
      godotArgs.add('--project-manager');
    }

    // Add any additional arguments
    godotArgs.addAll(args.skip(1));

    unawaited(Process.run(godotPath, godotArgs));
    final godotVersion = await _getLocalVersion() ?? await _getGlobalVersion();
    if (godotVersion != null) {
      _logger.info(
        'Opening Godot $godotVersion',
      );
    } else {
      _logger.err(
        'No Godot version set. Use "gvm use" or "gvm global" to set a version.',
      );
    }

    return ExitCode.success.code;
  }

  Future<String?> _getGodotPath() async {
    final localVersion = await _getLocalVersion();
    if (localVersion != null) {
      return _findGodotExecutable(localVersion);
    }

    final globalVersion = await _getGlobalVersion();
    if (globalVersion != null) {
      return _findGodotExecutable(globalVersion);
    }

    return null;
  }

  Future<String?> _getLocalVersion() async {
    final currentDir = Directory.current;
    final versionFile = File(path.join(currentDir.path, '.gvmrc'));
    if (versionFile.existsSync()) {
      return versionFile.readAsString().then((s) => s.trim());
    }
    return null;
  }

  Future<String?> _getGlobalVersion() async {
    final homeDir =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    final gvmDir = Directory(path.join(homeDir!, '.gvm'));
    final globalVersionFile = File(path.join(gvmDir.path, 'global_version'));
    if (globalVersionFile.existsSync()) {
      return globalVersionFile.readAsString().then((s) => s.trim());
    }
    return null;
  }

  Future<String?> _findGodotExecutable(String version) async {
    final homeDir =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    final versionDir =
        Directory(path.join(homeDir!, '.gvm', 'versions', version));

    if (!versionDir.existsSync()) {
      _logger.err('Godot version $version is not installed.');
      return null;
    }

    if (Platform.isMacOS) {
      final appPath = path.join(versionDir.path, 'Godot.app');
      final monoAppPath = path.join(versionDir.path, 'Godot_mono.app');

      if (Directory(monoAppPath).existsSync()) {
        return path.join(monoAppPath, 'Contents', 'MacOS', 'Godot');
      } else if (Directory(appPath).existsSync()) {
        return path.join(appPath, 'Contents', 'MacOS', 'Godot');
      }
    } else if (Platform.isLinux) {
      final files = await versionDir.list().toList();
      final godotFile = files.firstWhere(
        (file) =>
            path.basename(file.path).startsWith('Godot_') &&
            !file.path.endsWith('.zip'),
        orElse: () =>
            throw Exception('Godot executable not found in $versionDir'),
      );
      return godotFile.path;
    } else if (Platform.isWindows) {
      final files = await versionDir.list().toList();
      final godotFile = files.firstWhere(
        (file) =>
            path.basename(file.path).toLowerCase().startsWith('godot_') &&
            file.path.toLowerCase().endsWith('.exe'),
        orElse: () =>
            throw Exception('Godot executable not found in $versionDir'),
      );
      return godotFile.path;
    }

    throw Exception('Unsupported platform: ${Platform.operatingSystem}');
  }
}
