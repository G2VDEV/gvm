import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:args/command_runner.dart';
import 'package:collection/collection.dart';
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

    final asset = _getAssetForCurrentPlatform(release);
    if (asset == null) {
      _logger.err('No compatible build found for ${release.name}');
      return ExitCode.software.code;
    }

    final installDir = await _createInstallDir(release.name);
    await _downloadAndExtract(asset, installDir);

    _logger.success('Godot ${release.name} installed successfully');
    return ExitCode.success.code;
  }

  Future<List<GodotRelease>> fetchRemoteVersions() async {
    const url = 'https://api.github.com/repos/godotengine/godot/releases';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final releases = jsonDecode(response.body) as List;
      return releases
          .map(
            (release) => GodotRelease.fromJson(release as Map<String, dynamic>),
          )
          .where(
            (version) =>
                version.name.startsWith('3.') || version.name.startsWith('4.'),
          )
          .toList();
    } else {
      throw Exception('Failed to fetch remote versions');
    }
  }

  Future<GodotRelease?> _selectVersion(List<GodotRelease> releases) async {
    final branches = ['4.x', '3.x'];
    final selectedBranch = _logger.chooseOne(
      'Select Godot branch:',
      choices: branches,
      defaultValue: branches.first,
    );

    final branchReleases =
        releases.where((r) => r.name.startsWith(selectedBranch[0])).toList();
    if (branchReleases.isEmpty) {
      _logger.err('No releases found for branch $selectedBranch');
      return null;
    }

    return _logger.chooseOne(
      'Select Godot version to install:',
      choices: branchReleases,
      // ignore: cast_nullable_to_non_nullable
      display: (release) => (release as GodotRelease).name,
    );
  }

  GodotAsset? _getAssetForCurrentPlatform(GodotRelease release) {
    final platform = Platform.operatingSystem;
    final arch = Platform.operatingSystemVersion.contains('64') ? '64' : '32';

    String assetNamePattern;
    if (platform == 'windows') {
      assetNamePattern = 'win$arch.exe.zip';
    } else if (platform == 'linux') {
      assetNamePattern = 'linux.$arch.zip';
    } else if (platform == 'macos') {
      assetNamePattern = 'macos.universal.zip';
    } else {
      throw Exception('Unsupported platform: $platform');
    }

    return release.assets
        .firstWhereOrNull((a) => a.name.contains(assetNamePattern));
  }

  Future<Directory> _createInstallDir(String version) async {
    final homeDir =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    final installDir =
        Directory(path.join(homeDir!, '.gvm', 'versions', version));
    await installDir.create(recursive: true);
    return installDir;
  }

  Future<void> _downloadAndExtract(
    GodotAsset asset,
    Directory installDir,
  ) async {
    _logger.info('Downloading Godot ${asset.name}...');
    final response = await http.get(Uri.parse(asset.browserDownloadUrl));
    if (response.statusCode != 200) {
      throw Exception('Failed to download Godot');
    }

    final bytes = response.bodyBytes;
    final archive = ZipDecoder().decodeBytes(bytes);

    _logger.info('Extracting files...');
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
  }
}
