import 'package:flutter/material.dart';
import 'package:party_queue_app/src/features/party/application/party_room_controller.dart';
import 'package:party_queue_app/src/features/party/domain/models/party_room.dart';
import 'package:party_queue_app/src/features/party/domain/models/user_profile.dart';

class RoomGuestsSheet extends StatelessWidget {
  const RoomGuestsSheet({super.key, required this.controller});

  final PartyRoomController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final room = controller.room;
        if (room == null) {
          return const SafeArea(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final participants = room.participants.values.toList()
          ..sort((a, b) => _compareParticipants(room, a, b));
        final hasOnlyHost = participants.length == 1;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Gaeste',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('${participants.length} Teilnehmer im Raum'),
                const SizedBox(height: 16),
                if (hasOnlyHost)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text('Noch keine weiteren Gaeste im Raum.'),
                  ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: participants.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final participant = participants[index];
                      final isHost = participant.id == room.hostUserId;
                      final isCurrentUser =
                          participant.id == controller.activeUserId;
                      final canKick = controller.isHost && !isHost;
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              participant.displayName.trim().isEmpty
                                  ? '?'
                                  : participant.displayName.characters.first
                                        .toUpperCase(),
                            ),
                          ),
                          title: Text(participant.displayName),
                          subtitle: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              if (isHost) const _GuestBadge(label: 'Host'),
                              if (isCurrentUser) const _GuestBadge(label: 'Du'),
                            ],
                          ),
                          trailing: canKick
                              ? IconButton(
                                  tooltip: 'Gast entfernen',
                                  onPressed: () =>
                                      _kickParticipant(context, participant),
                                  icon: const Icon(
                                    Icons.person_remove_outlined,
                                  ),
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _kickParticipant(
    BuildContext context,
    UserProfile participant,
  ) async {
    final roomBefore = controller.room;
    final existedBefore =
        roomBefore?.participants.containsKey(participant.id) ?? false;
    await controller.kickParticipant(participant.id);
    final roomAfter = controller.room;
    final existsAfter =
        roomAfter?.participants.containsKey(participant.id) ?? false;
    if (!context.mounted || !existedBefore || existsAfter) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('${participant.displayName} entfernt.')),
      );
  }

  int _compareParticipants(PartyRoom room, UserProfile a, UserProfile b) {
    final aIsHost = a.id == room.hostUserId;
    final bIsHost = b.id == room.hostUserId;
    if (aIsHost != bIsHost) {
      return aIsHost ? -1 : 1;
    }
    return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
  }
}

class _GuestBadge extends StatelessWidget {
  const _GuestBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
