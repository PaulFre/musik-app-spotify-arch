class PlaybackCommandResult {
  const PlaybackCommandResult({
    required this.success,
    this.effectiveTrackId,
    this.effectiveDeviceId,
    this.errorCode,
    this.errorMessage,
    this.retryable = false,
  });

  const PlaybackCommandResult.success({
    this.effectiveTrackId,
    this.effectiveDeviceId,
  }) : success = true,
       errorCode = null,
       errorMessage = null,
       retryable = false;

  const PlaybackCommandResult.failure({
    required this.errorCode,
    required this.errorMessage,
    this.retryable = false,
    this.effectiveTrackId,
    this.effectiveDeviceId,
  }) : success = false;

  final bool success;
  final String? effectiveTrackId;
  final String? effectiveDeviceId;
  final String? errorCode;
  final String? errorMessage;
  final bool retryable;
}
