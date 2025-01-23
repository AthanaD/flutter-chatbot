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

import "config.dart";
import "../gen/l10n.dart";
import "chat/current.dart";

import "dart:io";
import "package:flutter/services.dart";
import "package:flutter/material.dart";
import "package:share_plus/share_plus.dart";
import "package:flutter_svg/flutter_svg.dart";
import "package:url_launcher/url_launcher.dart";
import "package:image_gallery_saver_plus/image_gallery_saver_plus.dart";

class Util {
  static Future<void> copyText({
    required BuildContext context,
    required String text,
  }) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    Util.showSnackBar(
      context: context,
      content: Text(S.of(context).copied_successfully),
    );
  }

  static Future<void> checkUpdate({
    required BuildContext context,
    required bool notify,
  }) async {
    try {
      final info = await Updater.check();
      if (!context.mounted) return;

      if (info == null) {
        if (notify) {
          showSnackBar(
            context: context,
            content: Text(S.of(context).up_to_date),
          );
        }
        return;
      }

      String changeLog = info["body"];
      String newVersion = info["tag_name"];

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(newVersion),
          content: SingleChildScrollView(child: Text(changeLog)),
          actions: [
            TextButton(
              onPressed: Navigator.of(context).pop,
              child: Text(S.of(context).cancel),
            ),
            TextButton(
              child: Text(S.of(context).download),
              onPressed: () {
                launchUrl(Uri.parse(Updater.latestUrl));
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      );
    } catch (e) {
      if (notify) Dialogs.error(context: context, error: e);
    }
  }

  static bool checkApiModel(int? id, String? model) {
    final api = apiWith(id);
    return api != null && model != null && api.models.contains(model);
  }

  static bool checkChat(BuildContext context) {
    final core = Current.chatCore;

    if (!checkApiModel(core.api, core.model)) {
      showSnackBar(
        context: context,
        content: Text(S.of(context).setup_api_model_first),
      );
      return false;
    }

    if (Preferences.search) {
      final search = Config.webSearch;
      final vector = Config.vectorStore;
      final vectorOk = checkApiModel(vector.api, vector.model);
      final searchOk = Preferences.googleSearch || search.searxng != null;

      if (!searchOk) {
        showSnackBar(
          context: context,
          content: Text(S.of(context).setup_searxng_first),
        );
        return false;
      }

      if (search.vector && !vectorOk) {
        showSnackBar(
          context: context,
          content: Text(S.of(context).setup_vector_first),
        );
        return false;
      }
    }

    return true;
  }

  static void showSnackBar({
    required Text content,
    required BuildContext context,
    Duration duration = const Duration(milliseconds: 800),
    SnackBarBehavior behavior = SnackBarBehavior.floating,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: content,
        duration: duration,
        behavior: behavior,
        dismissDirection: DismissDirection.down,
      ),
    );
  }

  static String formatDateTime(DateTime time) {
    String two(int n) => n.toString().padLeft(2, '0');

    return "${two(time.month)}/${two(time.day)} "
        "${two(time.hour)}:${two(time.minute)}";
  }
}

class Dialogs {
  static Future<List<String>?> input({
    required BuildContext context,
    required String title,
    required List<InputDialogField> fields,
  }) async {
    return await showModalBottomSheet<List<String>>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: InputDialog(
          title: title,
          fields: fields,
        ),
      ),
    );
  }

  static void error({
    required BuildContext context,
    required dynamic error,
  }) {
    final info = error.toString();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.of(context).error),
        content: SingleChildScrollView(child: SelectableText(info)),
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: Text(S.of(context).cancel),
          ),
          TextButton(
            onPressed: () {
              Util.copyText(context: context, text: info);
              Navigator.of(context).pop();
            },
            child: Text(S.of(context).copy),
          ),
        ],
      ),
    );
  }

  static Future<String?> select({
    required BuildContext context,
    required List<String> list,
    required String title,
    String? selected,
  }) async {
    return await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      scrollControlDisabledMaxHeightRatio: 0.7,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DialogHeader(title: title),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: list.length,
                itemBuilder: (context, index) => RadioListTile(
                  value: list[index],
                  groupValue: selected,
                  title: Text(list[index]),
                  contentPadding: const EdgeInsets.only(left: 16, right: 24),
                  onChanged: (value) => setState(() => selected = value),
                ),
              ),
            ),
            const Divider(height: 1),
            DialogFooter(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(selected),
                  child: Text(S.of(context).ok),
                ),
                TextButton(
                  onPressed: Navigator.of(context).pop,
                  child: Text(S.of(context).cancel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static void loading({
    required BuildContext context,
    required String hint,
    bool canPop = false,
  }) {
    showDialog(
      context: context,
      barrierDismissible: canPop,
      builder: (context) => PopScope(
        canPop: canPop,
        child: AlertDialog(
          contentPadding: const EdgeInsets.all(24),
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 24),
              Text(hint),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> openLink({
    required BuildContext context,
    required String? link,
  }) async {
    if (link == null) {
      Util.showSnackBar(
        context: context,
        content: Text(S.of(context).empty_link),
      );
      return;
    }

    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.of(context).link),
        content: Text(link),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(1),
            child: Text(S.of(context).copy),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(2),
            child: Text(S.of(context).open),
          ),
        ],
      ),
    );

    switch (result) {
      case 1:
        if (!context.mounted) return;
        Util.copyText(context: context, text: link);
        break;

      case 2:
        final uri = Uri.parse(link);
        if (await canLaunchUrl(uri)) {
          launchUrl(uri, mode: LaunchMode.platformDefault);
        } else {
          if (!context.mounted) return;
          Util.showSnackBar(
            context: context,
            content: Text(S.of(context).cannot_open),
          );
        }
        break;
    }
  }

  static Future<void> handleImage({
    required BuildContext context,
    required String path,
  }) async {
    final action = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DragHandle(),
            ListTile(
              minTileHeight: 48,
              shape: StadiumBorder(),
              title: Text(S.of(context).share),
              onTap: () => Navigator.pop(context, 1),
              leading: const Icon(Icons.share_outlined),
            ),
            ListTile(
              minTileHeight: 48,
              shape: StadiumBorder(),
              title: Text(S.of(context).save),
              onTap: () => Navigator.pop(context, 2),
              leading: const Icon(Icons.save_outlined),
            ),
          ],
        ),
      ),
    );
    if (action == null) return;

    if (!Platform.isAndroid) {
      final uri = Uri.file(path);
      launchUrl(uri);
      return;
    }

    switch (action) {
      case 1:
        Share.shareXFiles([XFile(path)]);
        break;

      case 2:
        final result = await ImageGallerySaverPlus.saveFile(path);
        if (!context.mounted) return;
        if (result is Map && result["isSuccess"] == true) {
          Util.showSnackBar(
            context: context,
            content: Text(S.of(context).saved_successfully),
          );
        }
        break;
    }
  }
}

class InputDialogField {
  final String? text;
  final String? hint;
  final String? help;
  final String? label;
  final int? maxLines;

  const InputDialogField({
    this.hint,
    this.text,
    this.help,
    this.label,
    this.maxLines = 1,
  });
}

class InputDialog extends StatefulWidget {
  final String title;
  final List<InputDialogField> fields;

  const InputDialog({
    required this.title,
    required this.fields,
    super.key,
  });

  @override
  State<InputDialog> createState() => _InputDialogState();
}

class _InputDialogState extends State<InputDialog> {
  late final List<TextEditingController> _ctrls;

  @override
  void initState() {
    super.initState();
    _ctrls = [
      for (final field in widget.fields)
        TextEditingController(text: field.text),
    ];
  }

  @override
  void dispose() {
    for (final ctrl in _ctrls) {
      ctrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fields = widget.fields;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DialogHeader(
          title: widget.title,
          padding: const EdgeInsets.only(top: 16),
        ),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.only(left: 24, right: 24),
            itemCount: fields.length,
            itemBuilder: (context, index) => TextField(
              controller: _ctrls[index],
              maxLines: fields[index].maxLines,
              decoration: InputDecoration(
                hintText: fields[index].hint,
                labelText: fields[index].label,
                helperText: fields[index].help,
                border: const UnderlineInputBorder(),
              ),
            ),
            separatorBuilder: (context, index) => const SizedBox(height: 8),
          ),
        ),
        DialogFooter(
          padding: const EdgeInsets.only(top: 16, bottom: 16),
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(<String>[
                for (final ctrl in _ctrls) ctrl.text,
              ]),
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
}

class InfoCard extends StatelessWidget {
  final String info;

  const InfoCard({
    required this.info,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      margin: const EdgeInsets.only(left: 16, right: 16),
      child: Padding(
        padding: const EdgeInsets.only(top: 8, left: 12, right: 12, bottom: 8),
        child: Row(
          children: [
            Icon(
              Icons.info_outlined,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                info,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ModelAvatar extends StatelessWidget {
  final String? id;
  static const String _prefix = "assets/images";
  static const Map<String, String> _mappings = {
    "o1": "openai.svg",
    "gpt": "openai.svg",
    "claude": "claude.svg",
    "gemini": "gemini.svg",
    "grok": "grok.svg",
    "qwen": "qwen.svg",
    "llama": "ollama.svg",
    "deepseek": "deepseek.svg",
  };
  static final Map<String, SvgPicture?> _caches = {};

  const ModelAvatar({
    required this.id,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final image = _getImage(context);

    if (image == null) {
      return const CircleAvatar(
        child: Icon(Icons.smart_toy),
      );
    }

    return CircleAvatar(
      child: image,
    );
  }

  SvgPicture? _getImage(BuildContext context) {
    if (id == null) return null;

    final brightness = Theme.of(context).brightness;
    final key = "$id.${brightness.index}";

    return _caches.putIfAbsent(key, () {
      String? fileName;
      final modelId = id!.toLowerCase();

      for (final pair in _mappings.entries) {
        if (modelId.contains(pair.key)) {
          fileName = pair.value;
          break;
        }
      }

      if (fileName == null) return null;

      return SvgPicture.asset(
        "$_prefix/$fileName",
        colorFilter: ColorFilter.mode(
          Theme.of(context).iconTheme.color!,
          BlendMode.srcIn,
        ),
      );
    });
  }
}

class DragHandle extends StatelessWidget {
  final Size size;
  final EdgeInsets margin;

  const DragHandle({
    this.size = const Size(32, 4),
    this.margin = const EdgeInsets.only(
      top: 16,
      bottom: 8,
    ),
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: margin,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            borderRadius: BorderRadius.all(Radius.circular(2)),
          ),
          child: SizedBox.fromSize(size: size),
        ),
      ),
    );
  }
}

class DialogHeader extends StatelessWidget {
  final String title;
  final EdgeInsets padding;

  const DialogHeader({
    required this.title,
    this.padding = const EdgeInsets.only(
      top: 16,
      bottom: 16,
    ),
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          const SizedBox(width: 24),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: Navigator.of(context).pop,
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

class DialogFooter extends StatelessWidget {
  final EdgeInsets padding;
  final List<Widget> children;

  const DialogFooter({
    required this.children,
    this.padding = const EdgeInsets.only(
      top: 12,
      bottom: 12,
    ),
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final child1 = children.elementAt(0);
    final child2 = children.elementAtOrNull(1);
    final child3 = children.elementAtOrNull(2);

    return Padding(
      padding: padding,
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          const SizedBox(width: 24),
          child1,
          const SizedBox(width: 8),
          if (child2 != null) child2,
          const Expanded(child: SizedBox()),
          if (child3 != null) child3,
          const SizedBox(width: 24),
        ],
      ),
    );
  }
}
