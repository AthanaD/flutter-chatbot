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

import "./gen/objectbox.g.dart";
// import "package:objectbox/objectbox.dart";

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

@Entity()
class Module {
  static const int chatCore = 1;
  static const int webSearch = 2;
  static const int vectorStore = 3;
  static const int textToSpeech = 4;
  static const int documentChunk = 5;
  static const int titleGeneration = 6;
  static const int imageGeneration = 7;
  static const int imageCompression = 8;

  @Id(assignable: true)
  int id;

  String json;

  Module({
    required this.id,
    required this.json,
  });
}

class ChatCore {
  String? _bot;
  set bot(String? value) => _bot = value;
  String? get bot => Config.bots.containsKey(_bot) ? _bot : null;

  String? _api;
  set api(String? value) => _api = value;
  String? get api => Config.apis.containsKey(_api) ? _api : null;

  String? _model;
  set model(String? value) => _model = value;
  String? get model =>
      (Config.apis[_api]?.models.contains(_model) ?? false) ? _model : null;

  ChatCore({
    String? bot,
    String? api,
    String? model,
  })  : _bot = bot,
        _api = api,
        _model = model;

  factory ChatCore.fromJson(Map<String, dynamic> json) => ChatCore(
        bot: json["bot"],
        api: json["api"],
        model: json["model"],
      );

  Map<String, dynamic> toJson() => {
        "bot": bot,
        "api": api,
        "model": model,
      };
}

class WebSearch {
  int? n;
  bool? vector;
  int? queryTime;
  int? fetchTime;
  String? prompt;
  String? searxng;

  WebSearch({
    this.n,
    this.vector,
    this.prompt,
    this.searxng,
    this.queryTime,
    this.fetchTime,
  });

  factory WebSearch.fromJson(Map<String, dynamic> json) => WebSearch(
        n: json["n"],
        vector: json["vector"],
        prompt: json["prompt"],
        queryTime: json["query"],
        fetchTime: json["fetch"],
        searxng: json["searxng"],
      );

  Map<String, dynamic> toJson() => {
        "n": n,
        "vector": vector,
        "prompt": prompt,
        "query": queryTime,
        "fetch": fetchTime,
        "searxng": searxng,
      };
}

class VectorStore {
  int? batchSize;
  int? dimensions;

  String? _api;
  set api(String? value) => _api = value;
  String? get api => Config.apis.containsKey(_api) ? _api : null;

  String? _model;
  set model(String? value) => _model = value;
  String? get model =>
      (Config.apis[_api]?.models.contains(_model) ?? false) ? _model : null;

  VectorStore({
    String? api,
    String? model,
    this.batchSize,
    this.dimensions,
  })  : _api = api,
        _model = model;

  factory VectorStore.fromJson(Map<String, dynamic> json) => VectorStore(
        api: json["api"],
        model: json["model"],
        batchSize: json["batchSize"],
        dimensions: json["dimensions"],
      );

  Map<String, dynamic> toJson() => {
        "api": api,
        "model": model,
        "batchSize": batchSize,
        "dimensions": dimensions,
      };
}

class TextToSpeech {
  String? voice;

  String? _api;
  set api(String? value) => _api = value;
  String? get api => Config.apis.containsKey(_api) ? _api : null;

  String? _model;
  set model(String? value) => _model = value;
  String? get model =>
      (Config.apis[_api]?.models.contains(_model) ?? false) ? _model : null;

  TextToSpeech({
    String? api,
    String? model,
    this.voice,
  })  : _api = api,
        _model = model;

  factory TextToSpeech.fromJson(Map<String, dynamic> json) => TextToSpeech(
        api: json["api"],
        model: json["model"],
        voice: json["voice"],
      );

  Map<String, dynamic> toJson() => {
        "api": api,
        "model": model,
        "voice": voice,
      };
}

class DocumentChunk {
  int? n;
  int? size;
  int? overlap;

  DocumentChunk({
    this.n,
    this.size,
    this.overlap,
  });

  factory DocumentChunk.fromJson(Map<String, dynamic> json) => DocumentChunk(
        n: json["n"],
        size: json["size"],
        overlap: json["overlap"],
      );

  Map<String, dynamic> toJson() => {
        "n": n,
        "size": size,
        "overlap": overlap,
      };
}

class TitleGeneration {
  bool? enable;
  String? prompt;

  String? _api;
  set api(String? value) => _api = value;
  String? get api => Config.apis.containsKey(_api) ? _api : null;

  String? _model;
  set model(String? value) => _model = value;
  String? get model =>
      (Config.apis[_api]?.models.contains(_model) ?? false) ? _model : null;

  TitleGeneration({
    String? api,
    String? model,
    this.enable,
    this.prompt,
  })  : _api = api,
        _model = model;

  factory TitleGeneration.fromJson(Map<String, dynamic> json) =>
      TitleGeneration(
        api: json["api"],
        model: json["model"],
        prompt: json["prompt"],
        enable: json["enable"],
      );

  Map<String, dynamic> toJson() => {
        "api": api,
        "model": model,
        "prompt": prompt,
        "enable": enable,
      };
}

class ImageGeneration {
  String? size;
  String? style;
  String? quality;

  String? _api;
  set api(String? value) => _api = value;
  String? get api => Config.apis.containsKey(_api) ? _api : null;

  String? _model;
  set model(String? value) => _model = value;
  String? get model =>
      (Config.apis[_api]?.models.contains(_model) ?? false) ? _model : null;

  ImageGeneration({
    String? api,
    String? model,
    this.size,
    this.style,
    this.quality,
  })  : _api = api,
        _model = model;

  factory ImageGeneration.fromJson(Map<String, dynamic> json) =>
      ImageGeneration(
        api: json["api"],
        size: json["size"],
        model: json["model"],
        style: json["style"],
        quality: json["quality"],
      );

  Map<String, dynamic> toJson() => {
        "api": api,
        "model": model,
        "size": size,
        "style": style,
        "quality": quality,
      };
}

class ImageCompression {
  bool? enable;
  int? quality;
  int? minWidth;
  int? minHeight;

  ImageCompression({
    this.enable,
    this.quality,
    this.minWidth,
    this.minHeight,
  });

  factory ImageCompression.fromJson(Map<String, dynamic> json) =>
      ImageCompression(
        enable: json["enable"],
        quality: json["quality"],
        minWidth: json["minWidth"],
        minHeight: json["minHeight"],
      );

  Map<String, dynamic> toJson() => {
        "enable": enable,
        "quality": quality,
        "minWidth": minWidth,
        "minHeight": minHeight,
      };
}

@Entity()
class Bot {
  @Id()
  int id = 0;

  @Unique()
  String name;

  bool? stream;
  int? maxTokens;
  double? temperature;
  String? systemPrompts;

  Bot({
    required this.name,
    this.stream,
    this.maxTokens,
    this.temperature,
    this.systemPrompts,
  });

  factory Bot.fromJson(Map<String, dynamic> json) => Bot(
        name: json["name"],
        stream: json["stream"],
        maxTokens: json["maxTokens"],
        temperature: json["temperature"],
        systemPrompts: json["systemPrompts"],
      );

  Map<String, dynamic> toJson() => {
        "name": name,
        "stream": stream,
        "maxTokens": maxTokens,
        "temperature": temperature,
        "systemPrompts": systemPrompts,
      };
}

@Entity()
class Api {
  @Id()
  int id = 0;

  @Unique()
  String name;

  String url;
  String key;
  String? type;
  List<String> models;

  Api({
    required this.url,
    required this.key,
    required this.name,
    required this.models,
    this.type,
  });

  factory Api.fromJson(Map<String, dynamic> json) => Api(
        url: json["url"],
        key: json["key"],
        name: json["name"],
        type: json["type"],
        models: json["models"].cast<String>(),
      );

  Map<String, dynamic> toJson() => {
        "url": url,
        "key": key,
        "name": name,
        "type": type,
        "models": models,
      };
}

@Entity()
class Chat {
  @Id()
  int id = 0;

  String core;
  String title;

  @Property(type: PropertyType.date)
  DateTime time;

  @Backlink("chat")
  final messages = ToMany<Message>();

  Chat({
    required this.core,
    required this.time,
    required this.title,
  });

  factory Chat.fromJson(Map<String, dynamic> json) => Chat(
        core: json["core"],
        title: json["title"],
        time: DateTime.fromMillisecondsSinceEpoch(json["time"]),
      );

  Map<String, dynamic> toJson() => {
        "core": core,
        "title": title,
        "time": time.millisecondsSinceEpoch,
      };
}

@Entity()
class Message {
  static const int user = 0;
  static const int assistant = 1;

  @Id()
  int id = 0;

  int role;
  String? text;
  String? model;

  @Property(type: PropertyType.date)
  DateTime time;

  List<String> images;
  final chat = ToOne<Chat>();

  Message({
    required this.role,
    required this.time,
    required this.images,
  });

  @Transient()
  bool get isUser => role == user;

  @Transient()
  bool get isAssistant => role == assistant;
}

@Entity()
class Model {
  @Id()
  int id = 0;

  @Unique()
  String mid;

  bool chat;
  String name;

  Model({
    required this.mid,
    required this.chat,
    required this.name,
  });

  factory Model.fromJson(Map<String, dynamic> json) => Model(
        mid: json["id"],
        chat: json["chat"],
        name: json["name"],
      );

  Map<String, dynamic> toJson() => {
        "id": mid,
        "chat": chat,
        "name": name,
      };
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
