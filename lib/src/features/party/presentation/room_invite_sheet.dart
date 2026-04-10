import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

class RoomInviteSheet extends StatelessWidget {
  const RoomInviteSheet({
    super.key,
    required this.roomCode,
    required this.inviteLink,
  });

  final String roomCode;
  final Uri inviteLink;

  @override
  Widget build(BuildContext context) {
    final linkText = inviteLink.toString();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Einladen',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _InviteValueCard(
              label: 'Invite-Link',
              value: linkText,
              buttonLabel: 'Link kopieren',
              onCopy: () => _copy(context, linkText, 'Invite-Link kopiert.'),
            ),
            const SizedBox(height: 12),
            _InviteValueCard(
              label: 'Room-Code',
              value: roomCode,
              buttonLabel: 'Code kopieren',
              onCopy: () => _copy(context, roomCode, 'Room-Code kopiert.'),
            ),
            const SizedBox(height: 16),
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: QrImageView(
                  data: linkText,
                  size: 180,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                'QR-Code fuehrt direkt in denselben Raum-Link.',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copy(
    BuildContext context,
    String value,
    String confirmation,
  ) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(confirmation)));
  }
}

class _InviteValueCard extends StatelessWidget {
  const _InviteValueCard({
    required this.label,
    required this.value,
    required this.buttonLabel,
    required this.onCopy,
  });

  final String label;
  final String value;
  final String buttonLabel;
  final Future<void> Function() onCopy;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SelectableText(value),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: onCopy,
                child: Text(buttonLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
