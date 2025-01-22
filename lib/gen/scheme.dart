import "package:objectbox/objectbox.dart";

export "objectbox.g.dart";

@Entity()
class Module {
  @Id(assignable: true)
  int id;

  String json;

  Module({
    required this.id,
    required this.json,
  });
}

@Entity()
class Bot {
  @Id()
  int id = 0;

  @Unique()
  String name;

  bool stream;
  int? maxTokens;
  double? temperature;
  String? systemPrompts;

  Bot({
    required this.name,
    this.stream = true,
    this.maxTokens,
    this.temperature,
    this.systemPrompts,
  });
}

@Entity()
class Api {
  static const int openai = 1;
  static const int google = 2;

  @Id()
  int id = 0;

  @Unique()
  String name;

  int type;
  String url;
  String key;
  List<String> models;

  Api({
    required this.url,
    required this.key,
    required this.name,
    required this.models,
    this.type = openai,
  });
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
}

@Entity()
class Message {
  static const int user = 0;
  static const int system = 1;
  static const int assistant = 2;

  @Id()
  int id = 0;

  int role;
  String text;
  String? model;

  @Property(type: PropertyType.date)
  DateTime time;

  List<String> images;
  final chat = ToOne<Chat>();

  final parent = ToOne<Message>();

  @Backlink("parent")
  final children = ToMany<Message>();

  Message({
    required this.role,
    required this.text,
    required this.time,
    required this.images,
  });

  @Transient()
  bool get isUser => role == user;

  @Transient()
  bool get isAssistant => role == assistant;
}
