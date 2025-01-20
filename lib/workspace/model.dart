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

import "../util.dart";
import "../gen/l10n.dart";
import "../chat/chat.dart";

import "package:chatbot/config.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

class ModelTab extends ConsumerWidget {
  const ModelTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(chatProvider);

    final modelSet = <String>{};
    for (final api in Config.apis.values) {
      modelSet.addAll(api.models);
    }
    final modelList = modelSet.toList();

    return ListView.separated(
      key: ValueKey(Theme.of(context).brightness),
      padding: const EdgeInsets.all(16),
      itemCount: modelList.length,
      itemBuilder: (context, index) {
        final id = modelList[index];

        return Card.filled(
          color: Theme.of(context).colorScheme.surfaceContainer,
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: ModelAvatar(id: id),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            title: Text(
              Config.models[id]?.name ?? id,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              id,
              overflow: TextOverflow.ellipsis,
            ),
            titleTextStyle: Theme.of(context).textTheme.titleMedium,
            subtitleTextStyle: Theme.of(context).textTheme.bodySmall,
            onTap: () => showModalBottomSheet(
              context: context,
              useSafeArea: true,
              isScrollControlled: true,
              builder: (context) => Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: ModelSettings(id: id),
              ),
            ),
          ),
        );
      },
      separatorBuilder: (context, index) => const SizedBox(height: 12),
    );
  }
}

class ModelSettings extends ConsumerStatefulWidget {
  final String id;

  const ModelSettings({
    required this.id,
    super.key,
  });

  @override
  ConsumerState<ModelSettings> createState() => _ModelEditorState();
}

class _ModelEditorState extends ConsumerState<ModelSettings> {
  late String _id;
  late bool? _chat;
  late final Model? _model;
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _id = widget.id;
    _model = Config.models[_id];
    _chat = _model?.chat;
    _ctrl = TextEditingController(
      text: _model?.name ?? _id,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DialogHeader(title: S.of(context).model),
        const Divider(height: 1),
        const SizedBox(height: 8),
        Row(
          children: [
            const SizedBox(width: 24),
            Expanded(
              child: TextField(
                controller: _ctrl,
                decoration: InputDecoration(
                  labelText: S.of(context).model_name,
                  border: const UnderlineInputBorder(),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.transform),
              onPressed: _idToName,
            ),
            const SizedBox(width: 12),
          ],
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          value: _chat ?? true,
          title: Text(S.of(context).chat_model),
          subtitle: Text(S.of(context).chat_model_hint),
          onChanged: (value) => setState(() => _chat = value),
          contentPadding: const EdgeInsets.only(left: 24, right: 16),
        ),
        const Divider(height: 1),
        DialogFooter(
          children: [
            TextButton(
              onPressed: _save,
              child: Text(S.of(context).ok),
            ),
            TextButton(
              onPressed: Navigator.of(context).pop,
              child: Text(S.of(context).cancel),
            ),
          ],
        ),
      ],
    );
  }

  void _idToName() {
    String name = _id;
    final slash = name.indexOf('/');
    if (slash != -1) name = name.substring(slash + 1);

    var parts = name.split('-');
    parts.removeWhere((it) => it.isEmpty);
    parts =
        parts.map((it) => "${it[0].toUpperCase()}${it.substring(1)}").toList();

    _ctrl.text = parts.join(' ');
  }

  Future<void> _save() async {
    final name = _ctrl.text;
    if (name.isEmpty) return;

    final chat = _chat ?? true;
    Config.models[_id] = Model(
      mid: _id,
      name: name,
      chat: chat,
    );
    Config.save();

    ref.read(messagesProvider.notifier).notify();
    ref.read(chatProvider.notifier).notify();
    if (mounted) Navigator.of(context).pop();
  }
}
