// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'module.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChatCore _$ChatCoreFromJson(Map<String, dynamic> json) => ChatCore(
      bot: (json['bot'] as num?)?.toInt(),
      api: (json['api'] as num?)?.toInt(),
      model: json['model'] as String?,
    );

Map<String, dynamic> _$ChatCoreToJson(ChatCore instance) => <String, dynamic>{
      'bot': instance.bot,
      'api': instance.api,
      'model': instance.model,
    };

WebSearch _$WebSearchFromJson(Map<String, dynamic> json) => WebSearch(
      n: (json['n'] as num?)?.toInt() ?? 64,
      vector: json['vector'] as bool? ?? true,
      queryTime: (json['queryTime'] as num?)?.toInt() ?? 3000,
      fetchTime: (json['fetchTime'] as num?)?.toInt() ?? 2000,
      prompt: json['prompt'] as String?,
      searxng: json['searxng'] as String?,
    );

Map<String, dynamic> _$WebSearchToJson(WebSearch instance) => <String, dynamic>{
      'n': instance.n,
      'vector': instance.vector,
      'queryTime': instance.queryTime,
      'fetchTime': instance.fetchTime,
      'prompt': instance.prompt,
      'searxng': instance.searxng,
    };

VectorStore _$VectorStoreFromJson(Map<String, dynamic> json) => VectorStore(
      batchSize: (json['batchSize'] as num?)?.toInt() ?? 64,
      api: (json['api'] as num?)?.toInt(),
      model: json['model'] as String?,
      dimensions: (json['dimensions'] as num?)?.toInt(),
    );

Map<String, dynamic> _$VectorStoreToJson(VectorStore instance) =>
    <String, dynamic>{
      'batchSize': instance.batchSize,
      'dimensions': instance.dimensions,
      'api': instance.api,
      'model': instance.model,
    };

TextToSpeech _$TextToSpeechFromJson(Map<String, dynamic> json) => TextToSpeech(
      api: (json['api'] as num?)?.toInt(),
      model: json['model'] as String?,
      voice: json['voice'] as String?,
    );

Map<String, dynamic> _$TextToSpeechToJson(TextToSpeech instance) =>
    <String, dynamic>{
      'api': instance.api,
      'model': instance.model,
      'voice': instance.voice,
    };

DocumentChunk _$DocumentChunkFromJson(Map<String, dynamic> json) =>
    DocumentChunk(
      n: (json['n'] as num?)?.toInt() ?? 8,
      size: (json['size'] as num?)?.toInt() ?? 1200,
      overlap: (json['overlap'] as num?)?.toInt() ?? 80,
    );

Map<String, dynamic> _$DocumentChunkToJson(DocumentChunk instance) =>
    <String, dynamic>{
      'n': instance.n,
      'size': instance.size,
      'overlap': instance.overlap,
    };

TitleGeneration _$TitleGenerationFromJson(Map<String, dynamic> json) =>
    TitleGeneration(
      enable: json['enable'] as bool? ?? false,
      api: (json['api'] as num?)?.toInt(),
      model: json['model'] as String?,
      prompt: json['prompt'] as String?,
    );

Map<String, dynamic> _$TitleGenerationToJson(TitleGeneration instance) =>
    <String, dynamic>{
      'enable': instance.enable,
      'api': instance.api,
      'model': instance.model,
      'prompt': instance.prompt,
    };

ImageGeneration _$ImageGenerationFromJson(Map<String, dynamic> json) =>
    ImageGeneration(
      api: (json['api'] as num?)?.toInt(),
      size: json['size'] as String?,
      model: json['model'] as String?,
      style: json['style'] as String?,
      quality: json['quality'] as String?,
    );

Map<String, dynamic> _$ImageGenerationToJson(ImageGeneration instance) =>
    <String, dynamic>{
      'api': instance.api,
      'size': instance.size,
      'model': instance.model,
      'style': instance.style,
      'quality': instance.quality,
    };

ImageCompression _$ImageCompressionFromJson(Map<String, dynamic> json) =>
    ImageCompression(
      enable: json['enable'] as bool? ?? true,
      quality: (json['quality'] as num?)?.toInt() ?? 80,
      minWidth: (json['minWidth'] as num?)?.toInt() ?? 1920,
      minHeight: (json['minHeight'] as num?)?.toInt() ?? 1080,
    );

Map<String, dynamic> _$ImageCompressionToJson(ImageCompression instance) =>
    <String, dynamic>{
      'enable': instance.enable,
      'quality': instance.quality,
      'minWidth': instance.minWidth,
      'minHeight': instance.minHeight,
    };
