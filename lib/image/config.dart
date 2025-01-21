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
import "../settings/api.dart";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

class ConfigTab extends ConsumerStatefulWidget {
  const ConfigTab({super.key});

  @override
  ConsumerState<ConfigTab> createState() => _ConfigTabState();
}

class _ConfigTabState extends ConsumerState<ConfigTab> {
  @override
  Widget build(BuildContext context) {
    ref.watch(apisProvider);

    final s = S.of(context);
    const padding = EdgeInsets.only(left: 24, right: 24);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return ListView(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      children: [
        Padding(
          padding: padding,
          child: Text(
            s.base_config,
            style: TextStyle(color: primaryColor),
          ),
        ),
        ListTile(
          title: Text(s.api),
          contentPadding: padding,
          subtitle: Text(Config.imageGeneration.api ?? s.empty),
          onTap: () async {
            if (Config.apis.isEmpty) return;

            final api = await Dialogs.select(
              context: context,
              list: Config.apis.keys.toList(),
              selected: Config.imageGeneration.api,
              title: s.choose_api,
            );
            if (api == null) return;

            setState(() => Config.imageGeneration.api = api);
            Config.save();
          },
        ),
        const Divider(height: 1),
        ListTile(
          title: Text(s.model),
          contentPadding: padding,
          subtitle: Text(Config.imageGeneration.model ?? s.empty),
          onTap: () async {
            final models = Config.apis[Config.imageGeneration.api]?.models;
            if (models == null) return;

            final model = await Dialogs.select(
              context: context,
              selected: Config.imageGeneration.model,
              title: s.choose_model,
              list: models,
            );
            if (model == null) return;

            setState(() => Config.imageGeneration.model = model);
            Config.save();
          },
        ),
        Padding(
          padding: padding,
          child: Text(
            s.optional_config,
            style: TextStyle(color: primaryColor),
          ),
        ),
        ListTile(
          title: Text(s.image_size),
          contentPadding: padding,
          subtitle: Text(Config.imageGeneration.size ?? s.empty),
          onTap: () async {
            final texts = await Dialogs.input(
              context: context,
              title: s.image_size,
              fields: [
                InputDialogField(
                  label: s.please_input,
                  text: Config.imageGeneration.size,
                ),
              ],
            );
            if (texts == null) return;

            final text = texts[0].trim();
            final size = text.isEmpty ? null : text;
            setState(() => Config.imageGeneration.size = size);
            Config.save();
          },
        ),
        const Divider(height: 1),
        ListTile(
          title: Text(s.image_style),
          contentPadding: padding,
          subtitle: Text(Config.imageGeneration.style ?? s.empty),
          onTap: () async {
            final texts = await Dialogs.input(
              context: context,
              title: s.image_style,
              fields: [
                InputDialogField(
                  label: s.please_input,
                  text: Config.imageGeneration.style,
                ),
              ],
            );
            if (texts == null) return;

            final text = texts[0].trim();
            final style = text.isEmpty ? null : text;
            setState(() => Config.imageGeneration.style = style);
            Config.save();
          },
        ),
        const Divider(height: 1),
        ListTile(
          title: Text(s.image_quality),
          contentPadding: padding,
          subtitle: Text(Config.imageGeneration.quality ?? s.empty),
          onTap: () async {
            final texts = await Dialogs.input(
              context: context,
              title: s.image_quality,
              fields: [
                InputDialogField(
                  label: s.please_input,
                  text: Config.imageGeneration.quality,
                ),
              ],
            );
            if (texts == null) return;

            final text = texts[0].trim();
            final quality = text.isEmpty ? null : text;
            setState(() => Config.imageGeneration.quality = quality);
            Config.save();
          },
        ),
      ],
    );
  }
}
