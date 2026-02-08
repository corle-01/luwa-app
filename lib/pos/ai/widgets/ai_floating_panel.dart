import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:utter_app/core/models/ai_insight.dart';
import 'package:utter_app/core/models/ai_message.dart';
import 'package:utter_app/core/providers/ai/ai_chat_provider.dart';
import 'package:utter_app/core/providers/ai/ai_insight_provider.dart';
import 'package:utter_app/pos/ai/widgets/ai_quick_actions.dart';
import 'package:utter_app/shared/themes/app_theme.dart';

/// AI Floating Panel
///
/// An expandable chat panel that slides up from the FAB position.
/// On desktop it renders as a floating card; on mobile it uses a
/// bottom-sheet style layout. Contains insight cards, quick actions,
/// a chat message area, and a text input field.
class AiFloatingPanel extends ConsumerStatefulWidget {
  /// Callback to close the panel.
  final VoidCallback onClose;

  /// The outlet ID for sending messages.
  final String outletId;

  /// The user ID for sending messages.
  final String userId;

  /// Callback when "Lihat semua insights" is tapped.
  final VoidCallback? onViewAllInsights;

  const AiFloatingPanel({
    super.key,
    required this.onClose,
    required this.outletId,
    required this.userId,
    this.onViewAllInsights,
  });

  @override
  ConsumerState<AiFloatingPanel> createState() => _AiFloatingPanelState();
}

class _AiFloatingPanelState extends ConsumerState<AiFloatingPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();

  bool _isMinimized = false;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.0),
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
  }

  @override
  void dispose() {
    _slideController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  /// Animate panel close, then call the onClose callback.
  Future<void> _animateClose() async {
    await _slideController.reverse();
    widget.onClose();
  }

  /// Send a message through the chat provider.
  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;

    ref.read(aiChatProvider.notifier).sendMessage(
      text.trim(),
      outletId: widget.outletId,
      userId: widget.userId,
    );
    _textController.clear();
    _inputFocusNode.requestFocus();

    // Scroll to bottom after a short delay to allow state update.
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = screenWidth < 600;

    final panelWidth = isMobile ? screenWidth : 380.0;
    final panelHeight = isMobile
        ? screenHeight * 0.85
        : 500.0.clamp(0.0, screenHeight - 100);

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Align(
          alignment: isMobile
              ? Alignment.bottomCenter
              : Alignment.bottomRight,
          child: Padding(
            padding: isMobile
                ? EdgeInsets.zero
                : const EdgeInsets.only(right: 16, bottom: 80),
            child: Material(
              color: Colors.transparent,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                width: panelWidth,
                height: _isMinimized ? 58 : panelHeight,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: isMobile
                      ? const BorderRadius.vertical(top: Radius.circular(20))
                      : BorderRadius.circular(AppTheme.radiusXL),
                  boxShadow: AppTheme.shadowLG,
                  border: Border.all(
                    color: AppTheme.aiPrimary.withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    // Header
                    _buildHeader(context),

                    // Body (hidden when minimized)
                    if (!_isMinimized)
                      Expanded(
                        child: _buildBody(context),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Panel header with title and action buttons.
  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            AppTheme.aiPrimary,
            AppTheme.aiSecondary,
          ],
        ),
      ),
      child: Row(
        children: [
          // AI icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            child: const Icon(
              Icons.psychology,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: AppTheme.spacingS),

          // Title
          const Expanded(
            child: Text(
              'Utter AI',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),

          // Minimize button
          _HeaderIconButton(
            icon: _isMinimized ? Icons.open_in_full : Icons.minimize,
            tooltip: _isMinimized ? 'Perbesar' : 'Perkecil',
            onTap: () => setState(() => _isMinimized = !_isMinimized),
          ),
          const SizedBox(width: AppTheme.spacingXS),

          // Close button
          _HeaderIconButton(
            icon: Icons.close,
            tooltip: 'Tutup',
            onTap: _animateClose,
          ),
        ],
      ),
    );
  }

  /// Panel body containing insights, quick actions, messages, and input.
  Widget _buildBody(BuildContext context) {
    return Column(
      children: [
        // Insights section
        _buildInsightsSection(context),

        // Quick actions
        _buildQuickActionsSection(context),

        const Divider(height: 1),

        // Messages area
        Expanded(
          child: _buildMessagesArea(context),
        ),

        // Input field
        _buildInputField(context),
      ],
    );
  }

  /// Top section: latest 2-3 insight cards.
  Widget _buildInsightsSection(BuildContext context) {
    final insights = ref.watch(aiActiveInsightsProvider);
    final displayInsights = insights.take(3).toList();

    if (displayInsights.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingM,
        AppTheme.spacingS,
        AppTheme.spacingM,
        AppTheme.spacingXS,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Insight cards
          ...displayInsights.map((insight) => _InsightCompactCard(
                insight: insight,
                onTap: () {
                  // Send insight title as a chat message for more details.
                  _sendMessage('Jelaskan insight: ${insight.title}');
                },
              )),

          // "View all" link
          if (insights.length > 3)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: widget.onViewAllInsights,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingS,
                    vertical: AppTheme.spacingXS,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Lihat semua insights \u2192',
                  style: TextStyle(
                    color: AppTheme.aiPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Quick action chips section.
  Widget _buildQuickActionsSection(BuildContext context) {
    return AiQuickActions(
      onActionTap: _sendMessage,
    );
  }

  /// Scrollable message display area.
  Widget _buildMessagesArea(BuildContext context) {
    final messages = ref.watch(aiChatMessagesProvider);
    final isLoading = ref.watch(aiChatLoadingProvider);
    final error = ref.watch(aiChatErrorProvider);

    if (messages.isEmpty && !isLoading) {
      return _buildEmptyState(context);
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      itemCount: messages.length + (isLoading ? 1 : 0) + (error != null ? 1 : 0),
      itemBuilder: (context, index) {
        // Show error at the end
        if (error != null && index == messages.length + (isLoading ? 1 : 0)) {
          return _buildErrorBubble(context, error);
        }

        // Show typing indicator
        if (isLoading && index == messages.length) {
          return _buildTypingIndicator(context);
        }

        // Show message bubble
        final message = messages[index];
        return _MessageBubble(message: message);
      },
    );
  }

  /// Empty state when no messages are present.
  Widget _buildEmptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.aiBackground,
                borderRadius: BorderRadius.circular(AppTheme.radiusXL),
              ),
              child: const Icon(
                Icons.psychology,
                color: AppTheme.aiPrimary,
                size: 32,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            Text(
              'Halo! Saya Utter AI',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.spacingXS),
            Text(
              'Tanya apa saja tentang bisnis Anda.\nGunakan quick action di atas untuk mulai.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// AI typing indicator (three animated dots).
  Widget _buildTypingIndicator(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(
          bottom: AppTheme.spacingS,
          right: 60,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAiAvatar(),
            const SizedBox(width: AppTheme.spacingS),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingM,
                vertical: AppTheme.spacingS,
              ),
              decoration: BoxDecoration(
                color: AppTheme.aiBackground,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppTheme.radiusL),
                  topRight: Radius.circular(AppTheme.radiusL),
                  bottomRight: Radius.circular(AppTheme.radiusL),
                  bottomLeft: Radius.circular(AppTheme.radiusS),
                ),
              ),
              child: const _TypingDots(),
            ),
          ],
        ),
      ),
    );
  }

  /// Error message bubble.
  Widget _buildErrorBubble(BuildContext context, String error) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
      padding: const EdgeInsets.all(AppTheme.spacingS),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(
          color: AppTheme.errorColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.errorColor, size: 18),
          const SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.errorColor,
              ),
            ),
          ),
          InkWell(
            onTap: () => ref.read(aiChatProvider.notifier).clearError(),
            child: const Icon(Icons.close, color: AppTheme.errorColor, size: 16),
          ),
        ],
      ),
    );
  }

  /// Small AI avatar icon.
  Widget _buildAiAvatar() {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.aiSecondary, AppTheme.aiPrimary],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
      ),
      child: const Icon(
        Icons.psychology,
        color: Colors.white,
        size: 16,
      ),
    );
  }

  /// Chat input field with send button.
  Widget _buildInputField(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLoading = ref.watch(aiChatLoadingProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingS,
        AppTheme.spacingS,
        AppTheme.spacingS,
        AppTheme.spacingS,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : AppTheme.dividerColor,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Text input
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF374151)
                      : AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : AppTheme.borderColor.withValues(alpha: 0.5),
                  ),
                ),
                child: TextField(
                  controller: _textController,
                  focusNode: _inputFocusNode,
                  enabled: !isLoading,
                  maxLines: 3,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _sendMessage,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Ketik pesan...',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white38 : AppTheme.textTertiary,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppTheme.spacingS),

            // Send button
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isLoading
                    ? null
                    : const LinearGradient(
                        colors: [AppTheme.aiSecondary, AppTheme.aiPrimary],
                      ),
                color: isLoading
                    ? (isDark ? const Color(0xFF374151) : AppTheme.borderColor)
                    : null,
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
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private sub-widgets
// ---------------------------------------------------------------------------

/// Header icon button (minimize / close).
class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          child: SizedBox(
            width: 32,
            height: 32,
            child: Icon(icon, color: Colors.white, size: 18),
          ),
        ),
      ),
    );
  }
}

/// Compact insight card shown in the insights section.
class _InsightCompactCard extends StatelessWidget {
  final AiInsight insight;
  final VoidCallback? onTap;

  const _InsightCompactCard({
    required this.insight,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingXS),
      child: Material(
        color: isDark
            ? insight.severityColor.withValues(alpha: 0.1)
            : insight.severityColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingS,
              vertical: AppTheme.spacingS,
            ),
            child: Row(
              children: [
                // Severity color indicator
                Container(
                  width: 4,
                  height: 32,
                  decoration: BoxDecoration(
                    color: insight.severityColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingS),

                // Type icon
                Icon(
                  insight.typeIcon,
                  color: insight.severityColor,
                  size: 18,
                ),
                const SizedBox(width: AppTheme.spacingS),

                // Title
                Expanded(
                  child: Text(
                    insight.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : AppTheme.textPrimary,
                    ),
                  ),
                ),

                // Chevron
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: isDark ? Colors.white38 : AppTheme.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Single chat message bubble.
class _MessageBubble extends StatelessWidget {
  final AiMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: AppTheme.spacingS,
          left: isUser ? 48 : 0,
          right: isUser ? 0 : 48,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // AI avatar (left side)
            if (!isUser) ...[
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.aiSecondary, AppTheme.aiPrimary],
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
                child: const Icon(
                  Icons.psychology,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: AppTheme.spacingS),
            ],

            // Message content
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingM,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isUser
                      ? AppTheme.aiPrimary
                      : (isDark
                          ? const Color(0xFF374151)
                          : AppTheme.aiBackground),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(AppTheme.radiusL),
                    topRight: const Radius.circular(AppTheme.radiusL),
                    bottomLeft: Radius.circular(
                        isUser ? AppTheme.radiusL : AppTheme.radiusS),
                    bottomRight: Radius.circular(
                        isUser ? AppTheme.radiusS : AppTheme.radiusL),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  message.content,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: isUser
                        ? Colors.white
                        : (isDark ? Colors.white : AppTheme.textPrimary),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated three-dot typing indicator.
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
            final bounce = (t < 0.5)
                ? (t * 2.0)
                : (2.0 - t * 2.0);
            return Padding(
              padding: EdgeInsets.only(
                right: index < 2 ? 4 : 0,
              ),
              child: Transform.translate(
                offset: Offset(0, -4 * bounce),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: AppTheme.aiPrimary.withValues(alpha: 0.5 + 0.5 * bounce),
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
