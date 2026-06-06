import 'package:flutter/material.dart';

/// Standard dialog footer: Cancel, Save (keep open), Save & Close.
class AdminDialogSaveActions extends StatefulWidget {
  const AdminDialogSaveActions({
    super.key,
    required this.dialogContext,
    required this.onSave,
    this.saveLabel = 'Save',
    this.saveAndCloseLabel = 'Save & Close',
    this.savedMessage = 'Saved.',
    this.showCancel = true,
  });

  final BuildContext dialogContext;
  final Future<bool> Function() onSave;
  final String saveLabel;
  final String saveAndCloseLabel;
  final String savedMessage;
  final bool showCancel;

  @override
  State<AdminDialogSaveActions> createState() => _AdminDialogSaveActionsState();
}

class _AdminDialogSaveActionsState extends State<AdminDialogSaveActions> {
  bool _saving = false;

  Future<void> _run({required bool closeAfter}) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final ok = await widget.onSave();
      if (!widget.dialogContext.mounted) return;
      if (!ok) return;
      if (closeAfter) {
        Navigator.of(widget.dialogContext).pop();
      } else {
        ScaffoldMessenger.of(widget.dialogContext).showSnackBar(
          SnackBar(content: Text(widget.savedMessage)),
        );
      }
    } catch (e) {
      if (widget.dialogContext.mounted) {
        ScaffoldMessenger.of(widget.dialogContext).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = _saving ? 'Saving…' : null;
    return OverflowBar(
      spacing: 8,
      children: [
        if (widget.showCancel)
          TextButton(
            onPressed:
                _saving ? null : () => Navigator.of(widget.dialogContext).pop(),
            child: const Text('Cancel'),
          ),
        OutlinedButton(
          onPressed: _saving ? null : () => _run(closeAfter: false),
          child: Text(label ?? widget.saveLabel),
        ),
        FilledButton(
          onPressed: _saving ? null : () => _run(closeAfter: true),
          child: Text(label ?? widget.saveAndCloseLabel),
        ),
      ],
    );
  }
}
