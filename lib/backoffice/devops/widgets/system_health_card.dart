import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:utter_app/shared/themes/app_theme.dart';
import 'package:utter_app/core/providers/devops/devops_health_provider.dart';

/// System Health Card - Displays backend health metrics
class SystemHealthCard extends ConsumerWidget {
  const SystemHealthCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthAsync = ref.watch(devopsHealthProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.shadowSM,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.monitor_heart, size: 20, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                'System Health',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          healthAsync.when(
            data: (health) => _buildHealthMetrics(health),
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (error, stack) => _buildError(error.toString()),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthMetrics(Map<String, dynamic> health) {
    final database = health['database'] as Map<String, dynamic>? ?? {};
    final realtime = health['realtime'] as Map<String, dynamic>? ?? {};
    final api = health['api'] as Map<String, dynamic>? ?? {};

    return Column(
      children: [
        _buildHealthRow(
          'Database',
          database['status'] as String? ?? 'unknown',
          Icons.storage,
          database['status'] == 'healthy' ? Colors.green : Colors.red,
          details: database['connection'] as String?,
        ),
        const SizedBox(height: 12),
        _buildHealthRow(
          'Realtime',
          realtime['status'] as String? ?? 'unknown',
          Icons.cell_tower,
          realtime['status'] == 'connected' ? Colors.green : Colors.orange,
          details: '${realtime['channels'] ?? 0} channels',
        ),
        const SizedBox(height: 12),
        _buildHealthRow(
          'API',
          api['status'] as String? ?? 'unknown',
          Icons.api,
          api['status'] == 'healthy' ? Colors.green : Colors.red,
        ),
      ],
    );
  }

  Widget _buildHealthRow(
    String label,
    String status,
    IconData icon,
    Color color, {
    String? details,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                details ?? status,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Text(
            status,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError(String error) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Failed to load health metrics: $error',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
