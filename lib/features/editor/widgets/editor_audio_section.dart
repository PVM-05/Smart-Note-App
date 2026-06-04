import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/design/app_colors.dart';

class EditorAudioSection extends StatelessWidget {
  final List<String> audioUrls;
  final bool isRecording;
  final Duration recordDuration;
  final String? playingUrl;
  final bool isPlaying;
  final Duration playPosition;
  final Duration playTotal;
  final String? noteColor;
  final ValueChanged<String> onTogglePlay;
  final ValueChanged<double> onSeek;
  final Function(String, int) onDeleteAudio;
  final VoidCallback onStopRecording;

  const EditorAudioSection({
    super.key,
    required this.audioUrls,
    required this.isRecording,
    required this.recordDuration,
    required this.playingUrl,
    required this.isPlaying,
    required this.playPosition,
    required this.playTotal,
    required this.noteColor,
    required this.onTogglePlay,
    required this.onSeek,
    required this.onDeleteAudio,
    required this.onStopRecording,
  });

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _buildRecordingIndicator() {
    const recordColor = Color(0xFFEF4444);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: recordColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: recordColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.4, end: 1.0),
            duration: const Duration(milliseconds: 600),
            builder: (_, val, child) => Opacity(opacity: val, child: child),
            child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                    color: recordColor, shape: BoxShape.circle)),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Text(
            'Đang ghi âm... ${_formatDuration(recordDuration)}',
            style: GoogleFonts.outfit(
                color: recordColor, fontWeight: FontWeight.w600),
          )),
          GestureDetector(
            onTap: onStopRecording,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                  color: recordColor, borderRadius: BorderRadius.circular(20)),
              child: const Text('Dừng',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleKeepAudioItem(
      BuildContext context, String url, int index) {
    final isThisPlaying = playingUrl == url && isPlaying;
    final isThisLoaded = playingUrl == url;
    final isCustomColor = noteColor != null;
    const primaryColor = AppColors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isThisPlaying
            ? (isCustomColor
                ? const Color(0xFFBFDBFE).withValues(alpha: 0.3)
                : const Color(0xFFEFF6FF))
            : (isCustomColor
                ? Colors.black.withValues(alpha: 0.03)
                : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: isThisPlaying
              ? const Color(0xFFBFDBFE)
              : (isCustomColor
                  ? Colors.black.withValues(alpha: 0.06)
                  : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => onTogglePlay(url),
            child: CircleAvatar(
              radius: 18,
              backgroundColor:
                  isThisPlaying ? primaryColor : const Color(0xFFCBD5E1),
              child: Icon(
                  isThisPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ghi âm âm thanh ${index + 1}',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isThisLoaded
                      ? '${_formatDuration(playPosition)} / ${_formatDuration(playTotal)}'
                      : '00:00',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: isCustomColor
                        ? const Color(0xFF64748B)
                        : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          if (isThisLoaded && playTotal.inMilliseconds > 0)
            SizedBox(
              width: 80,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 4),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
                ),
                child: Slider(
                  value: playPosition.inMilliseconds
                      .toDouble()
                      .clamp(0, playTotal.inMilliseconds.toDouble()),
                  max: playTotal.inMilliseconds.toDouble(),
                  activeColor: primaryColor,
                  inactiveColor: Colors.grey.shade300,
                  onChanged: onSeek,
                ),
              ),
            ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => onDeleteAudio(url, index),
            child: Icon(Icons.delete_outline_rounded,
                color: Colors.grey.shade400, size: 20),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (audioUrls.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...audioUrls
              .asMap()
              .entries
              .map((e) => _buildGoogleKeepAudioItem(context, e.value, e.key)),
        ],
        if (isRecording) ...[
          const SizedBox(height: 8),
          _buildRecordingIndicator(),
        ],
      ],
    );
  }
}
