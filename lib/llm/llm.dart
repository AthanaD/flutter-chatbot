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

import "package:chatbot/util.dart";

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
    final api = apiWith(tts.api)!;
    final model = tts.model!;
    final voice = tts.voice!;

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
          "input": markdownToText(message.text),
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

    final core = Current.chatCore;
    final bot = botWith(core.bot);
    final api = apiWith(core.api)!;
    final messages = Current.messages;

    Current.chatStatus = ChatStatus.responding;
    updateMessage(message);
    notify();

    try {
      final context = await _buildContext(messages);
      BaseChatModel llm;

      switch (api.type) {
        case Api.google:
          _chatClient = _GoogleClient(baseUrl: api.url);
          llm = ChatGoogleGenerativeAI(
            apiKey: api.key,
            baseUrl: api.url,
            client: _chatClient,
            defaultOptions: ChatGoogleGenerativeAIOptions(
              model: core.model,
              temperature: Current.temperature,
              maxOutputTokens: Current.maxTokens,
            ),
          );
          break;

        default:
          _chatClient = Client();
          llm = ChatOpenAI(
            apiKey: api.key,
            baseUrl: api.url,
            client: _chatClient,
            defaultOptions: ChatOpenAIOptions(
              model: core.model,
              maxTokens: Current.maxTokens,
              temperature: Current.temperature,
            ),
          );
          break;
      }

      if (bot?.stream ?? true) {
        final stream = llm.stream(context);
        await for (final chunk in stream) {
          message.text += chunk.output.content;
          updateMessage(message);
        }
      } else {
        final result = await llm.invoke(context);
        message.text += result.output.content;
        updateMessage(message);
      }
    } catch (e) {
      if (!Current.chatStatus.isNothing) error = e;
      if (message.text.isEmpty) {
        // if (message.list.length == 1) {
        //   messages.length -= 2;
        //   ref.read(messagesProvider.notifier).notify();
        // } else {
        //   message.list.removeAt(message.index--);
        //   updateMessage(message);
        // }
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
    messages = List.of(messages);
    final context = <ChatMessage>[];
    final system = Current.systemPrompts;

    if (messages.last.isAssistant) messages.removeLast();

    if (Preferences.search && !Preferences.googleSearch) {
      messages.last = await _buildWebContext(messages.last);
      // messages.last.citations = items.last.citations;
    }

    if (system != null) context.add(ChatMessage.system(system));

    for (final item in messages) {
      switch (item.role) {
        case Message.assistant:
          context.add(ChatMessage.ai(item.text));
          break;

        case Message.user:
          if (item.images.isEmpty) {
            context.add(ChatMessage.humanText(item.text));
            break;
          }

          context.add(ChatMessage.human(ChatMessageContent.multiModal([
            ChatMessageContent.text(item.text),
            for (final image in item.images)
              ChatMessageContent.image(
                mimeType: "image/jpeg",
                data: image,
              ),
          ])));
          break;
      }
    }

    return PromptValue.chat(context);
  }

  Future<Message> _buildWebContext(Message origin) async {
    final text = origin.text;

    _chatClient = Client();
    final urls = await _getWebPageUrls(
      text,
      Config.webSearch.n,
    );
    if (urls.isEmpty) throw "No web page found.";

    final duration = Duration(milliseconds: Config.webSearch.fetchTime);
    var docs = await Isolate.run(() async {
      final loader = WebLoader(urls, timeout: duration);
      return await loader.load();
    });
    if (docs.isEmpty) throw "No web content retrieved.";

    if (Config.webSearch.vector) {
      final vector = Config.vectorStore;
      final chunk = Config.documentChunk;
      final api = apiWith(vector.api)!;

      final batchSize = vector.batchSize;
      final dimensions = vector.dimensions;

      final topK = chunk.n;
      final chunkSize = chunk.size;
      final chunkOverlap = chunk.overlap;

      final splitter = RecursiveCharacterTextSplitter(
        chunkSize: chunkSize,
        chunkOverlap: chunkOverlap,
      );

      Embeddings embeddings;

      switch (api.type) {
        case Api.google:
          _chatClient = _GoogleClient(
            baseUrl: api.url,
            enableSearch: false,
          );
          embeddings = GoogleGenerativeAIEmbeddings(
            apiKey: api.key,
            baseUrl: api.url,
            client: _chatClient,
            model: vector.model!,
            batchSize: batchSize,
            dimensions: dimensions,
          );
          break;

        default:
          embeddings = OpenAIEmbeddings(
            apiKey: api.key,
            baseUrl: api.url,
            client: _chatClient,
            model: vector.model!,
            batchSize: batchSize,
            dimensions: dimensions,
          );
          break;
      }

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

    final ret = Message(
      text: context,
      role: origin.role,
      time: origin.time,
      images: origin.images,
    );

    // for (final doc in docs) {
    //   item.citations.add((
    //     type: CitationType.web,
    //     content: doc.pageContent,
    //     source: doc.metadata["source"],
    //   ));
    // }

    return ret;
  }

  Future<List<String>> _getWebPageUrls(String query, int n) async {
    final searxng = Config.webSearch.searxng!;
    final baseUrl = searxng.replaceFirst("{text}", query);

    final badResponse = Response("Request Timeout", 408);
    final duration = Duration(milliseconds: Config.webSearch.queryTime);

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
  if (!Config.titleGeneration.enable) return text;

  final config = Config.titleGeneration;
  if (Util.checkApiModel(config.api, config.model)) return text;

  final api = apiWith(config.api)!;
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

  Client client;
  BaseChatModel llm;

  switch (api.type) {
    case Api.google:
      client = _GoogleClient(baseUrl: api.url);
      llm = ChatGoogleGenerativeAI(
        apiKey: api.key,
        baseUrl: api.url,
        client: client,
        defaultOptions: ChatGoogleGenerativeAIOptions(
          model: config.model,
          temperature: Current.temperature,
          maxOutputTokens: Current.maxTokens,
        ),
      );
      break;

    default:
      client = Client();
      llm = ChatOpenAI(
        apiKey: api.key,
        baseUrl: api.url,
        client: client,
        defaultOptions: ChatOpenAIOptions(
          model: config.model,
          maxTokens: Current.maxTokens,
          temperature: Current.temperature,
        ),
      );
      break;
  }

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
