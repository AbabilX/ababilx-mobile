import 'package:flutter/material.dart';

class CreateTaskField extends StatefulWidget {
  const CreateTaskField({
    super.key,
    required this.onCreate,
    this.disabled = false,
  });

  final Future<void> Function(String title) onCreate;
  final bool disabled;

  @override
  State<CreateTaskField> createState() => _CreateTaskFieldState();
}

class _CreateTaskFieldState extends State<CreateTaskField> {
  var _open = false;
  var _busy = false;
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _start() {
    if (widget.disabled) return;
    setState(() => _open = true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  Future<void> _submit() async {
    final title = _controller.text.trim();
    if (title.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await widget.onCreate(title);
      _controller.clear();
      if (mounted) setState(() => _open = false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (!_open) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextButton.icon(
          onPressed: widget.disabled ? null : _start,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add task'),
          style: TextButton.styleFrom(
            alignment: Alignment.centerLeft,
            foregroundColor: colors.onSurfaceVariant,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            focusNode: _focus,
            enabled: !_busy,
            maxLines: 3,
            minLines: 2,
            decoration: InputDecoration(
              hintText: 'Task title…',
              filled: true,
              fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.all(10),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Add'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _busy
                    ? null
                    : () {
                        _controller.clear();
                        setState(() => _open = false);
                      },
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
