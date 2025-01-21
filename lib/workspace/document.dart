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
import "../config.dart";
import "../gen/l10n.dart";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

class DocumentTab extends ConsumerStatefulWidget {
  const DocumentTab({super.key});

  @override
  ConsumerState<DocumentTab> createState() => _DocumentTabState();
}

class _DocumentTabState extends ConsumerState<DocumentTab> {
  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    const padding = EdgeInsets.only(left: 24, right: 24);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return ListView(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      children: [
        Padding(
          padding: padding,
          child: Text(
            s.embedding_vector,
            style: TextStyle(color: primaryColor),
          ),
        ),
        ListTile(
          title: Text(s.api),
          contentPadding: padding,
          subtitle: Text(Config.vectorStore.api ?? s.empty),
          onTap: () async {
            if (Config.apis.isEmpty) return;

            final api = await Dialogs.select(
              context: context,
              list: Config.apis.keys.toList(),
              selected: Config.vectorStore.api,
              title: s.choose_api,
            );
            if (api == null) return;

            setState(() => Config.vectorStore.api = api);
            Config.save();
          },
        ),
        const Divider(height: 1),
        ListTile(
          title: Text(s.model),
          contentPadding: padding,
          subtitle: Text(Config.vectorStore.model ?? s.empty),
          onTap: () async {
            final models = Config.apis[Config.vectorStore.api]?.models;
            if (models == null) return;

            final model = await Dialogs.select(
              context: context,
              selected: Config.vectorStore.model,
              title: s.choose_model,
              list: models,
            );
            if (model == null) return;

            setState(() => Config.vectorStore.model = model);
            Config.save();
          },
        ),
        const Divider(height: 1),
        ListTile(
          title: Text(s.vector_batch_size),
          contentPadding: padding,
          subtitle: Text(s.vector_batch_size_hint),
          onTap: () async {
            final texts = await Dialogs.input(
              context: context,
              title: s.vector_batch_size,
              fields: [
                InputDialogField(
                  label: s.please_input,
                  hint: "64",
                  text: Config.vectorStore.batchSize?.toString(),
                ),
              ],
            );
            if (texts == null) return;

            int? value;
            final text = texts[0].trim();
            if (text.isNotEmpty) {
              value = int.tryParse(text);
              if (value == null) return;
            }

            Config.vectorStore.batchSize = value;
            Config.save();
          },
        ),
        const Divider(height: 1),
        ListTile(
          title: Text(s.vector_dimensions),
          contentPadding: padding,
          subtitle: Text(s.vector_dimensions_hint),
          onTap: () async {
            final texts = await Dialogs.input(
              context: context,
              title: s.vector_dimensions,
              fields: [
                InputDialogField(
                  label: s.please_input,
                  text: Config.vectorStore.dimensions?.toString(),
                ),
              ],
            );
            if (texts == null) return;

            int? value;
            final text = texts[0].trim();
            if (text.isNotEmpty) {
              value = int.tryParse(text);
              if (value == null) return;
            }

            Config.vectorStore.dimensions = value;
            Config.save();
          },
        ),
        const SizedBox(height: 4),
        InfoCard(info: s.embedding_vector_info),
        const SizedBox(height: 16),
        Padding(
          padding: padding,
          child: Text(
            s.document_config,
            style: TextStyle(color: primaryColor),
          ),
        ),
        ListTile(
          title: Text(s.chunk_n),
          contentPadding: padding,
          subtitle: Text(s.chunk_n_hint),
          onTap: () async {
            final texts = await Dialogs.input(
              context: context,
              title: s.chunk_n,
              fields: [
                InputDialogField(
                  label: s.please_input,
                  hint: "8",
                  text: Config.documentChunk.n?.toString(),
                ),
              ],
            );
            if (texts == null) return;

            int? value;
            final text = texts[0].trim();
            if (text.isNotEmpty) {
              value = int.tryParse(text);
              if (value == null) return;
            }

            Config.documentChunk.n = value;
            Config.save();
          },
        ),
        const Divider(height: 1),
        ListTile(
          title: Text(s.chunk_size),
          contentPadding: padding,
          subtitle: Text(s.chunk_size_hint),
          onTap: () async {
            final texts = await Dialogs.input(
              context: context,
              title: s.chunk_size,
              fields: [
                InputDialogField(
                  label: s.please_input,
                  hint: "2000",
                  text: Config.documentChunk.size?.toString(),
                ),
              ],
            );
            if (texts == null) return;

            int? value;
            final text = texts[0].trim();
            if (text.isNotEmpty) {
              value = int.tryParse(text);
              if (value == null) return;
            }

            Config.documentChunk.size = value;
            Config.save();
          },
        ),
        const Divider(height: 1),
        ListTile(
          title: Text(s.chunk_overlap),
          contentPadding: padding,
          subtitle: Text(s.chunk_overlap_hint),
          onTap: () async {
            final texts = await Dialogs.input(
              context: context,
              title: s.chunk_overlap,
              fields: [
                InputDialogField(
                  label: s.please_input,
                  hint: "100",
                  text: Config.documentChunk.overlap?.toString(),
                ),
              ],
            );
            if (texts == null) return;

            int? value;
            final text = texts[0].trim();
            if (text.isNotEmpty) {
              value = int.tryParse(text);
              if (value == null) return;
            }

            Config.documentChunk.overlap = value;
            Config.save();
          },
        ),
        const SizedBox(height: 4),
        InfoCard(info: s.document_config_hint),
        const SizedBox(height: 8),
      ],
    );
  }
}
