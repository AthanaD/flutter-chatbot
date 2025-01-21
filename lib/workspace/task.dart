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

class TaskTab extends ConsumerStatefulWidget {
  const TaskTab({super.key});

  @override
  ConsumerState<TaskTab> createState() => _TaskTabState();
}

class _TaskTabState extends ConsumerState<TaskTab> {
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
            s.title_generation,
            style: TextStyle(color: primaryColor),
          ),
        ),
        CheckboxListTile(
          title: Text(s.enable),
          subtitle: Text(s.title_enable_hint),
          contentPadding: const EdgeInsets.only(left: 24, right: 16),
          value: Config.titleGeneration.enable ?? false,
          onChanged: (value) {
            setState(() => Config.titleGeneration.enable = value);
            Config.save();
          },
        ),
        const Divider(height: 1),
        ListTile(
          title: Text(s.api),
          contentPadding: padding,
          subtitle: Text(Config.titleGeneration.api ?? s.empty),
          onTap: () async {
            if (Config.apis.isEmpty) return;

            final api = await Dialogs.select(
              context: context,
              list: Config.apis.keys.toList(),
              selected: Config.titleGeneration.api,
              title: s.choose_api,
            );
            if (api == null) return;

            setState(() => Config.titleGeneration.api = api);
            Config.save();
          },
        ),
        const Divider(height: 1),
        ListTile(
          title: Text(s.model),
          contentPadding: padding,
          subtitle: Text(Config.titleGeneration.model ?? s.empty),
          onTap: () async {
            final models = Config.apis[Config.titleGeneration.api]?.models;
            if (models == null) return;

            final model = await Dialogs.select(
              context: context,
              selected: Config.titleGeneration.model,
              title: s.choose_model,
              list: models,
            );
            if (model == null) return;

            setState(() => Config.titleGeneration.model = model);
            Config.save();
          },
        ),
        const Divider(height: 1),
        ListTile(
          title: Text(s.title_prompt),
          contentPadding: padding,
          subtitle: Text(s.title_prompt_hint),
          onTap: () async {
            final texts = await Dialogs.input(
              context: context,
              title: s.title_prompt,
              fields: [
                InputDialogField(
                  label: s.please_input,
                  text: Config.titleGeneration.prompt,
                  maxLines: null,
                ),
              ],
            );
            if (texts == null) return;

            String? prompt;
            final text = texts[0].trim();
            if (text.isNotEmpty) prompt = text;

            Config.titleGeneration.prompt = prompt;
            Config.save();
          },
        ),
        const SizedBox(height: 4),
        InfoCard(info: s.title_generation_hint("{text}")),
        const SizedBox(height: 16),
        Padding(
          padding: padding,
          child: Text(
            s.web_search,
            style: TextStyle(color: primaryColor),
          ),
        ),
        CheckboxListTile(
          title: Text(s.search_vector),
          subtitle: Text(s.search_vector_hint),
          contentPadding: const EdgeInsets.only(left: 24, right: 16),
          value: Config.webSearch.vector ?? false,
          onChanged: (value) {
            setState(() => Config.webSearch.vector = value);
            Config.save();
          },
        ),
        const Divider(height: 1),
        ListTile(
          title: Text(s.search_searxng),
          contentPadding: padding,
          subtitle: Text(s.search_searxng_hint),
          onTap: () async {
            String? base;
            String? extra;

            final searxng = Config.webSearch.searxng;
            const fixedPart = "q={text}&format=json";

            if (searxng != null) {
              final uri = Uri.parse(searxng);
              base = "${uri.scheme}://${uri.host}";
              extra = uri.queryParameters.entries
                  .map((it) => "${it.key}=${it.value}")
                  .join('&');
              extra = extra.replaceFirst(fixedPart, "");
              if (extra.startsWith('&')) extra = extra.replaceFirst('&', "");
            }

            final texts = await Dialogs.input(
              context: context,
              title: s.search_searxng,
              fields: [
                InputDialogField(
                  text: base,
                  label: s.search_searxng_base,
                  hint: "https://your.searxng.com",
                ),
                InputDialogField(
                  text: extra,
                  label: s.search_searxng_extra,
                  help: s.search_searxng_extra_help,
                ),
              ],
            );
            if (texts == null) return;

            String? newBase;
            String? newExtra;
            final text1 = texts[0].trim();
            final text2 = texts[1].trim();
            if (text1.isNotEmpty) newBase = text1;
            if (text2.isNotEmpty) newExtra = text2;

            String? full;
            if (newBase != null) {
              full = "$newBase/search?$fixedPart";
              if (newExtra != null) full += "&$newExtra";
            }

            Config.webSearch.searxng = full;
            Config.save();
          },
        ),
        const Divider(height: 1),
        ListTile(
          title: Text(s.search_timeout),
          contentPadding: padding,
          subtitle: Text(s.search_timeout_hint),
          onTap: () async {
            final texts = await Dialogs.input(
              context: context,
              title: s.search_timeout,
              fields: [
                InputDialogField(
                  hint: "3000",
                  label: s.search_timeout_query,
                  help: s.search_timeout_query_help,
                  text: Config.webSearch.queryTime?.toString(),
                ),
                InputDialogField(
                  hint: "2000",
                  label: s.search_timeout_fetch,
                  help: s.search_timeout_fetch_help,
                  text: Config.webSearch.fetchTime?.toString(),
                ),
              ],
            );
            if (texts == null) return;

            int? query;
            int? fetch;
            final text1 = texts[0].trim();
            final text2 = texts[1].trim();
            if (text1.isNotEmpty) {
              query = int.tryParse(text1);
              if (query == null) return;
            }
            if (text2.isNotEmpty) {
              fetch = int.tryParse(text2);
              if (fetch == null) return;
            }

            Config.webSearch.queryTime = query;
            Config.webSearch.fetchTime = fetch;
            Config.save();
          },
        ),
        const Divider(height: 1),
        ListTile(
          title: Text(s.search_n),
          contentPadding: padding,
          subtitle: Text(s.search_n_hint),
          onTap: () async {
            final texts = await Dialogs.input(
              context: context,
              title: s.search_n,
              fields: [
                InputDialogField(
                  label: s.please_input,
                  hint: "64",
                  text: Config.webSearch.n?.toString(),
                ),
              ],
            );
            if (texts == null) return;

            int? n;
            final text = texts[0].trim();
            if (text.isNotEmpty) {
              n = int.tryParse(text);
              if (n == null) return;
            }

            Config.webSearch.n = n;
            Config.save();
          },
        ),
        const Divider(height: 1),
        ListTile(
          title: Text(s.search_prompt),
          contentPadding: padding,
          subtitle: Text(s.search_prompt_hint),
          onTap: () async {
            final texts = await Dialogs.input(
              context: context,
              title: s.search_prompt,
              fields: [
                InputDialogField(
                  label: s.please_input,
                  text: Config.webSearch.prompt,
                ),
              ],
            );
            if (texts == null) return;

            String? prompt;
            final text = texts[0].trim();
            if (text.isNotEmpty) prompt = text;

            Config.webSearch.prompt = prompt;
            Config.save();
          },
        ),
        const SizedBox(height: 4),
        InfoCard(info: s.search_prompt_info("{pages}", "{text}")),
        const SizedBox(height: 8),
      ],
    );
  }
}
