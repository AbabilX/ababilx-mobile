import 'package:flutter/material.dart';

/// One field + one button, inside a bottom sheet. [submit] returns null on
/// success (the sheet closes) or the reason it failed (shown under the
/// field; the text stays so nothing is retyped).
class SpaceFormSheet extends StatefulWidget {
  const SpaceFormSheet({
    super.key,
    required this.title,
    required this.hint,
    required this.action,
    required this.validate,
    required this.submit,
    this.note,
    this.maxLength,
  });

  final String title;
  final String hint;
  final String action;
  final String? note;
  final int? maxLength;
  final String? Function(String value) validate;
  final Future<String?> Function(String value) submit;

  @override
  State<SpaceFormSheet> createState() => _SpaceFormSheetState();
}

class _SpaceFormSheetState extends State<SpaceFormSheet> {
  final _text = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    final bad = widget.validate(_text.text);
    if (bad != null) return setState(() => _error = bad);
    setState(() {
      _busy = true;
      _error = null;
    });
    final failed = await widget.submit(_text.text);
    if (!mounted) return;
    if (failed == null) return Navigator.of(context).pop();
    setState(() {
      _busy = false;
      _error = failed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _text,
            autofocus: true,
            enabled: !_busy,
            maxLength: widget.maxLength,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _go(),
            decoration: InputDecoration(
              hintText: widget.hint,
              errorText: _error,
              errorMaxLines: 3,
            ),
          ),
          if (widget.note != null)
            Text(
              widget.note!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _go,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.action),
          ),
        ],
      ),
    );
  }
}
