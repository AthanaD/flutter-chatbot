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
import "message.dart";
import "current.dart";
import "../util.dart";
import "../config.dart";
import "../llm/llm.dart";
import "../gen/l10n.dart";

import "dart:convert";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:image_picker/image_picker.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_image_compress/flutter_image_compress.dart";

class InputWidget extends ConsumerStatefulWidget {
  static final FocusNode focusNode = FocusNode();

  const InputWidget({super.key});

  @override
  ConsumerState<InputWidget> createState() => _InputWidgetState();

  static void unFocus() => focusNode.unfocus();
}

typedef _Image = ({String name, MessageImage image});

class _InputWidgetState extends ConsumerState<InputWidget> {
  String _lastText = "";
  static final List<_Image> _images = [];
  final TextEditingController _inputCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _inputCtrl.addListener(() {
      final text = _inputCtrl.text;
      if (_lastText.isEmpty ^ text.isEmpty) {
        setState(() {});
      }
      _lastText = text;
    });
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(llmProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height / 4,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: TextField(
              maxLines: null,
              autofocus: false,
              controller: _inputCtrl,
              focusNode: InputWidget.focusNode,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                border: InputBorder.none,
                constraints: const BoxConstraints(),
                hintText: S.of(context).enter_message,
                contentPadding: const EdgeInsets.only(
                    top: 8, left: 16, right: 16, bottom: 8),
              ),
            ),
          ),
          Row(
            children: [
              const SizedBox(width: 8),
              SizedBox.square(
                dimension: 36,
                child: IconButton(
                  icon: const Icon(Icons.upload_file),
                  padding: EdgeInsets.zero,
                  onPressed: _addFile,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox.square(
                dimension: 36,
                child: GestureDetector(
                  onLongPress: () {
                    final old = Preferences.googleSearch;
                    Util.showSnackBar(
                      context: context,
                      content: Text(old
                          ? S.of(context).search_general_mode
                          : S.of(context).search_gemini_mode),
                    );
                    setState(() => Preferences.googleSearch = !old);
                  },
                  child: IconButton(
                    icon: const Icon(Icons.language),
                    isSelected: Preferences.search,
                    selectedIcon: Badge(
                      label: const Text("G"),
                      isLabelVisible: Preferences.googleSearch,
                      child: const Icon(Icons.language),
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: () => setState(
                        () => Preferences.search = !Preferences.search),
                  ),
                ),
              ),
              if (_images.isNotEmpty) ...[
                const SizedBox(width: 8),
                SizedBox.square(
                  dimension: 36,
                  child: IconButton(
                    icon: const Icon(Icons.image_outlined),
                    isSelected: true,
                    padding: EdgeInsets.zero,
                    onPressed: _editImages,
                  ),
                ),
              ],
              const Expanded(child: SizedBox()),
              const SizedBox(width: 8),
              SizedBox.square(
                dimension: 36,
                child: _buildSendButton(),
              ),
              const SizedBox(width: 8),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSendButton() {
    IconData icon;
    Color background;
    Color? foreground;

    if (Current.chatStatus.isResponding) {
      icon = Icons.pause;
      background = Theme.of(context).colorScheme.primaryContainer;
      foreground = Theme.of(context).colorScheme.onPrimaryContainer;
    } else {
      icon = Icons.arrow_upward;
      if (_inputCtrl.text.isEmpty) {
        background = Colors.grey.withOpacity(0.2);
      } else {
        background = Theme.of(context).colorScheme.primaryContainer;
        foreground = Theme.of(context).colorScheme.onPrimaryContainer;
      }
    }

    return IconButton(
      icon: Icon(icon),
      onPressed: _sendMessage,
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        foregroundColor: foreground,
        backgroundColor: background,
      ),
    );
  }

  Future<void> _addFile() async {
    InputWidget.unFocus();

    final result = await showModalBottomSheet<int>(
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
              title: Text(S.of(context).camera),
              leading: const Icon(Icons.camera_outlined),
              onTap: () => Navigator.of(context).pop(1),
            ),
            ListTile(
              minTileHeight: 48,
              shape: const StadiumBorder(),
              title: Text(S.of(context).gallery),
              leading: const Icon(Icons.photo_library_outlined),
              onTap: () => Navigator.of(context).pop(2),
            ),
          ],
        ),
      ),
    );

    switch (result) {
      case 1:
        await _addImage(ImageSource.camera);
        break;

      case 2:
        await _addImage(ImageSource.gallery);
        break;
    }
  }

  Future<void> _addImage(ImageSource source) async {
    XFile? result;
    Uint8List? compressed;
    final picker = ImagePicker();

    try {
      result = await picker.pickImage(source: source);
      if (result == null) return;
    } catch (e) {
      return;
    }

    if (Config.imageCompression.enable ?? true) {
      try {
        compressed = await FlutterImageCompress.compressWithFile(
          result.path,
          quality: Config.imageCompression.quality ?? 95,
          minWidth: Config.imageCompression.minWidth ?? 1920,
          minHeight: Config.imageCompression.minHeight ?? 1080,
        );
        if (compressed == null) throw false;
      } catch (e) {
        if (mounted) {
          Util.showSnackBar(
            context: context,
            content: Text(S.of(context).image_compress_failed),
          );
        }
      }
    }

    final bytes = compressed ?? await result.readAsBytes();
    final image = (
      name: result.name,
      image: (bytes: bytes, base64: base64Encode(bytes)),
    );
    setState(() => _images.add(image));
  }

  void _editImages() async {
    InputWidget.unFocus();

    showModalBottomSheet<String>(
      context: context,
      scrollControlDisabledMaxHeightRatio: 0.7,
      builder: (context) => StatefulBuilder(
        builder: (context, setState2) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DialogHeader(title: S.of(context).images),
            const Divider(height: 1),
            ListView.builder(
              shrinkWrap: true,
              itemCount: _images.length,
              itemBuilder: (context, index) => ListTile(
                title: Text(_images[index].name),
                contentPadding: const EdgeInsets.only(left: 24, right: 12),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () {
                    setState(() => _images.removeAt(index));
                    if (_images.isEmpty) {
                      Navigator.of(context).pop();
                    } else {
                      setState2(() {});
                    }
                  },
                ),
              ),
            ),
            const Divider(height: 1),
            DialogFooter(
              children: [
                TextButton(
                  onPressed: Navigator.of(context).pop,
                  child: Text(S.of(context).cancel),
                ),
                TextButton(
                  onPressed: () {
                    setState(() => _images.clear());
                    Navigator.of(context).pop();
                  },
                  child: Text(S.of(context).clear),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    if (!Current.chatStatus.isNothing) {
      ref.read(llmProvider.notifier).stopChat();
      return;
    }

    if (!Util.checkChat(context)) return;
    final text = _inputCtrl.text;
    if (text.isEmpty) return;

    final messages = Current.messages;
    final user = MessageItem(
      text: text,
      role: MessageRole.user,
    );
    for (final image in _images) {
      user.images.add(image.image);
    }
    messages.add(Message.fromItem(user));

    final assistant = Message.fromItem(MessageItem(
      text: "",
      model: Current.model,
      role: MessageRole.assistant,
      time: Util.formatDateTime(DateTime.now()),
    ));
    messages.add(assistant);
    ref.read(messagesProvider.notifier).notify();

    _images.clear();
    _inputCtrl.clear();

    final results = await Future.wait([
      _generateTitle(text).catchError((e) => text),
      ref.read(llmProvider.notifier).chat(assistant),
    ]);

    final title = results[0];
    final error = results[1];

    if (error != null && mounted) {
      _inputCtrl.text = text;
      Dialogs.error(context: context, error: error);
    }

    if (title != null) {
      Current.newChat(title);
      ref.read(chatProvider.notifier).notify();
      ref.read(chatsProvider.notifier).notify();
    }
    Current.save();
  }

  Future<String?> _generateTitle(String text) async {
    if (Current.hasChat) return null;
    return await generateTitle(text);
  }
}
