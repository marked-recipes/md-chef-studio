import 'package:flutter/material.dart';

class CommitDialog extends StatefulWidget {
  final String title;
  final String defaultMessage;
  final String actionLabel;
  final bool isDestructive;

  const CommitDialog({
    super.key,
    required this.title,
    required this.defaultMessage,
    required this.actionLabel,
    this.isDestructive = false,
  });

  @override
  State<CommitDialog> createState() => _CommitDialogState();
}

class _CommitDialogState extends State<CommitDialog> {
  late final TextEditingController _messageController;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController(text: widget.defaultMessage);
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter a commit message to record this change in the Git repository history:',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                labelText: 'Commit Message',
                hintText: 'e.g. feat(pasta): add authentic carbonara recipe',
              ),
              maxLines: 2,
              autofocus: true,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: widget.isDestructive
              ? ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white)
              : null,
          onPressed: () {
            final msg = _messageController.text.trim();
            Navigator.of(context).pop(msg.isNotEmpty ? msg : widget.defaultMessage);
          },
          child: Text(widget.actionLabel),
        ),
      ],
    );
  }
}
