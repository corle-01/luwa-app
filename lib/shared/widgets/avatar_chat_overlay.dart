import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/ai_message.dart';
import '../../core/providers/ai/ai_chat_provider.dart';
import '../../core/providers/ai/ai_persona_provider.dart';
import '../../core/providers/outlet_provider.dart';
import '../../core/services/ai/ai_memory_service.dart';
import '../../core/services/voice_command_service.dart';
import '../themes/app_theme.dart';
import 'luwa_avatar.dart';

/// Avatar Chat Overlay
///
/// A beautiful chat overlay that slides in when the avatar is tapped.
/// Features:
/// - Custom BG pattern background
/// - Avatar appears in AI message bubbles
/// - Mood-reactive header gradient
/// - Smooth slide + fade animation
class AvatarChatOverlay extends ConsumerStatefulWidget {
  final VoidCallback onClose;
  final String outletId;

  const AvatarChatOverlay({
    super.key,
    required this.onClose,
    required this.outletId,
  });

  @override
  ConsumerState<AvatarChatOverlay> createState() => _AvatarChatOverlayState();
}

class _AvatarChatOverlayState extends ConsumerState<AvatarChatOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();

  // Voice command
  final VoiceCommandService _voiceService = VoiceCommandService();
  bool _isVoiceListening = false;
  bool _isSpeaking = false;
  StreamSubscription<String>? _voiceResultSub;
  StreamSubscription<VoiceStatus>? _voiceStatusSub;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    _slideController.forward();

    // Initialize voice
    _voiceService.preloadVoices();
    if (VoiceCommandService.isSupported) {
      _voiceService.initialize();
      _voiceResultSub = _voiceService.onResult.listen((text) {
        if (text.isNotEmpty) {
          _sendMessage(text);
        }
      });
      _voiceStatusSub = _voiceService.onStatus.listen((status) {
        if (mounted) {
          setState(() {
            _isVoiceListening = status == VoiceStatus.listening;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    _voiceResultSub?.cancel();
    _voiceStatusSub?.cancel();
    _voiceService.dispose();
    super.dispose();
  }

  Future<void> _animateClose() async {
    await _slideController.reverse();
    widget.onClose();
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;

    ref.read(aiChatProvider.notifier).sendMessage(
          text.trim(),
          outletId: widget.outletId,
          userId: 'pos-user',
        );
    _textController.clear();
    _inputFocusNode.requestFocus();

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Color _getMoodColor(BusinessMood? mood) {
    switch (mood) {
      case BusinessMood.thriving:
        return const Color(0xFF10B981);
      case BusinessMood.good:
        return const Color(0xFF34D399);
      case BusinessMood.steady:
        return AppTheme.aiPrimary;
      case BusinessMood.slow:
        return const Color(0xFFF59E0B);
      case BusinessMood.concerned:
        return const Color(0xFFEF4444);
      case null:
        return AppTheme.aiPrimary;
    }
  }

  String _getMoodGreeting(BusinessMood? mood) {
    switch (mood) {
      case BusinessMood.thriving:
        return 'Bisnis lagi rame banget! Ada yang bisa dibantu?';
      case BusinessMood.good:
        return 'Bisnis lagi bagus nih! Mau tanya apa?';
      case BusinessMood.steady:
        return 'Halo! Saya siap membantu bisnis kamu.';
      case BusinessMood.slow:
        return 'Hari agak sepi ya... Mau analisis bareng?';
      case BusinessMood.concerned:
        return 'Ada beberapa hal yang perlu diperhatikan. Yuk diskusi!';
      case null:
        return 'Halo! Saya Luwa AI, asisten bisnis kamu.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = screenWidth < 600;
    final panelWidth = isMobile ? screenWidth : 400.0;
    final mood = ref.watch(aiBusinessMoodProvider)?.mood;

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            width: panelWidth,
            height: screenHeight,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 24,
                  offset: const Offset(-4, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildHeader(context, mood),
                Expanded(child: _buildChatArea(context, mood)),
                _buildInputField(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, BusinessMood? mood) {
    final moodColor = _getMoodColor(mood);
    final moodData = ref.watch(aiBusinessMoodProvider);

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 8,
        bottom: 12,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            moodColor,
            moodColor.withValues(alpha: 0.8),
            AppTheme.aiPrimary.withValues(alpha: 0.9),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: moodColor.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Mini avatar in header
          LuwaMiniAvatar(size: 40),
          const SizedBox(width: 12),

          // Title + mood
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Haru AI',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                if (moodData != null)
                  Text(
                    '${moodData.moodEmoji} ${moodData.moodText}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
              ],
            ),
          ),

          // Close button
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: _animateClose,
            tooltip: 'Tutup',
          ),
        ],
      ),
    );
  }

  Widget _buildChatArea(BuildContext context, BusinessMood? mood) {
    final messages = ref.watch(aiChatMessagesProvider);
    final isLoading = ref.watch(aiChatLoadingProvider);
    final error = ref.watch(aiChatErrorProvider);

    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/chat_bg_pattern.png'),
          repeat: ImageRepeat.repeat,
          opacity: 0.08,
        ),
      ),
      child: messages.isEmpty && !isLoading
          ? _buildEmptyState(context, mood)
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: messages.length +
                  (isLoading ? 1 : 0) +
                  (error != null ? 1 : 0),
              itemBuilder: (context, index) {
                if (error != null &&
                    index == messages.length + (isLoading ? 1 : 0)) {
                  return _buildErrorBubble(error);
                }
                if (isLoading && index == messages.length) {
                  return _buildTypingBubble();
                }
                return _AvatarMessageBubble(
                  message: messages[index],
                  onSpeak: _speakText,
                  isSpeaking: _isSpeaking,
                );
              },
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context, BusinessMood? mood) {
    final greeting = _getMoodGreeting(mood);
    final moodColor = _getMoodColor(mood);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar (larger, no tap handler)
            LuwaAvatar(size: 80),
            const SizedBox(height: 16),

            // Greeting bubble
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                greeting,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppTheme.textPrimary,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Quick action suggestions
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _QuickChip(
                  label: 'Ringkasan hari ini',
                  icon: Icons.summarize,
                  color: moodColor,
                  onTap: () => _sendMessage('Berikan ringkasan bisnis hari ini'),
                ),
                _QuickChip(
                  label: 'Cek stok',
                  icon: Icons.inventory_2_outlined,
                  color: AppTheme.accentColor,
                  onTap: () => _sendMessage('Cek stok yang hampir habis'),
                ),
                _QuickChip(
                  label: 'Produk terlaris',
                  icon: Icons.trending_up,
                  color: AppTheme.successColor,
                  onTap: () => _sendMessage('Apa produk terlaris minggu ini?'),
                ),
                _QuickChip(
                  label: 'Saran bisnis',
                  icon: Icons.lightbulb_outline,
                  color: AppTheme.infoColor,
                  onTap: () =>
                      _sendMessage('Berikan saran untuk meningkatkan penjualan'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, right: 60),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Mini avatar
            LuwaMiniAvatar(size: 28),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.aiBackground,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                  bottomLeft: Radius.circular(4),
                ),
              ),
              child: const _TypingDots(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBubble(String error) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.errorColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(error,
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppTheme.errorColor)),
          ),
          InkWell(
            onTap: () => ref.read(aiChatProvider.notifier).clearError(),
            child:
                const Icon(Icons.close, color: AppTheme.errorColor, size: 14),
          ),
        ],
      ),
    );
  }

  void _toggleVoice() {
    if (_isVoiceListening) {
      _voiceService.stopListening();
    } else {
      _voiceService.startListening();
    }
  }

  void _speakText(String text) {
    if (!VoiceCommandService.isTtsSupported) return;

    if (_isSpeaking) {
      // Stop if already speaking
      _voiceService.stopSpeaking();
      if (mounted) setState(() => _isSpeaking = false);
      return;
    }

    setState(() => _isSpeaking = true);
    _voiceService.speak(
      _cleanForTts(text),
      onDone: () {
        if (mounted) setState(() => _isSpeaking = false);
      },
    );
  }

  /// Strip markdown formatting so TTS reads clean text.
  String _cleanForTts(String text) {
    var clean = text;
    // Remove bold/italic markers
    clean = clean.replaceAll(RegExp(r'\*{1,3}'), '');
    clean = clean.replaceAll(RegExp(r'_{1,3}'), '');
    // Remove markdown headers
    clean = clean.replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '');
    // Remove bullet/list markers
    clean = clean.replaceAll(RegExp(r'^[\-\*]\s+', multiLine: true), '');
    clean = clean.replaceAll(RegExp(r'^\d+\.\s+', multiLine: true), '');
    // Remove code blocks and inline code
    clean = clean.replaceAll(RegExp(r'```[\s\S]*?```'), '');
    clean = clean.replaceAll(RegExp(r'`([^`]+)`'), r'$1');
    // Remove links [text](url) → text
    clean = clean.replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1');
    // Remove emojis (common unicode ranges)
    clean = clean.replaceAll(RegExp(r'[\u{1F300}-\u{1F9FF}]', unicode: true), '');
    clean = clean.replaceAll(RegExp(r'[\u{2600}-\u{27BF}]', unicode: true), '');
    // Collapse whitespace
    clean = clean.replaceAll(RegExp(r'\n{2,}'), '. ');
    clean = clean.replaceAll(RegExp(r'\s{2,}'), ' ');
    return clean.trim();
  }

  Widget _buildInputField(BuildContext context) {
    final isLoading = ref.watch(aiChatLoadingProvider);
    final hasVoice = VoiceCommandService.isSupported;

    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppTheme.dividerColor.withValues(alpha: 0.5)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Mic button
          if (hasVoice)
            GestureDetector(
              onTap: isLoading ? null : _toggleVoice,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isVoiceListening
                      ? AppTheme.errorColor.withValues(alpha: 0.1)
                      : AppTheme.backgroundColor,
                  border: Border.all(
                    color: _isVoiceListening
                        ? AppTheme.errorColor.withValues(alpha: 0.5)
                        : AppTheme.borderColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(
                  _isVoiceListening ? Icons.mic : Icons.mic_none,
                  size: 18,
                  color: _isVoiceListening
                      ? AppTheme.errorColor
                      : AppTheme.textSecondary,
                ),
              ),
            ),
          if (hasVoice) const SizedBox(width: 6),

          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _isVoiceListening
                    ? AppTheme.errorColor.withValues(alpha: 0.04)
                    : AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _isVoiceListening
                      ? AppTheme.errorColor.withValues(alpha: 0.3)
                      : AppTheme.borderColor.withValues(alpha: 0.5),
                ),
              ),
              child: TextField(
                controller: _textController,
                focusNode: _inputFocusNode,
                enabled: !isLoading && !_isVoiceListening,
                maxLines: 3,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: _sendMessage,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppTheme.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: _isVoiceListening
                      ? 'Mendengarkan...'
                      : 'Ketik pesan...',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 14,
                    color: _isVoiceListening
                        ? AppTheme.errorColor.withValues(alpha: 0.6)
                        : AppTheme.textTertiary,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isLoading
                  ? null
                  : const LinearGradient(
                      colors: [AppTheme.aiSecondary, AppTheme.aiPrimary],
                    ),
              color: isLoading ? AppTheme.borderColor : null,
            ),
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: isLoading
                    ? null
                    : () => _sendMessage(_textController.text),
                customBorder: const CircleBorder(),
                child: Icon(
                  isLoading ? Icons.hourglass_top : Icons.send,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Message bubble with avatar for AI messages.
class _AvatarMessageBubble extends StatelessWidget {
  final AiMessage message;
  final void Function(String text)? onSpeak;
  final bool isSpeaking;

  const _AvatarMessageBubble({
    required this.message,
    this.onSpeak,
    this.isSpeaking = false,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final hasTts = VoiceCommandService.isTtsSupported && !isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 8,
          left: isUser ? 48 : 0,
          right: isUser ? 0 : 48,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // AI avatar (bird image)
            if (!isUser) ...[
              LuwaMiniAvatar(size: 28),
              const SizedBox(width: 8),
            ],

            // Message content
            Flexible(
              child: Column(
                crossAxisAlignment:
                    isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isUser ? AppTheme.aiPrimary : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isUser ? 16 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      message.content,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.5,
                        color: isUser ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  // TTS button for AI messages
                  if (hasTts)
                    Padding(
                      padding: const EdgeInsets.only(top: 2, left: 4),
                      child: InkWell(
                        onTap: () => onSpeak?.call(message.content),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isSpeaking
                                    ? Icons.stop_rounded
                                    : Icons.volume_up_rounded,
                                size: 13,
                                color: isSpeaking
                                    ? AppTheme.errorColor
                                    : AppTheme.textTertiary,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                isSpeaking ? 'Stop' : 'Dengar',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: isSpeaking
                                      ? AppTheme.errorColor
                                      : AppTheme.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quick action chip for empty state.
class _QuickChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated typing dots.
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final t = (_controller.value - delay).clamp(0.0, 1.0);
            final bounce = (t < 0.5) ? (t * 2.0) : (2.0 - t * 2.0);
            return Padding(
              padding: EdgeInsets.only(right: index < 2 ? 4 : 0),
              child: Transform.translate(
                offset: Offset(0, -3 * bounce),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppTheme.aiPrimary
                        .withValues(alpha: 0.4 + 0.6 * bounce),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
