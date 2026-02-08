import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:utter_app/core/providers/ai/ai_chat_provider.dart';
import 'package:utter_app/shared/themes/app_theme.dart';
import 'package:utter_app/backoffice/ai/widgets/ai_message_bubble.dart';

/// Full chat interface widget for the AI dashboard.
///
/// Includes a header, scrollable message list, quick action chips,
/// typing indicator, and text input field with send button.
class AiChatWidget extends ConsumerStatefulWidget {
  /// Optional outlet ID for the current context.
  final String? outletId;

  /// Optional user ID for the current user.
  final String? userId;

  const AiChatWidget({
    super.key,
    this.outletId,
    this.userId,
  });

  @override
  ConsumerState<AiChatWidget> createState() => _AiChatWidgetState();
}

class _AiChatWidgetState extends ConsumerState<AiChatWidget> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  static const List<_QuickAction> _quickActions = [
    _QuickAction(
      label: 'Ringkasan Hari Ini',
      message: 'Berikan ringkasan penjualan hari ini lengkap dengan detail order dan produk terlaris',
      icon: Icons.summarize_outlined,
    ),
    _QuickAction(
      label: 'Cek Stok Menipis',
      message: 'Tampilkan semua bahan baku yang stoknya menipis',
      icon: Icons.inventory_2_outlined,
    ),
    _QuickAction(
      label: 'Daftar Menu',
      message: 'Tampilkan semua menu/produk yang aktif beserta harganya',
      icon: Icons.restaurant_menu,
    ),
    _QuickAction(
      label: 'Tambah Menu Baru',
      message: 'Saya mau tambah menu baru',
      icon: Icons.add_circle_outline,
    ),
  ];

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;

    ref.read(aiChatProvider.notifier).sendMessage(
          text,
          outletId: widget.outletId ?? '',
          userId: widget.userId ?? '',
        );
    _messageController.clear();
    _focusNode.requestFocus();
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(aiChatProvider);
    final messages = chatState.messages;
    final isLoading = chatState.isLoading;
    final error = chatState.error;

    // Auto-scroll when messages change
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        children: [
          // Chat header
          _buildHeader(),
          const Divider(height: 1),

          // Messages area
          Expanded(
            child: messages.isEmpty
                ? _buildEmptyState()
                : _buildMessageList(messages, isLoading),
          ),

          // Error banner
          if (error != null) _buildErrorBanner(error),

          // Quick action chips (show when no messages)
          if (messages.isEmpty) _buildQuickActions(),

          // Typing indicator
          if (isLoading) _buildTypingIndicator(),

          const Divider(height: 1),

          // Input field
          _buildInputField(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppTheme.radiusL),
          topRight: Radius.circular(AppTheme.radiusL),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.aiPrimary, AppTheme.aiSecondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            ),
            child: const Icon(
              Icons.auto_awesome,
              size: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chat dengan Utter',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  'AI Co-Pilot bisnis kamu',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              ref.read(aiChatProvider.notifier).newConversation();
            },
            icon: const Icon(
              Icons.add_comment_outlined,
              size: 20,
            ),
            tooltip: 'Percakapan baru',
            color: AppTheme.textSecondary,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.aiPrimary.withValues(alpha: 0.15),
                    AppTheme.aiSecondary.withValues(alpha: 0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusXL),
              ),
              child: Icon(
                Icons.auto_awesome,
                size: 32,
                color: AppTheme.aiPrimary.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            Text(
              'Halo! Saya Utter.',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Saya bisa kelola menu, cek stok, analisa penjualan,\ndan eksekusi aksi langsung di sistem POS kamu.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(List messages, bool isLoading) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingS),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        // Determine whether to show timestamp
        // Show for the last message, or if the next message is from a different role
        final showTimestamp = index == messages.length - 1 ||
            messages[index + 1].role != message.role;

        return AiMessageBubble(
          message: message,
          showTimestamp: showTimestamp,
        );
      },
    );
  }

  Widget _buildErrorBanner(String error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      color: AppTheme.errorColor.withValues(alpha: 0.1),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 16,
            color: AppTheme.errorColor,
          ),
          const SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: Text(
              error,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppTheme.errorColor,
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              ref.read(aiChatProvider.notifier).clearError();
            },
            icon: Icon(
              Icons.close,
              size: 16,
              color: AppTheme.errorColor,
            ),
            constraints: const BoxConstraints(
              minWidth: 24,
              minHeight: 24,
            ),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingM,
        0,
        AppTheme.spacingM,
        AppTheme.spacingS,
      ),
      child: Wrap(
        spacing: AppTheme.spacingS,
        runSpacing: AppTheme.spacingS,
        children: _quickActions.map((action) {
          return ActionChip(
            avatar: Icon(
              action.icon,
              size: 16,
              color: AppTheme.aiPrimary,
            ),
            label: Text(
              action.label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppTheme.aiPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            onPressed: () => _sendMessage(action.message),
            backgroundColor: AppTheme.aiBackground,
            side: BorderSide(
              color: AppTheme.aiPrimary.withValues(alpha: 0.2),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.aiPrimary, AppTheme.aiSecondary],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            ),
            child: const Icon(
              Icons.auto_awesome,
              size: 14,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const _TypingDots(),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingS),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(AppTheme.radiusL),
          bottomRight: Radius.circular(AppTheme.radiusL),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: 'Ketik pesan...',
                hintStyle: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppTheme.textTertiary,
                ),
                filled: true,
                fillColor: AppTheme.backgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  borderSide: const BorderSide(
                    color: AppTheme.aiPrimary,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                isDense: true,
              ),
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textPrimary,
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: _sendMessage,
              maxLines: null,
            ),
          ),
          const SizedBox(width: AppTheme.spacingS),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.aiPrimary, AppTheme.aiSecondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            ),
            child: IconButton(
              onPressed: () => _sendMessage(_messageController.text),
              icon: const Icon(
                Icons.send_rounded,
                size: 18,
                color: Colors.white,
              ),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}

/// Quick action data class.
class _QuickAction {
  final String label;
  final String message;
  final IconData icon;

  const _QuickAction({
    required this.label,
    required this.message,
    required this.icon,
  });
}

/// Animated typing dots indicator.
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (index) {
      return AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      );
    });
    _animations = _controllers.map((controller) {
      return Tween<double>(begin: 0, end: -6).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      );
    }).toList();

    // Stagger the animations
    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) {
          _controllers[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _animations[index],
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _animations[index].value),
              child: Container(
                margin: EdgeInsets.only(
                  right: index < 2 ? 4 : 0,
                ),
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: AppTheme.aiPrimary.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
