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

import "dart:convert";
import "package:http/http.dart";
import "package:flutter/material.dart";
import "package:animate_do/animate_do.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

final apisProvider =
    NotifierProvider.autoDispose<ApisNotifier, void>(ApisNotifier.new);

class ApisNotifier extends AutoDisposeNotifier<void> {
  @override
  void build() {}
  void notify() => ref.notifyListeners();
}

class ApisTab extends ConsumerWidget {
  const ApisTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(apisProvider);
    final apis = Config.apis.keys.toList();

    return Stack(
      children: [
        ListView.separated(
          padding: const EdgeInsets.all(16),
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemCount: apis.length,
          itemBuilder: (context, index) => Card.filled(
            margin: EdgeInsets.zero,
            child: ListTile(
              title: Text(
                apis[index],
                overflow: TextOverflow.ellipsis,
              ),
              leading: const Icon(Icons.api),
              contentPadding: const EdgeInsets.only(left: 16, right: 8),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => ApiSettings(api: apis[index]),
              )),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            heroTag: "api",
            icon: const Icon(Icons.api),
            label: Text(S.of(context).new_api),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => ApiSettings(),
            )),
          ),
        ),
      ],
    );
  }
}

class ApiSettings extends ConsumerStatefulWidget {
  final String? api;

  const ApiSettings({
    super.key,
    this.api,
  });

  @override
  ConsumerState<ApiSettings> createState() => _ApiSettingsState();
}

class _ApiSettingsState extends ConsumerState<ApiSettings> {
  String? _type;
  Client? _client;
  bool _isFetching = false;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _modelsCtrl;
  late final TextEditingController _apiUrlCtrl;
  late final TextEditingController _apiKeyCtrl;

  @override
  void initState() {
    super.initState();

    final api = widget.api;
    final config = Config.apis[api];

    _type = config?.type;
    _nameCtrl = TextEditingController(text: api);
    _apiUrlCtrl = TextEditingController(text: config?.url);
    _apiKeyCtrl = TextEditingController(text: config?.key);
    _modelsCtrl = TextEditingController(text: config?.models.join(", "));
  }

  @override
  void dispose() {
    _modelsCtrl.dispose();
    _apiKeyCtrl.dispose();
    _apiUrlCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final api = widget.api;

    return Scaffold(
      appBar: AppBar(
        title: Text(S.of(context).api),
      ),
      body: ListView(
        padding: const EdgeInsets.only(left: 16, right: 16),
        children: [
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _type,
                  items: <DropdownMenuItem<String>>[
                    DropdownMenuItem(
                      value: "openai",
                      child: const Text("OpenAI"),
                    ),
                    DropdownMenuItem(
                      value: "google",
                      child: const Text("Google"),
                    ),
                  ],
                  isExpanded: true,
                  hint: Text(S.of(context).api_type),
                  onChanged: (it) => setState(() => _type = it),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: S.of(context).name,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _apiUrlCtrl,
            decoration: InputDecoration(
              labelText: S.of(context).api_url,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _apiKeyCtrl,
            decoration: InputDecoration(
              labelText: S.of(context).api_key,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  maxLines: 4,
                  controller: _modelsCtrl,
                  decoration: InputDecoration(
                    labelText: S.of(context).model_list,
                    alignLabelWithHint: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Spin(
                    infinite: true,
                    animate: _isFetching,
                    duration: Duration(seconds: 1),
                    child: IconButton.outlined(
                      icon: const Icon(Icons.sync),
                      onPressed: _fetchModels,
                    ),
                  ),
                  const SizedBox(height: 16),
                  IconButton.outlined(
                    icon: const Icon(Icons.edit),
                    onPressed: _editModels,
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 1,
                child: FilledButton.tonal(
                  onPressed: Navigator.of(context).pop,
                  child: Text(S.of(context).cancel),
                ),
              ),
              const SizedBox(width: 6),
              if (api != null) ...[
                const SizedBox(width: 6),
                Expanded(
                  flex: 1,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Theme.of(context).colorScheme.onError,
                    ),
                    child: Text(S.of(context).delete),
                    onPressed: () {
                      Config.apis.remove(api);
                      Config.save();

                      ref.read(apisProvider.notifier).notify();
                      Navigator.of(context).pop();
                    },
                  ),
                ),
                const SizedBox(width: 6),
              ],
              const SizedBox(width: 6),
              Expanded(
                flex: 1,
                child: FilledButton(
                  onPressed: _save,
                  child: Text(S.of(context).save),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _fetchModels() async {
    if (_isFetching) {
      _isFetching = false;
      _client?.close();
      _client = null;
      return;
    }

    final url = _apiUrlCtrl.text;
    final key = _apiKeyCtrl.text;
    final endPoint = switch (_type) {
      "google" => "$url/models?key=$key",
      _ => "$url/models",
    };

    if (url.isEmpty || key.isEmpty) {
      Util.showSnackBar(
        context: context,
        content: Text(S.of(context).complete_all_fields),
      );
      return;
    }

    setState(() => _isFetching = true);

    try {
      _client ??= Client();
      final response = await _client!.get(
        Uri.parse(endPoint),
        headers: switch (_type) {
          "google" => null,
          _ => {"Authorization": "Bearer $key"},
        },
      );

      if (response.statusCode != 200) {
        throw "${response.statusCode} ${response.body}";
      }

      final json = jsonDecode(response.body);
      List<String> models = switch (_type) {
        "google" => [
            for (final cell in json["models"]) cell["name"].substring(7),
          ],
        _ => [for (final cell in json["data"]) cell["id"]],
      };

      _modelsCtrl.text = models.join(", ");
    } catch (e) {
      if (_isFetching && mounted) {
        Dialogs.error(context: context, error: e);
      }
    }

    setState(() => _isFetching = false);
  }

  Future<void> _editModels() async {
    final text = _modelsCtrl.text;
    if (text.isEmpty) return;

    final models = text.split(',').map((it) => it.trim()).toList();
    models.removeWhere((e) => e.isEmpty);

    final chosen = {for (final it in models) it: true};
    if (chosen.isEmpty) return;

    final result = await showModalBottomSheet<bool>(
      context: context,
      scrollControlDisabledMaxHeightRatio: 0.7,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DialogHeader(title: S.of(context).select_models),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: chosen.length,
                itemBuilder: (context, index) => CheckboxListTile(
                  title: Text(models[index]),
                  value: chosen[models[index]],
                  contentPadding: const EdgeInsets.only(left: 24, right: 16),
                  onChanged: (value) =>
                      setState(() => chosen[models[index]] = value ?? false),
                ),
              ),
            ),
            const Divider(height: 1),
            DialogFooter(
              children: [
                TextButton(
                  child: Text(S.of(context).ok),
                  onPressed: () => Navigator.of(context).pop(true),
                ),
                TextButton(
                  onPressed: Navigator.of(context).pop,
                  child: Text(S.of(context).cancel),
                ),
                TextButton(
                  child: Text(S.of(context).clear),
                  onPressed: () => setState(
                      () => chosen.forEach((it, _) => chosen[it] = false)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (!(result ?? false)) return;

    _modelsCtrl.text = [
      for (final pair in chosen.entries)
        if (pair.value) pair.key
    ].join(", ");
  }

  void _save() {
    final name = _nameCtrl.text;
    final models = _modelsCtrl.text;
    final apiUrl = _apiUrlCtrl.text;
    final apiKey = _apiKeyCtrl.text;

    if (name.isEmpty || models.isEmpty || apiUrl.isEmpty || apiKey.isEmpty) {
      Util.showSnackBar(
        context: context,
        content: Text(S.of(context).complete_all_fields),
      );
      return;
    }

    final api = widget.api;
    if (Config.apis.containsKey(name) && (api == null || name != api)) {
      Util.showSnackBar(
        context: context,
        content: Text(S.of(context).duplicate_api_name),
      );
      return;
    }

    if (api != null) Config.apis.remove(api);
    final modelList = models.split(',').map((e) => e.trim()).toList();
    modelList.removeWhere((e) => e.isEmpty);

    Config.apis[name] = Api(
      name: name,
      url: apiUrl,
      key: apiKey,
      type: _type,
      models: modelList,
    );
    Config.save();

    ref.read(apisProvider.notifier).notify();
    Navigator.of(context).pop();
  }
}
