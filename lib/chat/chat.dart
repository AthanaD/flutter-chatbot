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

import "input.dart";
import "message.dart";
import "current.dart";
import "../util.dart";
import "../config.dart";
import "../gen/l10n.dart";
import "../providers.dart";

import "dart:io";
import "dart:convert";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:langchain/langchain.dart";
import "package:image_picker/image_picker.dart";
import "package:langchain_openai/langchain_openai.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_image_compress/flutter_image_compress.dart";

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final ImagePicker _picker = ImagePicker();
  final ScrollController _scrollCtrl = ScrollController();
  final TextEditingController _inputCtrl = TextEditingController();

  Future<void> _addImage(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return Wrap(
          alignment: WrapAlignment.center,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 16, bottom: 8),
              decoration: const BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.all(Radius.circular(2)),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera),
              title: Text(S.of(context).camera),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(S.of(context).gallery),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        );
      },
    );
    if (source == null) return;

    final result = await _picker.pickImage(source: source);
    if (result == null) return;

    final compressed = await FlutterImageCompress.compressWithFile(result.path,
        quality: 60, minWidth: 1024, minHeight: 1024);
    Uint8List bytes = compressed ?? await File(result.path).readAsBytes();

    if (compressed == null && context.mounted) {
      Util.showSnackBar(
        context: context,
        content: Text(S.of(context).image_compress_failed),
      );
    }

    final base64 = base64Encode(bytes);
    setState(() => CurrentChat.image = base64);
  }

  void _clearImage(BuildContext context) {
    setState(() => CurrentChat.image = null);
  }

  Future<void> _sendMessage(BuildContext context) async {
    final text = _inputCtrl.text;
    if (text.isEmpty) return;

    final apiUrl = CurrentChat.apiUrl;
    final apiKey = CurrentChat.apiKey;
    final model = CurrentChat.model;

    if (apiUrl == null || apiKey == null || model == null) {
      Util.showSnackBar(
        context: context,
        content: Text(S.of(context).setup_bot_api_first),
      );
      return;
    }

    final messages = CurrentChat.messages;
    final length = messages.length;

    messages.add(Message(
      text: text,
      role: MessageRole.user,
      image: CurrentChat.image,
    ));
    final message = Message(role: MessageRole.assistant, text: "");
    final chatContext = _buildContext(messages);
    messages.add(message);

    _inputCtrl.clear();
    setState(() => CurrentChat.status = CurrentChatStatus.responding);

    try {
      final llm = ChatOpenAI(
        apiKey: apiKey,
        baseUrl: apiUrl,
        defaultOptions: ChatOpenAIOptions(
          model: model,
          maxTokens: CurrentChat.maxTokens,
          temperature: CurrentChat.temperature,
        ),
      );

      if (CurrentChat.stream ?? true) {
        final stream = llm.stream(PromptValue.chat(chatContext));
        await for (final chunk in stream) {
          if (CurrentChat.isNothing) break;
          final content = chunk.output.content;
          setState(() => message.text += content);
          _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
        }
      } else {
        final result = await llm.invoke(PromptValue.chat(chatContext));
        if (!CurrentChat.isNothing) {
          setState(() => message.text += result.output.content);
          _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
        }
      }

      if (messages.length == length + 2) {
        CurrentChat.image = null;
        await CurrentChat.save();
      }
    } catch (e) {
      if (messages.length == length + 2 && !CurrentChat.isNothing) {
        if (context.mounted) {
          Util.showSnackBar(
            context: context,
            content: Text("$e"),
            duration: const Duration(milliseconds: 1500),
          );
        }
        if (messages.last.text.isEmpty) {
          _inputCtrl.text = text;
          messages.length -= 2;
        }
      }
    }

    setState(() => CurrentChat.status = CurrentChatStatus.nothing);
  }

  void _stopResponding(BuildContext context) {
    CurrentChat.status = CurrentChatStatus.nothing;
    final list = CurrentChat.messages;

    setState(() {
      final user = list[list.length - 2];
      final assistant = list.last;

      if (assistant.text.isEmpty) {
        list.removeRange(list.length - 2, list.length);
        _inputCtrl.text = user.text;
      }
    });
  }

  Future<void> _longPress(BuildContext context, int index) async {
    final message = CurrentChat.messages[index];
    final children = [
      Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(top: 16, bottom: 8),
        decoration: const BoxDecoration(
          color: Colors.grey,
          borderRadius: BorderRadius.all(Radius.circular(2)),
        ),
      ),
      ListTile(
        title: Text(S.of(context).copy),
        leading: const Icon(Icons.copy_all),
        onTap: () => Navigator.pop(context, MessageEvent.copy),
      ),
      ListTile(
        title: Text(S.of(context).source),
        leading: const Icon(Icons.code_outlined),
        onTap: () => Navigator.pop(context, MessageEvent.source),
      ),
      // ListTile(
      //   title: Text(S.of(context).edit),
      //   leading: const Icon(Icons.edit_outlined),
      //   onTap: () => Navigator.pop(context, MessageEvent.edit),
      // ),
    ];

    if (message.role == MessageRole.user) {
      children.add(
        ListTile(
          title: Text(S.of(context).delete),
          leading: const Icon(Icons.delete_outlined),
          onTap: () => Navigator.pop(context, MessageEvent.delete),
        ),
      );
    }

    final event = await showModalBottomSheet<MessageEvent>(
      context: context,
      builder: (BuildContext context) {
        return Wrap(
          alignment: WrapAlignment.center,
          children: children,
        );
      },
    );
    if (event == null) return;

    switch (event) {
      case MessageEvent.copy:
        await Clipboard.setData(ClipboardData(text: message.text));
        if (context.mounted) {
          Util.showSnackBar(
            context: context,
            content: Text(S.of(context).copied_successfully),
          );
        }
        break;

      case MessageEvent.delete:
        setState(() => CurrentChat.messages.removeRange(index, index + 2));
        await CurrentChat.save();
        break;

      case MessageEvent.source:
        if (!context.mounted) return;
        await showDialog(
          context: context,
          builder: (context) {
            return Scaffold(
              appBar: AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                title: Text(S.of(context).source),
              ),
              body: Padding(
                padding: EdgeInsets.all(16),
                child: SingleChildScrollView(
                  child: SelectableText(message.text),
                ),
              ),
            );
          },
        );

        break;

      default:
        if (context.mounted) {
          Util.showSnackBar(
            context: context,
            content: Text(S.of(context).not_implemented_yet),
          );
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final drawer = Column(
      children: [
        ListTile(
          title: Text(
            "ChatBot",
            style: Theme.of(context).textTheme.titleLarge,
          ),
          contentPadding: const EdgeInsets.only(left: 16, right: 8),
        ),
        Divider(),
        Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
          child: Text(
            S.of(context).all_chats,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
        Expanded(
          child: Consumer(
            builder: (context, ref, child) {
              ref.watch(currentChatProvider);

              return ListView.builder(
                itemCount: Config.chats.length,
                itemBuilder: (context, index) {
                  final chat = Config.chats[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.only(left: 16, right: 8),
                    leading: const Icon(Icons.article),
                    selected: CurrentChat.chat == chat,
                    title: Text(
                      chat.title,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(chat.time),
                    onTap: () async {
                      if (CurrentChat.chat == chat) return;
                      await CurrentChat.load(chat);
                      setState(() {});
                    },
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () async {
                        if (CurrentChat.chat == chat) CurrentChat.clear();
                        await File(Config.chatFilePath(chat.fileName)).delete();
                        Config.chats.removeAt(index);
                        await Config.save();
                        setState(() {});
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "ChatBot",
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Consumer(builder: (context, ref, child) {
                  ref.watch(currentChatProvider);
                  return Text(
                    CurrentChat.model ?? S.of(context).no_model,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  );
                })
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.swap_vert),
            iconSize: 20,
            onPressed: () async {
              await showDialog(
                context: context,
                builder: (context) => CurrentChatSettings(),
              );
            },
          ),
        ]),
        actions: [
          IconButton(
              icon: const Icon(Icons.note_add_outlined),
              onPressed: () {
                CurrentChat.clear();
                setState(() {});
              }),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).pushNamed("/settings"),
          ),
        ],
      ),
      drawer: Drawer(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: SafeArea(child: drawer),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(8),
              itemCount: CurrentChat.messages.length,
              itemBuilder: (context, index) {
                final message = CurrentChat.messages[index];
                return MessageWidget(
                  message: message,
                  longPress: (context) async =>
                      await _longPress(context, index),
                );
              },
            ),
          ),
          InputWidget(
            controller: _inputCtrl,
            addImage: _addImage,
            clearImage: _clearImage,
            sendMessage: _sendMessage,
            stopResponding: _stopResponding,
          ),
        ],
      ),
    );
  }
}

List<ChatMessage> _buildContext(List<Message> list) {
  final context = <ChatMessage>[];

  if (Config.bot.systemPrompts != null) {
    context.add(ChatMessage.system(Config.bot.systemPrompts!));
  }

  for (final item in list) {
    switch (item.role) {
      case MessageRole.assistant:
        context.add(ChatMessage.ai(item.text));
        break;

      case MessageRole.user:
        if (item.image == null) {
          context.add(ChatMessage.humanText(item.text));
        } else {
          context.add(ChatMessage.human(ChatMessageContent.multiModal([
            ChatMessageContent.text(item.text),
            ChatMessageContent.image(
              mimeType: "image/jpeg",
              data: item.image!,
            ),
          ])));
        }
    }
  }

  return context;
}
