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

import "chat.dart";
import "input.dart";
import "current.dart";
import "../util.dart";
import "../config.dart";
import "../llm/llm.dart";
import "../gen/l10n.dart";
import "../markdown/util.dart";
import "../markdown/code.dart";
import "../markdown/latex.dart";

import "dart:async";
import "dart:convert";
import "dart:typed_data";
import "package:flutter/material.dart";
import "package:animate_do/animate_do.dart";
import "package:flutter_spinkit/flutter_spinkit.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_markdown/flutter_markdown.dart";

final messageProvider = NotifierProvider.autoDispose
    .family<MessageNotifier, void, Message>(MessageNotifier.new);

class MessageNotifier extends AutoDisposeFamilyNotifier<void, Message> {
  @override
  void build(Message arg) {}

  void notify() => ref.notifyListeners();
}

enum MessageRole {
  user,
  assistant;

  bool get isUser => this == MessageRole.user;
  bool get isAssistant => this == MessageRole.assistant;
}

enum CitationType {
  web,
}

typedef MessageImage = ({
  Uint8List bytes,
  String base64,
});

typedef MessageCitation = ({
  CitationType type,
  String content,
  String source,
});

class MessageWidget extends ConsumerStatefulWidget {
  final Message message;

  const MessageWidget({
    required this.message,
    super.key,
  });

  @override
  ConsumerState<MessageWidget> createState() => _MessageWidgetState();
}

class _MessageWidgetState extends ConsumerState<MessageWidget> {
  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    ref.watch(messageProvider(message));

    final item = message.item;
    final role = item.role;

    return Container(
      alignment: role.isUser ? Alignment.topRight : Alignment.topLeft,
      child: Column(
        crossAxisAlignment: role.isAssistant
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.end,
        children: [
          if (item.images.isNotEmpty) ...[
            _buildImages(),
            const SizedBox(height: 8),
          ],
          if (role.isAssistant) ...[
            _buildHeader(),
            SizedBox(height: 8),
          ],
          _buildBody(),
          if (Current.messages.lastOrNull == message &&
              Current.chatStatus.isNothing) ...[
            const SizedBox(height: 4),
            FadeIn(child: _buildToolBar()),
          ],
        ],
      ),
    );
  }

  Widget _buildImages() {
    final item = widget.message.item;

    return LayoutBuilder(builder: (context, constraints) {
      final n = (constraints.maxWidth / 120).ceil();
      final width = (constraints.maxWidth - 8 * (n - 1)) / n;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final image in item.images)
            Ink(
              width: width,
              height: width,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                image: DecorationImage(
                  image: MemoryImage(image.bytes),
                  fit: BoxFit.cover,
                ),
              ),
              child: InkWell(
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                onTap: () async {
                  InputWidget.unFocus();

                  final result = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(S.of(context).delete_image),
                      content: Text(S.of(context).ensure_delete_image),
                      actions: [
                        TextButton(
                          onPressed: Navigator.of(context).pop,
                          child: Text(S.of(context).cancel),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: Text(S.of(context).delete),
                        ),
                      ],
                    ),
                  );
                  if (!(result ?? false)) return;

                  setState(() => item.images.remove(image));
                  Current.save();
                },
              ),
            ),
        ],
      );
    });
  }

  Widget _buildHeader() {
    final message = widget.message;
    final item = message.item;
    final id = item.model;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ModelAvatar(id: id),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 1),
              Text(
                Config.models[id]?.name ?? id ?? S.of(context).no_model,
                style: Theme.of(context).textTheme.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              Text(
                item.time ?? Util.formatDateTime(DateTime.now()),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 2),
            ],
          ),
        ),
        if (message.list.length > 1 &&
            (Current.chatStatus.isNothing ||
                message != Current.messages.lastOrNull)) ...[
          const SizedBox(width: 8),
          SizedBox(
            width: 32,
            height: 32,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded),
              iconSize: 16,
              onPressed: () {
                if (item == message.list.first) return;
                setState(() => message.index--);
                Current.save();
              },
            ),
          ),
          Text("${message.index + 1}/${message.list.length}"),
          SizedBox(
            width: 32,
            height: 32,
            child: IconButton(
              icon: const Icon(Icons.arrow_forward_ios_rounded),
              iconSize: 16,
              onPressed: () {
                if (item == message.list.last) return;
                setState(() => message.index++);
                Current.save();
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBody() {
    final item = widget.message.item;
    final text = item.text;
    final role = item.role;

    final colorScheme = Theme.of(context).colorScheme;
    final markdownStyleSheet = MarkdownStyleSheet(
      codeblockPadding: EdgeInsets.all(0),
      codeblockDecoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      blockquoteDecoration: BoxDecoration(
        color: colorScheme.brightness == Brightness.light
            ? Colors.blueGrey.withOpacity(0.3)
            : Colors.black.withOpacity(0.3),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
    );

    final radius = BorderRadius.only(
      topLeft: const Radius.circular(12),
      bottomLeft: const Radius.circular(12),
      bottomRight: const Radius.circular(12),
      topRight: Radius.circular(role.isUser ? 2 : 12),
    );

    return LayoutBuilder(
      key: UniqueKey(),
      builder: (context, constraints) => Ink(
        decoration: BoxDecoration(
          color: role.isAssistant
              ? colorScheme.surfaceContainer
              : colorScheme.secondaryContainer,
          borderRadius: radius,
        ),
        child: InkWell(
          borderRadius: radius,
          onLongPress: _longPress,
          child: Container(
            padding: const EdgeInsets.all(12),
            constraints: BoxConstraints(
              maxWidth: constraints.maxWidth * (role.isUser ? 0.9 : 1),
            ),
            child: switch (text.isNotEmpty) {
              true => MarkdownBody(
                  data: text,
                  extensionSet: mdExtensionSet,
                  onTapLink: (text, href, title) =>
                      Dialogs.openLink(context: context, link: href),
                  builders: {
                    "pre": CodeBlockBuilder(context: context),
                    "latex": LatexElementBuilder(textScaleFactor: 1.2),
                  },
                  styleSheet: markdownStyleSheet,
                  styleSheetTheme: MarkdownStyleSheetBaseTheme.material,
                ),
              false => SizedBox(
                  width: 36,
                  height: 18,
                  child: SpinKitWave(
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
            },
          ),
        ),
      ),
    );
  }

  Widget _buildToolBar() {
    final item = widget.message.item;
    final role = item.role;

    return Row(
      mainAxisAlignment:
          role.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (role.isAssistant) ...[
          SizedBox(
            width: 36,
            height: 26,
            child: IconButton(
              icon: Icon(switch (Current.ttsStatus) {
                TtsStatus.loading => Icons.cancel_outlined,
                TtsStatus.nothing => Icons.volume_up_outlined,
                TtsStatus.playing => Icons.pause_circle_outlined,
              }),
              iconSize: 18,
              onPressed: _tts,
              padding: EdgeInsets.zero,
            ),
          ),
          SizedBox(
            width: 36,
            height: 26,
            child: IconButton(
              icon: const Icon(Icons.sync_outlined),
              iconSize: 18,
              onPressed: _reanswer,
              padding: EdgeInsets.zero,
            ),
          ),
          if (item.citations.isNotEmpty)
            SizedBox(
              width: 36,
              height: 26,
              child: IconButton(
                icon: const Icon(Icons.find_in_page_outlined),
                iconSize: 18,
                onPressed: _citations,
                padding: EdgeInsets.zero,
              ),
            ),
        ],
        SizedBox(
          width: 36,
          height: 26,
          child: IconButton(
            icon: const Icon(Icons.paste_outlined),
            iconSize: 16,
            onPressed: _copy,
            padding: EdgeInsets.zero,
          ),
        ),
        SizedBox(
          width: 36,
          height: 26,
          child: IconButton(
            icon: const Icon(Icons.edit_outlined),
            iconSize: 18,
            onPressed: _edit,
            padding: EdgeInsets.zero,
          ),
        ),
        SizedBox(
          width: 36,
          height: 26,
          child: IconButton(
            icon: const Icon(Icons.delete_outlined),
            iconSize: 18,
            onPressed: _delete,
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  void _edit() {
    InputWidget.unFocus();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => _MessageEditor(message: widget.message),
    ));
  }

  void _copy() {
    Util.copyText(
      context: context,
      text: widget.message.item.text,
    );
  }

  void _delete() {
    if (!Current.chatStatus.isNothing) return;
    if (!Current.ttsStatus.isNothing) return;

    final message = widget.message;
    final list = message.list;
    final item = message.item;

    if (list.length == 1) {
      Current.messages.remove(message);
      ref.read(messagesProvider.notifier).notify();
    } else {
      if (item == list.last) message.index--;
      setState(() => list.remove(item));
    }

    Current.save();
  }

  void _source() {
    InputWidget.unFocus();

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      scrollControlDisabledMaxHeightRatio: 1,
      builder: (context) => ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: double.infinity,
          minHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(left: 24, right: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                widget.message.item.text,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  void _citations() {
    InputWidget.unFocus();
    final citations = widget.message.item.citations;

    void onTap(MessageCitation citation) {
      switch (citation.type) {
        case CitationType.web:
          Dialogs.openLink(
            context: context,
            link: citation.source,
          );
          break;
      }
    }

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      scrollControlDisabledMaxHeightRatio: 0.7,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DialogHeader(title: S.of(context).citations),
          const Divider(height: 1),
          Flexible(
            child: ListView.separated(
              itemCount: citations.length,
              itemBuilder: (context, index) {
                final citation = citations[index];
                final content = citation.content;
                final source = citation.source;

                return Card.filled(
                  margin: EdgeInsets.zero,
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  child: ListTile(
                    title: Text(
                      source,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => onTap(citation),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                );
              },
              padding: const EdgeInsets.all(12),
              separatorBuilder: (context, index) => const SizedBox(height: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _longPress() {
    InputWidget.unFocus();

    void invoke(VoidCallback func) {
      Navigator.of(context).pop();
      func();
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DragHandle(),
            ListTile(
              minTileHeight: 48,
              shape: const StadiumBorder(),
              title: Text(S.of(context).edit),
              leading: const Icon(Icons.edit_outlined),
              onTap: () => invoke(_edit),
            ),
            ListTile(
              minTileHeight: 48,
              shape: StadiumBorder(),
              title: Text(S.of(context).copy),
              leading: const Icon(Icons.copy_all),
              onTap: () => invoke(_copy),
            ),
            ListTile(
              minTileHeight: 48,
              shape: const StadiumBorder(),
              title: Text(S.of(context).delete),
              leading: const Icon(Icons.delete_outlined),
              onTap: () => invoke(_delete),
            ),
            ListTile(
              minTileHeight: 48,
              shape: const StadiumBorder(),
              title: Text(S.of(context).source),
              leading: const Icon(Icons.code_outlined),
              onTap: () => invoke(_source),
            ),
            if (widget.message.item.citations.isNotEmpty)
              ListTile(
                minTileHeight: 48,
                shape: const StadiumBorder(),
                title: Text(S.of(context).citations),
                leading: const Icon(Icons.find_in_page_outlined),
                onTap: () => invoke(_citations),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _tts() async {
    if (!Current.ttsStatus.isNothing) {
      ref.read(llmProvider.notifier).stopTts();
      return;
    }

    final message = widget.message;
    final text = message.item.text;
    if (text.isEmpty) return;

    final tts = Config.textToSpeech;
    final ttsOk = tts.api != null && tts.model != null && tts.voice != null;

    if (!ttsOk) {
      Util.showSnackBar(
        context: context,
        content: Text(S.of(context).setup_tts_first),
      );
      return;
    }

    final error = await ref.read(llmProvider.notifier).tts(message);
    if (error != null && mounted) {
      Dialogs.error(context: context, error: error);
    }
  }

  Future<void> _reanswer() async {
    if (!Current.chatStatus.isNothing) {
      ref.read(llmProvider.notifier).stopChat();
      return;
    }

    if (!Util.checkChat(context)) return;
    final message = widget.message;

    message.list.add(MessageItem(
      text: "",
      model: Current.model,
      role: MessageRole.assistant,
      time: Util.formatDateTime(DateTime.now()),
    ));
    message.index = message.list.length - 1;

    final error = await ref.read(llmProvider.notifier).chat(message);
    if (error != null && mounted) {
      Dialogs.error(context: context, error: error);
    }

    Current.save();
  }
}

class MessageView extends StatelessWidget {
  final Message message;
  final MessageItem item;

  MessageView({
    required this.message,
    super.key,
  }) : item = message.item;

  @override
  Widget build(BuildContext context) {
    final role = item.role;

    return Container(
      alignment: role.isUser ? Alignment.topRight : Alignment.topLeft,
      child: Column(
        crossAxisAlignment: role.isAssistant
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.end,
        children: [
          if (item.images.isNotEmpty) ...[
            _buildImages(context),
            const SizedBox(height: 8),
          ],
          if (role.isAssistant) ...[
            _buildHeader(context),
            const SizedBox(height: 8),
          ],
          _buildBody(context),
        ],
      ),
    );
  }

  Widget _buildImages(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final n = (constraints.maxWidth / 120).ceil();
      final width = (constraints.maxWidth - 8 * (n - 1)) / n;

      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final image in item.images)
            ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              child: Image.memory(
                image.bytes,
                width: width,
                height: width,
                fit: BoxFit.cover,
              ),
            ),
        ],
      );
    });
  }

  Widget _buildHeader(BuildContext context) {
    final id = item.model;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ModelAvatar(id: id),
        const SizedBox(width: 12),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 1),
            Text(
              Config.models[id]?.name ?? id ?? S.current.no_model,
              style: Theme.of(context).textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 1),
            Text(
              item.time ?? Util.formatDateTime(DateTime.now()),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 2),
          ],
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    final text = item.text;
    final role = item.role;

    final colorScheme = Theme.of(context).colorScheme;
    final markdownStyleSheet = MarkdownStyleSheet(
      codeblockPadding: EdgeInsets.all(0),
      codeblockDecoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      blockquoteDecoration: BoxDecoration(
        color: colorScheme.brightness == Brightness.light
            ? Colors.blueGrey.withOpacity(0.3)
            : Colors.black.withOpacity(0.3),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
    );

    final radius = BorderRadius.only(
      topLeft: const Radius.circular(12),
      bottomLeft: const Radius.circular(12),
      bottomRight: const Radius.circular(12),
      topRight: Radius.circular(role.isUser ? 2 : 12),
    );

    return Container(
      padding: const EdgeInsets.all(12),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * (role.isUser ? 0.9 : 1),
      ),
      decoration: BoxDecoration(
        borderRadius: radius,
        color: role.isAssistant
            ? colorScheme.surfaceContainer
            : colorScheme.secondaryContainer,
      ),
      child: MarkdownBody(
        data: text,
        extensionSet: mdExtensionSet,
        onTapLink: (text, href, title) =>
            Dialogs.openLink(context: context, link: href),
        builders: {
          "pre": CodeBlockBuilder2(context: context),
          "latex": LatexElementBuilder2(textScaleFactor: 1.2),
        },
        styleSheet: markdownStyleSheet,
        styleSheetTheme: MarkdownStyleSheetBaseTheme.material,
      ),
    );
  }
}

class _MessageEditor extends ConsumerStatefulWidget {
  final Message message;

  const _MessageEditor({
    required this.message,
  });

  @override
  ConsumerState<_MessageEditor> createState() => _MessageEditorState();
}

class _MessageEditorState extends ConsumerState<_MessageEditor> {
  late final Message message;
  late final UndoHistoryController _undoCtrl;
  late final TextEditingController _editCtrl;

  @override
  void initState() {
    super.initState();
    message = widget.message;
    _undoCtrl = UndoHistoryController();
    final text = widget.message.item.text;
    _editCtrl = TextEditingController(text: text);
  }

  @override
  void dispose() {
    _editCtrl.dispose();
    _undoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.of(context).edit),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: () => _undoCtrl.undo(),
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            onPressed: () => _undoCtrl.redo(),
          ),
          IconButton(
            icon: const Icon(Icons.done),
            onPressed: () {
              message.item.text = _editCtrl.text;
              ref.read(messageProvider(message).notifier).notify();

              Current.save();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: TextField(
        expands: true,
        maxLines: null,
        controller: _editCtrl,
        undoController: _undoCtrl,
        textAlign: TextAlign.start,
        keyboardType: TextInputType.multiline,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: S.of(context).enter_message,
          contentPadding:
              const EdgeInsets.only(top: 12, left: 16, right: 16, bottom: 12),
        ),
      ),
    );
  }
}
