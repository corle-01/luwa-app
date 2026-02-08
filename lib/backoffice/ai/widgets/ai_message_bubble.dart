import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:utter_app/core/models/ai_message.dart';
import 'package:utter_app/shared/themes/app_theme.dart';
import 'package:utter_app/shared/utils/format_utils.dart';
import 'package:utter_app/backoffice/ai/widgets/ai_function_result_card.dart';

/// A single chat message bubble.
///
/// Renders differently based on message role:
/// - User messages: right-aligned, primary color background
/// - Assistant messages: left-aligned, grey background with AI avatar
/// - Function messages: center-aligned, compact function result card
class AiMessageBubble extends StatefulWidget {
  /// The message to display.
  final AiMessage message;

  /// Whether to show the timestamp.
  final bool showTimestamp;

  const AiMessageBubble({
    super.key,
    required this.message,
    this.showTimestamp = true,
  });

  @override
  State<AiMessageBubble> createState() => _AiMessageBubbleState();
}

class _AiMessageBubbleState extends State<AiMessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: _buildMessageContent(),
      ),
    );
  }

  Widget _buildMessageContent() {
    final message = widget.message;

    // Function messages
    if (message.isFunction) {
      return _buildFunctionMessage();
    }

    // System messages
    if (message.isSystem) {
      return _buildSystemMessage();
    }

    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppTheme.spacingXS,
        horizontal: AppTheme.spacingM,
      ),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // AI Avatar (only for assistant)
              if (!isUser) ...[
                Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.only(right: 8, bottom: 2),
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
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ],

              // Message bubble
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.7,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isUser
                        ? AppTheme.primaryColor
                        : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft:
                          isUser ? const Radius.circular(16) : Radius.zero,
                      bottomRight:
                          isUser ? Radius.zero : const Radius.circular(16),
                    ),
                    boxShadow: AppTheme.shadowSM,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Message text with basic formatting
                      _FormattedText(
                        text: message.content,
                        isUser: isUser,
                      ),
                      // Inline function calls
                      if (message.hasFunctionCalls) ...[
                        const SizedBox(height: AppTheme.spacingS),
                        ...message.parsedFunctionCalls.map(
                          (fc) => Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: AiFunctionResultCard(
                              functionName: fc.name,
                              arguments: fc.arguments,
                              result: fc.result,
                              compact: true,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Timestamp
          if (widget.showTimestamp) ...[
            Padding(
              padding: EdgeInsets.only(
                top: 4,
                left: isUser ? 0 : 36,
                right: isUser ? 0 : 0,
              ),
              child: Text(
                FormatUtils.time(message.createdAt),
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: AppTheme.textTertiary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFunctionMessage() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppTheme.spacingXS,
        horizontal: AppTheme.spacingL,
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingM,
            vertical: AppTheme.spacingS,
          ),
          decoration: BoxDecoration(
            color: AppTheme.aiBackground,
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
            border: Border.all(
              color: AppTheme.aiPrimary.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.functions,
                size: 14,
                color: AppTheme.aiPrimary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  widget.message.content,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.aiPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSystemMessage() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppTheme.spacingS,
        horizontal: AppTheme.spacingXL,
      ),
      child: Center(
        child: Text(
          widget.message.content,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppTheme.textTertiary,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// Widget that renders text with basic markdown-like formatting.
///
/// Supports: **bold**, *italic*, `code`
class _FormattedText extends StatelessWidget {
  final String text;
  final bool isUser;

  const _FormattedText({
    required this.text,
    required this.isUser,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = isUser ? AppTheme.textWhite : AppTheme.textPrimary;
    final spans = _parseFormattedText(text, baseColor);

    return RichText(
      text: TextSpan(
        style: GoogleFonts.inter(
          fontSize: 14,
          color: baseColor,
          height: 1.5,
        ),
        children: spans,
      ),
    );
  }

  List<TextSpan> _parseFormattedText(String text, Color baseColor) {
    final List<TextSpan> spans = [];
    final RegExp pattern = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*|`(.+?)`');
    int lastIndex = 0;

    for (final match in pattern.allMatches(text)) {
      // Add text before the match
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
        ));
      }

      if (match.group(1) != null) {
        // Bold: **text**
        spans.add(TextSpan(
          text: match.group(1),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ));
      } else if (match.group(2) != null) {
        // Italic: *text*
        spans.add(TextSpan(
          text: match.group(2),
          style: const TextStyle(fontStyle: FontStyle.italic),
        ));
      } else if (match.group(3) != null) {
        // Code: `text`
        spans.add(TextSpan(
          text: match.group(3),
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            backgroundColor: isUser
                ? Colors.white.withValues(alpha: 0.15)
                : AppTheme.backgroundColor,
          ),
        ));
      }

      lastIndex = match.end;
    }

    // Add remaining text
    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
      ));
    }

    return spans.isEmpty ? [TextSpan(text: text)] : spans;
  }
}
