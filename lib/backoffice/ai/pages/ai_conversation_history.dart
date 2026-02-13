import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:luwa_app/core/providers/ai/ai_chat_provider.dart';
import 'package:luwa_app/shared/themes/app_theme.dart';
import 'package:luwa_app/shared/utils/format_utils.dart';


/// Model for a conversation summary displayed in the list.
/// This is a local view model; the actual data would come from
/// a conversation repository or provider.
class _ConversationSummary {
  final String id;
  final String title;
  final DateTime lastMessageAt;
  final int messageCount;
  final String source; // 'backoffice', 'pos', 'auto'

  const _ConversationSummary({
    required this.id,
    required this.title,
    required this.lastMessageAt,
    required this.messageCount,
    required this.source,
  });
}

/// Past conversations list page.
///
/// Displays a searchable, swipe-to-delete list of previous
/// AI conversations. Tap to open/continue a conversation.
class AiConversationHistory extends ConsumerStatefulWidget {
  const AiConversationHistory({super.key});

  @override
  ConsumerState<AiConversationHistory> createState() =>
      _AiConversationHistoryState();
}

class _AiConversationHistoryState
    extends ConsumerState<AiConversationHistory> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  List<_ConversationSummary> _conversations = [];
  List<_ConversationSummary> _filteredConversations = [];

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _searchController.addListener(_filterConversations);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    setState(() => _isLoading = true);
    // In production, this would load from a conversation repository.
    // For now, we use the chat provider's state or simulate loading.
    await Future.delayed(const Duration(milliseconds: 300));

    // The actual data would come from AiConversationRepository.
    // This represents the expected structure.
    final chatState = ref.read(aiChatProvider);
    final List<_ConversationSummary> loaded = [];

    // If there's an active conversation, include it
    if (chatState.conversationId != null &&
        chatState.messages.isNotEmpty) {
      loaded.add(_ConversationSummary(
        id: chatState.conversationId!,
        title: _deriveTitle(chatState.messages.first.content),
        lastMessageAt: chatState.messages.last.createdAt,
        messageCount: chatState.messages.length,
        source: 'backoffice',
      ));
    }

    if (mounted) {
      setState(() {
        _conversations = loaded;
        _filteredConversations = loaded;
        _isLoading = false;
      });
    }
  }

  String _deriveTitle(String firstMessage) {
    if (firstMessage.length <= 50) return firstMessage;
    return '${firstMessage.substring(0, 47)}...';
  }

  void _filterConversations() {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      setState(() => _filteredConversations = _conversations);
      return;
    }
    setState(() {
      _filteredConversations = _conversations
          .where((c) => c.title.toLowerCase().contains(query))
          .toList();
    });
  }

  void _openConversation(String conversationId) {
    ref.read(aiChatProvider.notifier).loadConversation(conversationId);
    Navigator.pop(context);
  }

  Future<void> _deleteConversation(String conversationId) async {
    // In production, call repository to delete
    setState(() {
      _conversations.removeWhere((c) => c.id == conversationId);
      _filterConversations();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Percakapan dihapus',
            style: GoogleFonts.inter(fontSize: 13),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
          ),
          action: SnackBarAction(
            label: 'Batal',
            textColor: Colors.white,
            onPressed: () {
              // In production, implement undo
              _loadConversations();
            },
          ),
        ),
      );
    }
  }

  String _sourceLabel(String source) {
    switch (source) {
      case 'backoffice':
        return 'Back Office';
      case 'pos':
        return 'POS';
      case 'auto':
        return 'Otomatis';
      default:
        return source;
    }
  }

  Color _sourceColor(String source) {
    switch (source) {
      case 'backoffice':
        return AppTheme.aiPrimary;
      case 'pos':
        return AppTheme.infoColor;
      case 'auto':
        return AppTheme.successColor;
      default:
        return AppTheme.textTertiary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Riwayat Percakapan',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        scrolledUnderElevation: 1,
        actions: [
          IconButton(
            onPressed: _loadConversations,
            icon: const Icon(Icons.refresh),
            color: AppTheme.textSecondary,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          _buildSearchBar(),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.aiPrimary,
                    ),
                  )
                : _filteredConversations.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadConversations,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppTheme.spacingS,
                          ),
                          itemCount: _filteredConversations.length,
                          itemBuilder: (context, index) {
                            final conversation =
                                _filteredConversations[index];
                            return _buildConversationCard(conversation);
                          },
                        ),
                      ),
          ),
        ],
      ),
      // FAB: New conversation
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ref.read(aiChatProvider.notifier).newConversation();
          Navigator.pop(context);
        },
        backgroundColor: AppTheme.aiPrimary,
        tooltip: 'Percakapan Baru',
        child: const Icon(Icons.add_comment_outlined),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(
          bottom: BorderSide(color: AppTheme.dividerColor),
        ),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Cari percakapan...',
          hintStyle: GoogleFonts.inter(
            fontSize: 14,
            color: AppTheme.textTertiary,
          ),
          prefixIcon: Icon(
            Icons.search,
            size: 20,
            color: AppTheme.textTertiary,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                  },
                  icon: Icon(
                    Icons.close,
                    size: 18,
                    color: AppTheme.textTertiary,
                  ),
                )
              : null,
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
      ),
    );
  }

  Widget _buildConversationCard(_ConversationSummary conversation) {
    return Dismissible(
      key: ValueKey(conversation.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppTheme.spacingL),
        color: AppTheme.errorColor,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.delete_outline, color: Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(
              'Hapus',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusL),
            ),
            title: Text(
              'Hapus Percakapan?',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: Text(
              'Percakapan ini akan dihapus secara permanen.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Batal',
                  style: GoogleFonts.inter(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.errorColor,
                ),
                child: Text(
                  'Hapus',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) {
        _deleteConversation(conversation.id);
      },
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingM,
          vertical: AppTheme.spacingXS,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          side: BorderSide(color: AppTheme.dividerColor),
        ),
        child: InkWell(
          onTap: () => _openConversation(conversation.id),
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: Row(
              children: [
                // AI icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.aiPrimary.withValues(alpha: 0.15),
                        AppTheme.aiSecondary.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusM),
                  ),
                  child: Icon(
                    Icons.forum_outlined,
                    size: 20,
                    color: AppTheme.aiPrimary,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingM),

                // Title and metadata
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conversation.title,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          // Date
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: AppTheme.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            FormatUtils.relativeTime(
                                conversation.lastMessageAt),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppTheme.textTertiary,
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacingM),
                          // Message count
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 12,
                            color: AppTheme.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${conversation.messageCount} pesan',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppTheme.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppTheme.spacingS),

                // Source badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _sourceColor(conversation.source)
                        .withValues(alpha: 0.1),
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusFull),
                  ),
                  child: Text(
                    _sourceLabel(conversation.source),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _sourceColor(conversation.source),
                    ),
                  ),
                ),

                const SizedBox(width: AppTheme.spacingS),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: AppTheme.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasSearchQuery = _searchController.text.isNotEmpty;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.aiBackground,
              borderRadius: BorderRadius.circular(AppTheme.radiusXL),
            ),
            child: Icon(
              hasSearchQuery ? Icons.search_off : Icons.forum_outlined,
              size: 36,
              color: AppTheme.aiPrimary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          Text(
            hasSearchQuery
                ? 'Tidak ditemukan'
                : 'Belum ada percakapan',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hasSearchQuery
                ? 'Coba kata kunci lain.'
                : 'Mulai percakapan baru dengan Luwa\nuntuk melihat riwayat di sini.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          if (!hasSearchQuery) ...[
            const SizedBox(height: AppTheme.spacingL),
            ElevatedButton.icon(
              onPressed: () {
                ref.read(aiChatProvider.notifier).newConversation();
                Navigator.pop(context);
              },
              icon: const Icon(Icons.add, size: 18),
              label: Text(
                'Mulai Percakapan',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.aiPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusFull),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingL,
                  vertical: AppTheme.spacingS + 2,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
