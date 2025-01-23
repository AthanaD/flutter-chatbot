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

import "../config.dart";

import "dart:convert";

class Current {
  static Chat? chat;
  static List<Message> messages = [];
  static ChatCore chatCore = Config.chatCore;
  static TtsStatus ttsStatus = TtsStatus.nothing;
  static ChatStatus chatStatus = ChatStatus.nothing;

  static Future<void> load(Chat chat) async {
    messages.clear();
    final root = chat.messages.first;

    for (;;) {
      final next = root.child.target;
      if (next == null) break;
      messages.add(next);
    }

    Current.chat = chat;
    chatCore = ChatCore.fromJson(jsonDecode(chat.core));
  }

  static void newChat(String title) {
    final time = DateTime.now();

    final root = Message(
      text: "",
      time: time,
      images: const [],
      role: Message.root,
    );

    final chat = Chat(
      time: time,
      title: title,
      core: jsonEncode(chatCore),
    );

    chat.messages.add(root);

    Current.chat = chat;
    Config.chatBox.put(chat);
  }
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
