import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

class CurrentCommand extends Command<int> {
  CurrentCommand({required Logger logger}) : _logger = logger;

  @override
  String get description => 'Display the current Godot version in use';

  @override
  String get name => 'current';

  final Logger _logger;

  @override
  Future<int> run() async {
    final localVersion = await _getLocalVersion();
    if (localVersion != null) {
      _logger.info('Current local Godot version: $localVersion');
      return ExitCode.success.code;
    }

    final globalVersion = await _getGlobalVersion();
    if (globalVersion != null) {
      _logger.info('Current global Godot version: $globalVersion');
      return ExitCode.success.code;
    }

    _logger.warn('No Godot version currently set (neither local nor global)');
    return ExitCode.success.code;
  }

  Future<String?> _getLocalVersion() async {
    final currentDir = Directory.current;
    final versionFile = File(path.join(currentDir.path, '.gvmrc'));
    if (versionFile.existsSync()) {
      return versionFile.readAsString();
    }
    return null;
  }

  Future<String?> _getGlobalVersion() async {
    final homeDir =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    final gvmDir = Directory(path.join(homeDir!, '.gvm'));
    final globalVersionFile = File(path.join(gvmDir.path, 'global_version'));
    if (globalVersionFile.existsSync()) {
      return globalVersionFile.readAsString();
    }
    return null;
  }
}
