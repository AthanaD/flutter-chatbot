// This file is part of ChatBot.
//
// ChatBot is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// ChatBot is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with ChatBot. If not, see <https://www.gnu.org/licenses/>.

import "dart:io";
import "dart:convert";
import "dart:isolate";
import "package:path/path.dart";
import "package:http/http.dart";
import "package:flutter/material.dart";
import "package:archive/archive_io.dart";
import "package:path_provider/path_provider.dart";
import "package:package_info_plus/package_info_plus.dart";
import "package:shared_preferences/shared_preferences.dart";

import "gen/scheme.dart";
import "gen/module.dart";

class Config {
  static late final ChatCore chatCore;
  static late final WebSearch webSearch;
  static late final VectorStore vectorStore;
  static late final TextToSpeech textToSpeech;
  static late final DocumentChunk documentChunk;
  static late final TitleGeneration titleGeneration;
  static late final ImageGeneration imageGeneration;
  static late final ImageCompression imageCompression;

  static final List<Chat> chats = [];
  static final Map<String, Bot> bots = {};
  static final Map<String, Api> apis = {};
  static final Map<String, Model> models = {};

  static late final String _cacheDir;
  static late final String _configDir;
  static const String _audioDir = "audio";
  static const String _imageDir = "image";

  static late final Store store;
  static late final Box<Bot> botBox;
  static late final Box<Api> apiBox;
  static late final Box<Chat> chatBox;
  static late final Box<Model> modelBox;
  static late final Box<Module> moduleBox;

  static Future<void> _initDb() async {
    store = await openStore(
      directory: _configDir,
    );
    botBox = store.box<Bot>();
    apiBox = store.box<Api>();
    chatBox = store.box<Chat>();
    modelBox = store.box<Model>();
    moduleBox = store.box<Module>();
  }

  static void saveModule(int id, Object module) {
    moduleBox.put(Module(
      id: id,
      json: jsonEncode(module),
    ));
  }

  static Future<void> init() async {
    _cacheDir = (await getTemporaryDirectory()).path;
    if (Platform.isAndroid) {
      _configDir = (await getExternalStorageDirectory())!.path;
    } else {
      _configDir = (await getApplicationSupportDirectory()).path;
    }

    await _initDb();

    _initDir();

    await Preferences.init();
  }

  static String audioFilePath(String fileName) =>
      join(_configDir, _audioDir, fileName);
  static String imageFilePath(String fileName) =>
      join(_configDir, _imageDir, fileName);
  static String cacheFilePath(String fileName) => join(_cacheDir, fileName);

  static void _initDir() {
    final audioDir = Directory(join(_configDir, _audioDir));
    if (!(audioDir.existsSync())) {
      audioDir.createSync();
    }

    final imageDir = Directory(join(_configDir, _imageDir));
    if (!(imageDir.existsSync())) {
      imageDir.createSync();
    }
  }
}

class Backup {
  static Future<void> exportConfig(String to) async {
    final time = DateTime.now().millisecondsSinceEpoch.toString();
    final path = join(to, "chatbot-backup-$time.zip");
    final root = Directory(Config._configDir);

    await Isolate.run(() async {
      final encoder = ZipFileEncoder();
      encoder.create(path);

      await for (final entity in root.list()) {
        if (entity is File) {
          encoder.addFile(entity);
        } else if (entity is Directory) {
          encoder.addDirectory(entity);
        }
      }
      await encoder.close();
    });
  }

  static Future<void> importConfig(String from) async {
    final root = Config._configDir;

    await Isolate.run(() async {
      await extractFileToDisk(from, root);
    });
  }

  static Future<void> clearData(List<String> dirs) async {
    final root = Config._configDir;

    await Isolate.run(() async {
      for (final dir in dirs) {
        final directory = Directory(join(root, dir));
        if (!directory.existsSync()) continue;
        directory.deleteSync(recursive: true);
      }
    });

    Config._initDir();
  }
}

class Updater {
  static List<int>? versionCode;
  static const String latestUrl =
      "https://github.com/fanenr/flutter-chatbot/releases/latest";
  static const String apiEndPoint =
      "https://api.github.com/repos/fanenr/flutter-chatbot/releases/latest";

  static Future<Map?> check() async {
    if (versionCode == null) {
      final version = (await PackageInfo.fromPlatform()).version;
      versionCode = version.split('.').map(int.parse).toList();
    }

    final client = Client();
    final response = await client.get(Uri.parse(apiEndPoint));

    if (response.statusCode != 200) {
      throw "${response.statusCode} ${response.body}";
    }

    final json = jsonDecode(response.body);
    return _isNewer(json["tag_name"]) ? json : null;
  }

  static bool _isNewer(String latest) {
    final latestCode = latest.substring(1).split('.').map(int.parse).toList();
    for (int i = 0; i < 3; i++) {
      if (latestCode[i] < versionCode![i]) return false;
      if (latestCode[i] > versionCode![i]) return true;
    }
    return false;
  }
}

class Preferences {
  static late bool _search;
  static late bool _googleSearch;
  static late SharedPreferencesAsync _prefs;

  static Future<void> init() async {
    SharedPreferences.setPrefix("chatbot");
    _prefs = SharedPreferencesAsync();
    await _init();
  }

  static bool get search => _search;
  static bool get googleSearch => _googleSearch;

  static set search(bool value) {
    _search = value;
    _prefs.setBool("search", value);
  }

  static set googleSearch(bool value) {
    _googleSearch = value;
    _prefs.setBool("googleSearch", value);
  }

  static Future<void> _init() async {
    _search = await _prefs.getBool("search") ?? false;
    _googleSearch = await _prefs.getBool("googleSearch") ?? false;
  }
}

const Color _baseColor = Colors.indigo;

final ColorScheme darkColorScheme = ColorScheme.fromSeed(
  brightness: Brightness.dark,
  seedColor: _baseColor,
);

final ColorScheme lightColorScheme = ColorScheme.fromSeed(
  brightness: Brightness.light,
  seedColor: _baseColor,
);

final ThemeData darkTheme = ThemeData.dark(useMaterial3: true).copyWith(
  colorScheme: darkColorScheme,
  bottomSheetTheme: BottomSheetThemeData(
    backgroundColor: darkColorScheme.surface,
  ),
  appBarTheme: AppBarTheme(color: darkColorScheme.primaryContainer),
);

final ThemeData lightTheme = ThemeData.light(useMaterial3: true).copyWith(
  colorScheme: lightColorScheme,
  bottomSheetTheme: BottomSheetThemeData(
    backgroundColor: lightColorScheme.surface,
  ),
  appBarTheme: AppBarTheme(color: lightColorScheme.primaryContainer),
);
