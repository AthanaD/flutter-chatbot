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
import "package:http/http.dart";
import "package:flutter/material.dart";
import "package:archive/archive_io.dart";
import "package:path_provider/path_provider.dart";
import "package:package_info_plus/package_info_plus.dart";
import "package:shared_preferences/shared_preferences.dart";

import "./gen/objectbox.g.dart";
//import "package:objectbox/objectbox.dart";

class Config {
  static late final ChatCore core;
  static late final WebSearch search;
  static late final TextToSpeech tts;
  static late final ImageCompression cic;
  static late final VectorStore vector;
  static late final ImageGeneration image;
  static late final TitleGeneration title;
  static late final DocumentChunk document;

  static final List<Chat> chats = [];
  static final Map<String, Bot> bots = {};
  static final Map<String, Api> apis = {};
  static final Map<String, Model> models = {};

  static late final File _file;
  static late final String _dir;
  static late final String _sep;
  static late final String _cache;

  static const String _chatDir = "chat";
  static const String _audioDir = "audio";
  static const String _imageDir = "image";
  static const String _settingsFile = "settings.json";

  static late final Store store;
  static late final Box<Bot> botBox;
  static late final Box<Api> apiBox;
  static late final Box<Chat> chatBox;
  static late final Box<Model> modelBox;
  static late final Box<Module> moduleBox;

  static Future<void> _initDb() async {
    store = await openStore(
      directory: _dir,
    );
    botBox = store.box<Bot>();
    apiBox = store.box<Api>();
    chatBox = store.box<Chat>();
    modelBox = store.box<Model>();
    moduleBox = store.box<Module>();
  }

  static void saveModule(String key, Object module) {
    moduleBox.put(Module(
      key: key,
      value: jsonEncode(module),
    ));
  }

  static Future<void> _migrate() async {
    final file = File("$_dir$_sep$_settingsFile");
    if (!file.existsSync()) return;

    final json = jsonDecode(file.readAsStringSync());

    Map<String, dynamic> ttsJson = json["tts"] ?? {};
    Map<String, dynamic> cicJson = json["cic"] ?? {};
    Map<String, dynamic> coreJson = json["core"] ?? {};
    Map<String, dynamic> imageJson = json["image"] ?? {};
    Map<String, dynamic> titleJson = json["title"] ?? {};
    Map<String, dynamic> searchJson = json["search"] ?? {};
    Map<String, dynamic> vectorJson = json["vector"] ?? {};
    Map<String, dynamic> documentJson = json["document"] ?? {};

    Map<String, dynamic> botsJson = json["bots"] ?? {};
    Map<String, dynamic> apisJson = json["apis"] ?? {};
    Map<String, dynamic> modelsJson = json["models"] ?? {};

    final core = ChatCore.fromJson(coreJson);
    final tts = TextToSpeech.fromJson(ttsJson);
    final search = WebSearch.fromJson(searchJson);
    final cic = ImageCompression.fromJson(cicJson);
    final vector = VectorStore.fromJson(vectorJson);
    final image = ImageGeneration.fromJson(imageJson);
    final title = TitleGeneration.fromJson(titleJson);
    final document = DocumentChunk.fromJson(documentJson);

    saveModule(Module.chatCore, core);
    saveModule(Module.webSearch, search);
    saveModule(Module.textToSpeech, tts);
    saveModule(Module.vectorStore, vector);
    saveModule(Module.imageCompression, cic);
    saveModule(Module.imageGeneration, image);
    saveModule(Module.titleGeneration, title);
    saveModule(Module.documentChunk, document);

    for (final pair in botsJson.entries) {
      final json = pair.value..["name"] = pair.key;
      botBox.put(Bot.fromJson(json));
    }
    for (final pair in apisJson.entries) {
      final json = pair.value..["name"] = pair.key;
      apiBox.put(Api.fromJson(json));
    }
    for (final pair in modelsJson.entries) {
      final json = pair.value..["id"] = pair.key;
      modelBox.put(Model.fromJson(json));
    }
  }

  static Future<void> init() async {
    _sep = Platform.pathSeparator;
    _cache = (await getTemporaryDirectory()).path;
    if (Platform.isAndroid) {
      _dir = (await getExternalStorageDirectory())!.path;
    } else {
      _dir = (await getApplicationSupportDirectory()).path;
    }

    await _initDb();
    await _migrate();

    _initDir();
    _initFile();

    await Preferences.init();
  }

  static Future<void> save() async {
    await _file.writeAsString(jsonEncode(toJson()));
  }

  static String chatFilePath(String fileName) =>
      "$_dir$_sep$_chatDir$_sep$fileName";
  static String audioFilePath(String fileName) =>
      "$_dir$_sep$_audioDir$_sep$fileName";
  static String imageFilePath(String fileName) =>
      "$_dir$_sep$_imageDir$_sep$fileName";
  static String cacheFilePath(String fileName) => "$_cache$_sep$fileName";

  static Map toJson() => {
        "tts": tts,
        "cic": cic,
        "core": core,
        "bots": bots,
        "apis": apis,
        "chats": chats,
        "image": image,
        "title": title,
        "search": search,
        "vector": vector,
        "models": models,
        "document": document,
      };

  static void fromJson(Map json) {
    final ttsJson = json["tts"] ?? {};
    final imgJson = json["cic"] ?? {};
    final coreJson = json["core"] ?? {};
    final botsJson = json["bots"] ?? {};
    final apisJson = json["apis"] ?? {};
    final chatsJson = json["chats"] ?? [];
    final imageJson = json["image"] ?? {};
    final titleJson = json["title"] ?? {};
    final searchJson = json["search"] ?? {};
    final vectorJson = json["vector"] ?? {};
    final modelsJson = json["models"] ?? {};
    final documentJson = json["document"] ?? {};

    tts = TextToSpeech.fromJson(ttsJson);
    cic = ImageCompression.fromJson(imgJson);
    core = ChatCore.fromJson(coreJson);
    image = ImageGeneration.fromJson(imageJson);
    title = TitleGeneration.fromJson(titleJson);
    search = WebSearch.fromJson(searchJson);
    vector = VectorStore.fromJson(vectorJson);
    document = DocumentChunk.fromJson(documentJson);

    for (final chat in chatsJson) {
      chats.add(Chat.fromJson(chat));
    }
    for (final pair in botsJson.entries) {
      final json = pair.value..["name"] = pair.key;
      bots[pair.key] = Bot.fromJson(json);
    }
    for (final pair in apisJson.entries) {
      final json = pair.value..["name"] = pair.key;
      apis[pair.key] = Api.fromJson(json);
    }
    for (final pair in modelsJson.entries) {
      final json = pair.value..["id"] = pair.key;
      models[pair.key] = Model.fromJson(json);
    }
  }

  static void _initDir() {
    final chatPath = "$_dir$_sep$_chatDir";
    final chatDir = Directory(chatPath);
    if (!(chatDir.existsSync())) {
      chatDir.createSync();
    }

    final imagePath = "$_dir$_sep$_imageDir";
    final imageDir = Directory(imagePath);
    if (!(imageDir.existsSync())) {
      imageDir.createSync();
    }

    final audioPath = "$_dir$_sep$_audioDir";
    final audioDir = Directory(audioPath);
    if (!(audioDir.existsSync())) {
      audioDir.createSync();
    }
  }

  static void _initFile() {
    final path = "$_dir$_sep$_settingsFile";
    _file = File(path);

    if (_file.existsSync()) {
      final data = _file.readAsStringSync();
      fromJson(jsonDecode(data));
    } else {
      fromJson({});
    }
  }
}

class Backup {
  static Future<void> exportConfig(String to) async {
    final time = DateTime.now().millisecondsSinceEpoch.toString();
    final path = "$to${Config._sep}chatbot-backup-$time.zip";
    final root = Directory(Config._dir);

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
    final root = Config._dir;

    await Isolate.run(() async {
      await extractFileToDisk(from, root);
    });
  }

  static Future<void> clearData(List<String> dirs) async {
    final root = Config._dir;
    final sep = Config._sep;

    await Isolate.run(() async {
      for (final dir in dirs) {
        final directory = Directory("$root$sep$dir");
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
  static const chatCore = "chat_core";
  static const webSearch = "web_search";
  static const vectorStore = "vector_store";
  static const textToSpeech = "text_to_speech";
  static const documentChunk = "document_chunk";
  static const titleGeneration = "title_generation";
  static const imageGeneration = "image_generation";
  static const imageCompression = "image_compression";

  @Id()
  int id = 0;

  @Index(type: IndexType.value)
  @Unique(onConflict: ConflictStrategy.replace)
  String key;

  String value;

  Module({
    required this.key,
    required this.value,
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
  DateTime time;

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
