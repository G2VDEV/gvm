import 'package:collection/collection.dart';

class GodotRelease {
  GodotRelease({
    required this.id,
    required this.name,
    required this.publishedAt,
    required this.body,
    required this.assets,
  });

  factory GodotRelease.fromJson(Map<String, dynamic> json) {
    return GodotRelease(
      id: json['tag_name'] as String,
      name: _cleanName(json['name'] as String),
      publishedAt: DateTime.parse(json['published_at'] as String),
      body: json['body'] as String,
      assets: (json['assets'] as List<dynamic>)
          .map((e) => GodotAsset.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final String id;
  final String name;
  final DateTime publishedAt;
  final String body;
  final List<GodotAsset> assets;

  static String _cleanName(String name) {
    return name
        .replaceAll(RegExp(r'-stable$'), '')
        .replaceAll(RegExp('^v'), '');
  }

  GodotAsset? getAssetForPlatform(String platform) {
    return assets.firstWhereOrNull((asset) => asset.name.contains(platform));
  }
}

class GodotAsset {
  GodotAsset({
    required this.name,
    required this.browserDownloadUrl,
    required this.size,
    required this.downloadCount,
  });

  factory GodotAsset.fromJson(Map<String, dynamic> json) {
    return GodotAsset(
      name: json['name'] as String,
      browserDownloadUrl: json['browser_download_url'] as String,
      size: json['size'] as int,
      downloadCount: json['download_count'] as int,
    );
  }

  final String name;
  final String browserDownloadUrl;
  final int size;
  final int downloadCount;
}
