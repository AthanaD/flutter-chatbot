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

import "message.dart";
import "../util.dart";
import "../config.dart";

import "dart:io";
import "dart:isolate";
import "dart:convert";

class Current {
  static File? _file;
  static Chat? _chat;

  static ChatCore core = Config.chatCore;
  static final List<Message> messages = [];
  static TtsStatus ttsStatus = TtsStatus.nothing;
  static ChatStatus chatStatus = ChatStatus.nothing;

  static Future<void> load(Chat chat) async {
    _file = File(Config.chatFilePath(chat.fileName));
    final from = _file;

    final json = await Isolate.run(() async {
      return jsonDecode(await from!.readAsString());
    });

    final messagesJson = json["messages"] ?? [];
    final coreJson = json["core"];

    messages.clear();
    for (final message in messagesJson) {
      messages.add(Message.fromJson(message));
    }

    core = coreJson != null ? ChatCore.fromJson(coreJson) : Config.chatCore;
  }

  static Future<void> save() async {
    await _file!.writeAsString(jsonEncode({
      "core": core,
      "messages": messages,
    }));
  }

  static void clear() {
    _chat = null;
    _file = null;
    messages.clear();
    core = Config.chatCore;
  }

  static void newChat(String title) {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch.toString();

    final time = Util.formatDateTime(now);
    final fileName = "$timestamp.json";

    _chat = Chat(
      time: time,
      title: title,
      fileName: fileName,
    );
    _file = File(Config.chatFilePath(fileName));

    Config.chats.insert(0, _chat!);
    Config.save();
  }

  static String? get bot => core.bot;
  static String? get api => core.api;
  static String? get model => core.model;

  static Api? get _api => Config.apis[api];
  static Bot? get _bot => Config.bots[bot];

  static String? get apiUrl => _api?.url;
  static String? get apiKey => _api?.key;
  static String? get apiType => _api?.type;

  static bool? get stream => _bot?.stream;
  static int? get maxTokens => _bot?.maxTokens;
  static double? get temperature => _bot?.temperature;
  static String? get systemPrompts => _bot?.systemPrompts;

  static Chat? get chat => _chat;
  static set chat(Chat? chat) => _chat = chat!;

  static String? get title => _chat?.title;
  static set title(String? title) => _chat?.title = title!;

  static bool get hasChat => _chat != null;
}

enum TtsStatus {
  nothing,
  loading,
  playing;

  bool get isNothing => this == TtsStatus.nothing;
  bool get isLoading => this == TtsStatus.loading;
  bool get isPlaying => this == TtsStatus.playing;
}

enum ChatStatus {
  nothing,
  responding;

  bool get isNothing => this == ChatStatus.nothing;
  bool get isResponding => this == ChatStatus.responding;
}
