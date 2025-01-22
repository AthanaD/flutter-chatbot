import "package:json_annotation/json_annotation.dart";

part "module.g.dart";

typedef JsonObject = Map<String, dynamic>;

const Map<Type, int> moduleIds = {
  ChatCore: 1,
  WebSearch: 2,
  VectorStore: 3,
  TextToSpeech: 4,
  DocumentChunk: 5,
  ImageGeneration: 6,
  TitleGeneration: 7,
  ImageCompression: 8,
};

@JsonSerializable()
class ChatCore {
  int? bot;
  int? api;
  String? model;

  ChatCore({
    this.bot,
    this.api,
    this.model,
  });

  factory ChatCore.fromJson(JsonObject json) => _$ChatCoreFromJson(json);

  JsonObject toJson() => _$ChatCoreToJson(this);
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

  factory WebSearch.fromJson(JsonObject json) => _$WebSearchFromJson(json);

  JsonObject toJson() => _$WebSearchToJson(this);
}

@JsonSerializable()
class VectorStore {
  @JsonKey(defaultValue: 64)
  int batchSize;

  int? dimensions;

  int? api;
  String? model;

  VectorStore({
    required this.batchSize,
    this.api,
    this.model,
    this.dimensions,
  });

  factory VectorStore.fromJson(JsonObject json) => _$VectorStoreFromJson(json);

  JsonObject toJson() => _$VectorStoreToJson(this);
}

@JsonSerializable()
class TextToSpeech {
  int? api;
  String? model;
  String? voice;

  TextToSpeech({
    this.api,
    this.model,
    this.voice,
  });

  factory TextToSpeech.fromJson(JsonObject json) =>
      _$TextToSpeechFromJson(json);

  JsonObject toJson() => _$TextToSpeechToJson(this);
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

  factory DocumentChunk.fromJson(JsonObject json) =>
      _$DocumentChunkFromJson(json);

  JsonObject toJson() => _$DocumentChunkToJson(this);
}

@JsonSerializable()
class TitleGeneration {
  @JsonKey(defaultValue: false)
  bool enable;

  int? api;
  String? model;
  String? prompt;

  TitleGeneration({
    required this.enable,
    this.api,
    this.model,
    this.prompt,
  });

  factory TitleGeneration.fromJson(JsonObject json) =>
      _$TitleGenerationFromJson(json);

  JsonObject toJson() => _$TitleGenerationToJson(this);
}

@JsonSerializable()
class ImageGeneration {
  int? api;
  String? size;
  String? model;
  String? style;
  String? quality;

  ImageGeneration({
    this.api,
    this.size,
    this.model,
    this.style,
    this.quality,
  });

  factory ImageGeneration.fromJson(JsonObject json) =>
      _$ImageGenerationFromJson(json);

  JsonObject toJson() => _$ImageGenerationToJson(this);
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

  factory ImageCompression.fromJson(JsonObject json) =>
      _$ImageCompressionFromJson(json);

  JsonObject toJson() => _$ImageCompressionToJson(this);
}
