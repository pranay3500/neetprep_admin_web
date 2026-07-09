import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
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

  void _finishSaving() {
    if (mounted) setState(() => _saving = false);
  }

  String _formatError(Object e) {
    if (e is FirebaseException) {
      if (e.code == 'permission-denied') {
        return 'Save failed: permission denied. Sign in as owner/moderator '
            'and ensure Firestore rules are deployed.';
      }
      return 'Save failed (${e.code}): ${e.message ?? 'unknown error'}';
    }
    if (e is TimeoutException) {
      return e.message ?? 'Save timed out. Check your connection and try again.';
    }
    return 'Save failed: $e';
  }

  Future<void> _run({required bool closeAfter}) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final ok = await widget.onSave();
      if (!mounted) return;
      if (!ok) return;
      if (!widget.dialogContext.mounted) return;
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
          SnackBar(
            content: Text(_formatError(e)),
            backgroundColor: const Color(0xFFC62828),
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } finally {
      _finishSaving();
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
