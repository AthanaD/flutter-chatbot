import "../config.dart";
import "package:json_annotation/json_annotation.dart";

part "module.g.dart";

@JsonSerializable()
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
  }) {
    this.bot = bot;
    this.api = api;
    this.model = model;
  }

  factory ChatCore.fromJson(Map<String, dynamic> json) =>
      _$ChatCoreFromJson(json);

  Map<String, dynamic> toJson() => _$ChatCoreToJson(this);
}

@JsonSerializable()
class WebSearch {
  @JsonKey(defaultValue: 64)
  int n;

  @JsonKey(defaultValue: true)
  bool vector;

  @JsonKey(defaultValue: 3000)
  int queryTime;

  @JsonKey(defaultValue: 2000)
  int fetchTime;

  String? prompt;
  String? searxng;

  WebSearch({
    required this.n,
    required this.vector,
    required this.queryTime,
    required this.fetchTime,
    this.prompt,
    this.searxng,
  });

  factory WebSearch.fromJson(Map<String, dynamic> json) =>
      _$WebSearchFromJson(json);

  Map<String, dynamic> toJson() => _$WebSearchToJson(this);
}

@JsonSerializable()
class VectorStore {
  @JsonKey(defaultValue: 64)
  int batchSize;

  int? dimensions;

  String? _api;
  set api(String? value) => _api = value;
  String? get api => Config.apis.containsKey(_api) ? _api : null;

  String? _model;
  set model(String? value) => _model = value;
  String? get model =>
      (Config.apis[_api]?.models.contains(_model) ?? false) ? _model : null;

  VectorStore({
    required this.batchSize,
    String? api,
    String? model,
    this.dimensions,
  }) {
    this.api = api;
    this.model = model;
  }

  factory VectorStore.fromJson(Map<String, dynamic> json) =>
      _$VectorStoreFromJson(json);

  Map<String, dynamic> toJson() => _$VectorStoreToJson(this);
}

@JsonSerializable()
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
  }) {
    this.api = api;
    this.model = model;
  }

  factory TextToSpeech.fromJson(Map<String, dynamic> json) =>
      _$TextToSpeechFromJson(json);

  Map<String, dynamic> toJson() => _$TextToSpeechToJson(this);
}

@JsonSerializable()
class DocumentChunk {
  @JsonKey(defaultValue: 8)
  int n;

  @JsonKey(defaultValue: 1200)
  int size;

  @JsonKey(defaultValue: 80)
  int overlap;

  DocumentChunk({
    required this.n,
    required this.size,
    required this.overlap,
  });

  factory DocumentChunk.fromJson(Map<String, dynamic> json) =>
      _$DocumentChunkFromJson(json);

  Map<String, dynamic> toJson() => _$DocumentChunkToJson(this);
}

@JsonSerializable()
class TitleGeneration {
  @JsonKey(defaultValue: false)
  bool enable;

  String? prompt;

  String? _api;
  set api(String? value) => _api = value;
  String? get api => Config.apis.containsKey(_api) ? _api : null;

  String? _model;
  set model(String? value) => _model = value;
  String? get model =>
      (Config.apis[_api]?.models.contains(_model) ?? false) ? _model : null;

  TitleGeneration({
    required this.enable,
    String? api,
    String? model,
    this.prompt,
  }) {
    this.api = api;
    this.model = model;
  }

  factory TitleGeneration.fromJson(Map<String, dynamic> json) =>
      _$TitleGenerationFromJson(json);

  Map<String, dynamic> toJson() => _$TitleGenerationToJson(this);
}

@JsonSerializable()
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
      _$ImageGenerationFromJson(json);

  Map<String, dynamic> toJson() => _$ImageGenerationToJson(this);
}

@JsonSerializable()
class ImageCompression {
  @JsonKey(defaultValue: true)
  bool enable;

  @JsonKey(defaultValue: 80)
  int quality;

  @JsonKey(defaultValue: 1920)
  int minWidth;

  @JsonKey(defaultValue: 1080)
  int minHeight;

  ImageCompression({
    required this.enable,
    required this.quality,
    required this.minWidth,
    required this.minHeight,
  });

  factory ImageCompression.fromJson(Map<String, dynamic> json) =>
      _$ImageCompressionFromJson(json);

  Map<String, dynamic> toJson() => _$ImageCompressionToJson(this);
}
