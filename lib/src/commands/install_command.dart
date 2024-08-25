// ignore_for_file: lines_longer_than_80_chars

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:args/command_runner.dart';
import 'package:gvm/src/models/godot_release.dart';
import 'package:http/http.dart' as http;
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

class InstallCommand extends Command<int> {
  InstallCommand({required Logger logger}) : _logger = logger {
    argParser.addOption(
      'version',
      abbr: 'v',
      help: 'Specify the Godot version to install',
    );
  }

  @override
  String get description => 'Install a specific version of Godot';

  @override
  String get name => 'install';

  final Logger _logger;

  @override
  Future<int> run() async {
    final version = argResults?['version'] as String?;
    final releases = await fetchRemoteVersions();

    GodotRelease? release;
    if (version == null) {
      release = await _selectVersion(releases);
    } else {
      release = releases.firstWhere(
        (r) => r.name == version,
        orElse: () => throw Exception('Version $version not found'),
      );
    }

    if (release == null) {
      _logger.err('No version selected. Installation cancelled.');
      return ExitCode.success.code;
    }

    final assetOptions = _getCompatibleAssets(release);
    if (assetOptions.isEmpty) {
      _logger.err('No compatible build found for your system.');
      return ExitCode.software.code;
    }

    final asset = await _selectAsset(assetOptions);
    if (asset == null) {
      _logger.err('No asset selected. Installation cancelled.');
      return ExitCode.success.code;
    }

    final installDir = await _createInstallDir(release.name, asset.isMono);
    await _downloadAndExtract(asset, installDir);

    _logger.success(
      'Godot ${release.name}${asset.isMono ? ' (Mono)' : ''} installed successfully',
    );
    return ExitCode.success.code;
  }

  List<GodotAsset> _getCompatibleAssets(GodotRelease release) {
    final platform = Platform.operatingSystem;
    final arch = _getSystemArchitecture();

    String assetNamePattern;
    if (platform == 'windows') {
      assetNamePattern = arch == 'arm64' ? 'win64.exe.zip' : 'win$arch.exe.zip';
    } else if (platform == 'linux') {
      if (arch == 'arm64') {
        assetNamePattern = 'linux.arm64.zip';
      } else if (arch == 'arm32') {
        assetNamePattern = 'linux.arm32.zip';
      } else {
        assetNamePattern = 'linux.$arch.zip';
      }
    } else if (platform == 'macos') {
      assetNamePattern = 'macos.universal.zip';
    } else {
      throw Exception('Unsupported platform: $platform');
    }

    return release.assets
        .where((a) => a.name.contains(assetNamePattern))
        .toList();
  }

  Future<GodotAsset?> _selectAsset(List<GodotAsset> assets) async {
    if (assets.isEmpty) {
      return null;
    }
    if (assets.length == 1) {
      return assets.first;
    }

    return _logger.chooseOne(
      'Select Godot version to install:',
      choices: assets,
      display: (asset) {
        // ignore: cast_nullable_to_non_nullable
        final assetCast = asset as GodotAsset;
        return assetCast.isMono ? '${assetCast.name} (Mono)' : assetCast.name;
      },
    );
  }

  Future<Directory> _createInstallDir(String version, bool isMono) async {
    final homeDir =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    final installDir = Directory(
      path.join(
        homeDir!,
        '.gvm',
        'versions',
        '$version${isMono ? '-mono' : ''}',
      ),
    );
    await installDir.create(recursive: true);

    return installDir;
  }

  Future<GodotRelease?> _selectVersion(List<GodotRelease> releases) async {
    final godot4Releases =
        releases.where((r) => r.name.startsWith('4.')).toList();
    final godot3Releases =
        releases.where((r) => r.name.startsWith('3.')).toList();

    final branch = _logger.chooseOne(
      'Select Godot branch:',
      choices: ['4.x', '3.x'],
      defaultValue: '4.x',
    );

    final releaseChoices = branch == '4.x' ? godot4Releases : godot3Releases;

    return _logger.chooseOne(
      'Select Godot version to install:',
      choices: releaseChoices,
      // ignore: cast_nullable_to_non_nullable
      display: (release) => (release as GodotRelease).name,
    );
  }

  String _getSystemArchitecture() {
    if (Platform.isWindows) {
      return Platform.environment['PROCESSOR_ARCHITECTURE']?.toLowerCase() ==
              'arm64'
          ? 'arm64'
          : '64';
    } else if (Platform.isMacOS) {
      return Platform.version.toLowerCase().contains('arm') ? 'arm64' : '64';
    } else if (Platform.isLinux) {
      final result = Process.runSync('uname', ['-m']);
      final output = result.stdout.toString().trim().toLowerCase();
      if (output.contains('aarch64') || output.contains('arm64')) {
        return 'arm64';
      } else if (output.contains('armv7') || output.contains('armhf')) {
        return 'arm32';
      } else if (output.contains('x86_64') || output.contains('amd64')) {
        return 'x86_64';
      } else {
        return 'x86_32';
      }
    }
    throw Exception('Unsupported platform: ${Platform.operatingSystem}');
  }

  Future<void> _downloadAndExtract(
    GodotAsset asset,
    Directory installDir,
  ) async {
    final progress = _logger.progress('Downloading Godot ${asset.name}');

    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(asset.browserDownloadUrl));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        progress.fail('Failed to download Godot');
        throw Exception('Failed to download Godot');
      }

      final totalBytes = response.contentLength ?? -1;
      var receivedBytes = 0;
      final bytes = <int>[];

      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          final progressStatus =
              (receivedBytes / totalBytes * 100).toStringAsFixed(1);
          progress.update('Downloading: $progressStatus%');
        }
      }

      progress.complete('Download completed');

      final extractProgress = _logger.progress('Extracting files');
      final archive = ZipDecoder().decodeBytes(bytes);
      for (final file in archive) {
        final filename = file.name;
        if (file.isFile) {
          final data = file.content as List<int>;
          File(path.join(installDir.path, filename))
            ..createSync(recursive: true)
            ..writeAsBytesSync(data);
        } else {
          Directory(path.join(installDir.path, filename))
              .createSync(recursive: true);
        }
      }
      extractProgress.complete('Extraction completed');

      // Add this line to organize files and set permissions
      await _organizeAndSetPermissions(installDir, asset);
    } finally {
      client.close();
    }
  }

  Future<void> _organizeAndSetPermissions(
    Directory installDir,
    GodotAsset asset,
  ) async {
    final progress =
        _logger.progress('Organizing files and setting permissions');
    try {
      final platform = Platform.operatingSystem;
      final isMono = asset.isMono;
      final version = path.basename(installDir.path).split('-').first;

      if (platform == 'macos') {
        final appName = isMono ? 'Godot_mono.app' : 'Godot.app';
        final appDir = Directory(path.join(installDir.path, appName));
        if (appDir.existsSync()) {
          final cliPath = path.join(appDir.path, 'Contents', 'MacOS', 'Godot');
          await Process.run('chmod', ['+x', cliPath]);
        }
      } else if (platform == 'linux') {
        final binaryName = isMono
            ? 'Godot_${version}_mono_linux.${_getSystemArchitecture()}'
            : 'Godot_${version}_linux.${_getSystemArchitecture()}';
        final binaryPath = path.join(installDir.path, binaryName);
        await Process.run('chmod', ['+x', binaryPath]);
      }

      progress.complete('Files organized and permissions set');
    } catch (e) {
      progress.fail('Failed to organize files and set permissions: $e');
    }
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
              (release) =>
                  GodotRelease.fromJson(release as Map<String, dynamic>),
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

extension on GodotAsset {
  bool get isMono => name.toLowerCase().contains('mono');
}
