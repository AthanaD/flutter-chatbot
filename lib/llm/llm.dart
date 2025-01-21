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

import "web.dart";
import "../config.dart";
import "../chat/chat.dart";
import "../chat/current.dart";
import "../chat/message.dart";
import "../markdown/util.dart";

import "dart:io";
import "dart:math";
import "dart:isolate";
import "dart:convert";
import "package:http/http.dart";
import "package:langchain/langchain.dart";
import "package:audioplayers/audioplayers.dart";
import "package:langchain_openai/langchain_openai.dart";
import "package:langchain_google/langchain_google.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

final llmProvider =
    AutoDisposeNotifierProvider<LlmNotifier, void>(LlmNotifier.new);

class LlmNotifier extends AutoDisposeNotifier<void> {
  Client? _ttsClient;
  Client? _chatClient;
  AudioPlayer? _player;

  @override
  void build() {}
  void notify() => ref.notifyListeners();

  void updateMessage(Message message) =>
      ref.read(messageProvider(message).notifier).notify();

  Future<dynamic> tts(Message message) async {
    dynamic error;

    final tts = Config.textToSpeech;
    final model = tts.model!;
    final voice = tts.voice!;
    final api = Config.apis[tts.api]!;

    final apiUrl = api.url;
    final apiKey = api.key;
    final endPoint = "$apiUrl/audio/speech";

    Current.ttsStatus = TtsStatus.loading;
    updateMessage(message);

    try {
      _ttsClient ??= Client();
      _player ??= AudioPlayer();
      final response = await _ttsClient!.post(
        Uri.parse(endPoint),
        headers: {
          "Authorization": "Bearer $apiKey",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "model": model,
          "voice": voice,
          "stream": false,
          "input": markdownToText(message.item.text),
        }),
      );

      if (response.statusCode != 200) {
        throw "${response.statusCode} ${response.body}";
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final path = Config.audioFilePath("$timestamp.mp3");

      final file = File(path);
      await file.writeAsBytes(response.bodyBytes);

      Current.ttsStatus = TtsStatus.playing;
      updateMessage(message);

      await _player!.play(DeviceFileSource(path));
      await _player!.onPlayerStateChanged.first;
    } catch (e) {
      if (!Current.ttsStatus.isNothing) error = e;
    }

    Current.ttsStatus = TtsStatus.nothing;
    updateMessage(message);
    return error;
  }

  void stopTts() {
    Current.ttsStatus = TtsStatus.nothing;
    _ttsClient?.close();
    _ttsClient = null;
    _player?.stop();
  }

  Future<dynamic> chat(Message message) async {
    dynamic error;

    final item = message.item;
    final model = Current.model!;
    final apiUrl = Current.apiUrl!;
    final apiKey = Current.apiKey!;
    final apiType = Current.apiType;
    final messages = Current.messages;

    Current.chatStatus = ChatStatus.responding;
    updateMessage(message);
    notify();

    try {
      final context = await _buildContext(messages);

      _chatClient = switch (apiType) {
        "google" => _GoogleClient(baseUrl: apiUrl),
        _ => Client(),
      };

      BaseChatModel llm = switch (apiType) {
        "google" => ChatGoogleGenerativeAI(
            apiKey: apiKey,
            baseUrl: apiUrl,
            client: _chatClient,
            defaultOptions: ChatGoogleGenerativeAIOptions(
              model: model,
              temperature: Current.temperature,
              maxOutputTokens: Current.maxTokens,
            ),
          ),
        _ => ChatOpenAI(
            apiKey: apiKey,
            baseUrl: apiUrl,
            client: _chatClient,
            defaultOptions: ChatOpenAIOptions(
              model: model,
              maxTokens: Current.maxTokens,
              temperature: Current.temperature,
            ),
          ),
      };

      if (Current.stream ?? true) {
        final stream = llm.stream(context);
        await for (final chunk in stream) {
          item.text += chunk.output.content;
          updateMessage(message);
        }
      } else {
        final result = await llm.invoke(context);
        item.text += result.output.content;
        updateMessage(message);
      }
    } catch (e) {
      if (!Current.chatStatus.isNothing) error = e;
      if (item.text.isEmpty) {
        if (message.list.length == 1) {
          messages.length -= 2;
          ref.read(messagesProvider.notifier).notify();
        } else {
          message.list.removeAt(message.index--);
          updateMessage(message);
        }
      }
    }

    Current.chatStatus = ChatStatus.nothing;
    updateMessage(message);
    notify();

    return error;
  }

  void stopChat() {
    Current.chatStatus = ChatStatus.nothing;
    _chatClient?.close();
    _chatClient = null;
  }

  Future<PromptValue> _buildContext(List<Message> messages) async {
    final context = <ChatMessage>[];
    final system = Current.systemPrompts;
    final items = messages.map((it) => it.item).toList();

    if (items.last.role.isAssistant) items.removeLast();

    if (Preferences.search && !Preferences.googleSearch) {
      items.last = await _buildWebContext(items.last);
      messages.last.item.citations = items.last.citations;
    }

    if (system != null) context.add(ChatMessage.system(system));

    for (final item in items) {
      switch (item.role) {
        case MessageRole.assistant:
          context.add(ChatMessage.ai(item.text));
          break;

        case MessageRole.user:
          if (item.images.isEmpty) {
            context.add(ChatMessage.humanText(item.text));
            break;
          }

          context.add(ChatMessage.human(ChatMessageContent.multiModal([
            ChatMessageContent.text(item.text),
            for (final image in item.images)
              ChatMessageContent.image(
                mimeType: "image/jpeg",
                data: image.base64,
              ),
          ])));
          break;
      }
    }

    return PromptValue.chat(context);
  }

  Future<MessageItem> _buildWebContext(MessageItem origin) async {
    final text = origin.text;

    _chatClient = Client();
    final urls = await _getWebPageUrls(
      text,
      Config.webSearch.n ?? 64,
    );
    if (urls.isEmpty) throw "No web page found.";

    final duration = Duration(milliseconds: Config.webSearch.fetchTime ?? 2000);
    var docs = await Isolate.run(() async {
      final loader = WebLoader(urls, timeout: duration);
      return await loader.load();
    });
    if (docs.isEmpty) throw "No web content retrieved.";

    if (Config.webSearch.vector ?? false) {
      final vector = Config.vectorStore;
      final document = Config.documentChunk;
      final api = Config.apis[vector.api]!;

      final apiUrl = api.url;
      final apiKey = api.key;
      final apiType = api.type;
      final model = vector.model!;
      final dimensions = vector.dimensions;
      final batchSize = vector.batchSize ?? 64;

      final topK = document.n ?? 8;
      final chunkSize = document.size ?? 2000;
      final chunkOverlap = document.overlap ?? 100;

      final splitter = RecursiveCharacterTextSplitter(
        chunkSize: chunkSize,
        chunkOverlap: chunkOverlap,
      );

      _chatClient = switch (apiType) {
        "google" => _GoogleClient(
            baseUrl: apiUrl,
            enableSearch: false,
          ),
        _ => _chatClient,
      };

      final embeddings = switch (apiType) {
        "google" => GoogleGenerativeAIEmbeddings(
            model: model,
            apiKey: apiKey,
            baseUrl: apiUrl,
            client: _chatClient,
            batchSize: batchSize,
            dimensions: dimensions,
          ),
        _ => OpenAIEmbeddings(
            model: model,
            apiKey: apiKey,
            baseUrl: apiUrl,
            client: _chatClient,
            batchSize: batchSize,
            dimensions: dimensions,
          ),
      };

      final vectorStore = MemoryVectorStore(
        embeddings: embeddings,
      );

      docs = await Isolate.run(() => splitter.splitDocuments(docs));
      await vectorStore.addDocuments(documents: docs);

      docs = await vectorStore.search(
        query: text,
        searchType: VectorStoreSearchType.similarity(
          k: topK,
        ),
      );
    }

    final pages = docs.map((it) => "<webPage>\n${it.pageContent}\n</webPage>");
    final template = Config.webSearch.prompt ??
        """
You are now an AI model with internet search capabilities.
You can answer user questions based on content from the internet.
I will provide you with some information from web pages on the internet.
Each <webPage> tag below contains the content of a web page:
{pages}

You need to answer the user's question based on the above content:
{text}
        """
            .trim();

    final context = PromptTemplate.fromTemplate(template).format({
      "pages": pages.join("\n\n"),
      "text": text,
    });

    final item = MessageItem(
      role: MessageRole.user,
      text: context,
    );

    for (final doc in docs) {
      item.citations.add((
        type: CitationType.web,
        content: doc.pageContent,
        source: doc.metadata["source"],
      ));
    }

    return item;
  }

  Future<List<String>> _getWebPageUrls(String query, int n) async {
    final searxng = Config.webSearch.searxng!;
    final baseUrl = searxng.replaceFirst("{text}", query);

    final badResponse = Response("Request Timeout", 408);
    final duration = Duration(milliseconds: Config.webSearch.queryTime ?? 3000);

    Uri uriOf(int i) => Uri.parse("$baseUrl&pageno=$i");
    final responses = await Future.wait(List.generate(
      (n / 16).ceil(),
      (i) => _chatClient!
          .get(uriOf(i))
          .timeout(duration)
          .catchError((_) => badResponse),
    ));

    final urls = <String>[];

    for (final res in responses) {
      if (res.statusCode != 200) continue;
      final json = jsonDecode(res.body);
      final results = json["results"];
      for (final it in results) {
        urls.add(it["url"]);
      }
    }

    n = min(n, urls.length);
    return urls.sublist(0, n);
  }
}

Future<String> generateTitle(String text) async {
  if (!(Config.titleGeneration.enable ?? false)) return text;

  final model = Config.titleGeneration.model;
  final api = Config.apis[Config.titleGeneration.api];
  if (api == null || model == null) return text;

  final prompt = Config.titleGeneration.prompt ??
      """
Based on the user input below, generate a concise and relevant title.
Note: Only return the title text, without any additional content!

Output examples:
1. C Language Discussion
2. 数学问题解答
3. 電影推薦

User input:
{text}
      """
          .trim();

  final apiUrl = api.url;
  final apiKey = api.key;
  final apiType = api.type;

  final client = switch (apiType) {
    "google" => _GoogleClient(
        baseUrl: apiUrl,
        enableSearch: false,
      ),
    _ => Client(),
  };

  BaseChatModel llm = switch (apiType) {
    "google" => ChatGoogleGenerativeAI(
        apiKey: apiKey,
        client: client,
        baseUrl: apiUrl,
        defaultOptions: ChatGoogleGenerativeAIOptions(
          model: model,
        ),
      ),
    _ => ChatOpenAI(
        apiKey: apiKey,
        client: client,
        baseUrl: apiUrl,
        defaultOptions: ChatOpenAIOptions(
          model: model,
        ),
      ),
  };

  final chain = ChatPromptTemplate.fromTemplate(prompt).pipe(llm);
  final res = await chain.invoke({"text": text});
  return res.output.content.trim();
}

class _GoogleClient extends BaseClient {
  final String baseUrl;
  final bool enableSearch;

  final Client _client = Client();

  _GoogleClient({
    required this.baseUrl,
    this.enableSearch = true,
  });

  BaseRequest _hook(BaseRequest origin) {
    if (origin is! Request) {
      return origin;
    }

    final request = Request(
      origin.method,
      Uri.parse("${origin.url}".replaceFirst(
        "https://generativelanguage.googleapis.com/v1beta",
        baseUrl,
      )),
    );
    request.headers.addAll(origin.headers);

    final bodyJson = jsonDecode(origin.body);
    if (enableSearch && Preferences.search && Preferences.googleSearch) {
      bodyJson["tools"] = const [
        {"google_search": {}},
      ];
    }

    request.body = jsonEncode(bodyJson);
    return request;
  }

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    request = _hook(request);
    return _client.send(request);
  }

  @override
  void close() {
    super.close();
    _client.close();
  }
}
