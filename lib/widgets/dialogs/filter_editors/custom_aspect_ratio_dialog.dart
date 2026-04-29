import 'package:aves/model/filters/aspect_ratio.dart';
import 'package:aves/model/filters/query.dart';
import 'package:aves/ref/unicode.dart';
import 'package:aves/widgets/common/extensions/build_context.dart';
import 'package:aves/widgets/common/providers/media_query_data_provider.dart';
import 'package:aves/widgets/dialogs/aves_dialog.dart';
import 'package:flutter/material.dart';

class CustomAspectRatioDialog extends StatefulWidget {
  static const routeName = '/dialog/custom_aspect_ratio';

  const CustomAspectRatioDialog({super.key});

  @override
  State<CustomAspectRatioDialog> createState() => _CustomAspectRatioDialogState();

  static String promptLabel(BuildContext context) => context.locale.startsWith('zh') ? '自定义比例' : 'Custom ratio';
}

class _CustomAspectRatioDialogState extends State<CustomAspectRatioDialog> {
  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();

  AspectRatioFilter? _filter;

  static final _presets = [
    AspectRatioFilter.ratio3x2,
    AspectRatioFilter.ratio2x3,
    AspectRatioFilter.ratio4x5,
    AspectRatioFilter.ratio5x4,
    AspectRatioFilter.ratio21x9,
    AspectRatioFilter.ratio9x21,
    AspectRatioFilter.ratio27x10,
    AspectRatioFilter.ratio2x1,
    AspectRatioFilter.ratio1x2,
  ];

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isChinese = context.locale.startsWith('zh');
    _recomputeFilter();
    return MediaQueryDataProvider(
      child: Builder(
        builder: (context) {
          return AvesDialog(
            title: CustomAspectRatioDialog.promptLabel(context),
            scrollableContent: [
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _presets.map((filter) {
                    return ActionChip(
                      label: Text(filter.ratioText ?? filter.universalLabel),
                      onPressed: () => Navigator.maybeOf(context)?.pop(filter),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        isChinese ? '或手动输入' : 'or enter manually',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _widthController,
                        decoration: InputDecoration(
                          labelText: isChinese ? '宽' : 'W',
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textAlign: TextAlign.center,
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        ':',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _heightController,
                        decoration: InputDecoration(
                          labelText: isChinese ? '高' : 'H',
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textAlign: TextAlign.center,
                        textInputAction: TextInputAction.done,
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _submitCustom(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            actions: [
              const CancelButton(),
              TextButton(
                onPressed: _filter != null ? () => _submitCustom(context) : null,
                child: Text(context.l10n.applyButtonLabel),
              ),
            ],
          );
        },
      ),
    );
  }

  void _recomputeFilter() {
    final w = double.tryParse(_widthController.text.trim());
    final h = double.tryParse(_heightController.text.trim());
    if (w != null && h != null && w > 0 && h > 0) {
      _filter = AspectRatioFilter(
        w / h,
        QueryFilter.opEqual,
        tolerance: AspectRatioFilter.customTolerance,
        ratioText: '${_formatInput(w)}${UniChars.ratio}${_formatInput(h)}',
      );
    } else {
      _filter = null;
    }
  }

  String _formatInput(double v) {
    return v == v.truncateToDouble() ? v.toInt().toString() : v.toString();
  }

  void _submitCustom(BuildContext context) {
    final filter = _filter;
    if (filter != null) {
      Navigator.maybeOf(context)?.pop(filter);
    }
  }
}
