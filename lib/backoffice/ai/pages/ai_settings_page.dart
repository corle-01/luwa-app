import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:utter_app/core/config/app_constants.dart';
import 'package:utter_app/core/providers/ai/ai_trust_provider.dart';
import 'package:utter_app/shared/themes/app_theme.dart';
import 'package:utter_app/backoffice/ai/widgets/trust_level_slider.dart';

/// AI Trust Settings page.
///
/// Allows the user to configure how autonomous the AI is
/// for each supported feature. Organized by feature group.
class AiSettingsPage extends ConsumerStatefulWidget {
  const AiSettingsPage({super.key});

  @override
  ConsumerState<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends ConsumerState<AiSettingsPage> {
  // Track local changes before save
  final Map<String, int> _pendingChanges = {};

  @override
  Widget build(BuildContext context) {
    final trustState = ref.watch(aiTrustProvider);
    final isLoading = trustState.isLoading;


    // Listen for errors
    ref.listen<String?>(
      aiTrustProvider.select((state) => state.error),
      (previous, next) {
        if (next != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(next),
              backgroundColor: AppTheme.errorColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
          ref.read(aiTrustProvider.notifier).clearError();
        }
      },
    );

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.aiPrimary, AppTheme.aiSecondary],
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              child: const Icon(
                Icons.tune,
                size: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: AppTheme.spacingS),
            Text(
              'Utter AI Settings',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: isLoading && trustState.settings.isEmpty
          ? const Center(
              child: CircularProgressIndicator(
                color: AppTheme.aiPrimary,
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppTheme.spacingM),
                    decoration: BoxDecoration(
                      color: AppTheme.aiBackground,
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusL),
                      border: Border.all(
                        color: AppTheme.aiPrimary.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: AppTheme.aiPrimary,
                        ),
                        const SizedBox(width: AppTheme.spacingS),
                        Expanded(
                          child: Text(
                            'Atur seberapa otonom Utter bertindak untuk setiap fitur. '
                            'Semakin tinggi level, semakin mandiri Utter bekerja.',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppTheme.aiPrimary,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingL),

                  // INVENTORY section
                  _buildSection(
                    title: 'INVENTORY',
                    icon: Icons.inventory_2_outlined,
                    color: AppTheme.infoColor,
                    features: [
                      _FeatureConfig(
                        key: AppConstants.featureStockAlert,
                        label: 'Stock Alert',
                        description:
                            'Notifikasi ketika stok mendekati batas minimum',
                      ),
                      _FeatureConfig(
                        key: AppConstants.featureAutoDisableProduct,
                        label: 'Auto-disable Produk',
                        description:
                            'Nonaktifkan produk otomatis saat stok habis',
                      ),
                      _FeatureConfig(
                        key: AppConstants.featureAutoEnableProduct,
                        label: 'Auto-enable Produk',
                        description:
                            'Aktifkan kembali produk saat stok tersedia',
                      ),
                      _FeatureConfig(
                        key: AppConstants.featureAutoReorder,
                        label: 'Auto-reorder ke Supplier',
                        description:
                            'Buat PO otomatis saat stok menipis',
                      ),
                    ],
                    trustState: trustState,
                  ),
                  const SizedBox(height: AppTheme.spacingL),

                  // PRICING & PROMO section
                  _buildSection(
                    title: 'PRICING & PROMO',
                    icon: Icons.local_offer_outlined,
                    color: AppTheme.warningColor,
                    features: [
                      _FeatureConfig(
                        key: AppConstants.featurePricingRecommendation,
                        label: 'Pricing Recommendation',
                        description:
                            'Rekomendasi penyesuaian harga berdasarkan data',
                      ),
                      _FeatureConfig(
                        key: AppConstants.featureAutoPromo,
                        label: 'Auto Promo',
                        description:
                            'Buat promo otomatis untuk meningkatkan penjualan',
                      ),
                    ],
                    trustState: trustState,
                  ),
                  const SizedBox(height: AppTheme.spacingL),

                  // FORECASTING section
                  _buildSection(
                    title: 'FORECASTING',
                    icon: Icons.trending_up,
                    color: AppTheme.successColor,
                    features: [
                      _FeatureConfig(
                        key: AppConstants.featureDemandForecast,
                        label: 'Demand Forecast',
                        description:
                            'Prediksi permintaan untuk perencanaan stok',
                      ),
                      _FeatureConfig(
                        key: AppConstants.featureMenuRecommendation,
                        label: 'Menu Recommendation',
                        description:
                            'Rekomendasi menu berdasarkan tren dan preferensi',
                      ),
                    ],
                    trustState: trustState,
                  ),
                  const SizedBox(height: AppTheme.spacingL),

                  // SECURITY section
                  _buildSection(
                    title: 'KEAMANAN',
                    icon: Icons.shield_outlined,
                    color: AppTheme.errorColor,
                    features: [
                      _FeatureConfig(
                        key: AppConstants.featureAnomalyAlert,
                        label: 'Anomaly Detection',
                        description:
                            'Deteksi aktivitas tidak wajar (void berlebih, dll.)',
                      ),
                    ],
                    trustState: trustState,
                  ),
                  const SizedBox(height: AppTheme.spacingL),

                  // OPERATIONS section
                  _buildSection(
                    title: 'OPERASIONAL',
                    icon: Icons.people_outline,
                    color: AppTheme.aiPrimary,
                    features: [
                      _FeatureConfig(
                        key: AppConstants.featureStaffingSuggestion,
                        label: 'Staffing Suggestion',
                        description:
                            'Saran penjadwalan staff berdasarkan forecast',
                      ),
                    ],
                    trustState: trustState,
                  ),
                  const SizedBox(height: AppTheme.spacingXL),

                  // Reset to default button
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: _showResetConfirmation,
                      icon: const Icon(Icons.restart_alt, size: 18),
                      label: Text(
                        'Reset ke Default',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        side: const BorderSide(color: AppTheme.borderColor),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingL,
                          vertical: AppTheme.spacingS + 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusM),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingXL),
                ],
              ),
            ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<_FeatureConfig> features,
    required AiTrustState trustState,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        side: BorderSide(color: AppTheme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(width: AppTheme.spacingS),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingS),
            const Divider(),

            // Feature sliders
            ...features.map((feature) {
              final setting =
                  trustState.getByFeatureKey(feature.key);
              final currentLevel =
                  _pendingChanges[feature.key] ??
                      setting?.trustLevel ??
                      0;
              final isEnabled = setting?.isEnabled ?? true;

              return TrustLevelSlider(
                featureKey: feature.key,
                currentLevel: currentLevel,
                isEnabled: isEnabled,
                label: feature.label,
                description: feature.description,
                onChanged: (level) {
                  setState(() {
                    _pendingChanges[feature.key] = level;
                  });
                  // Save immediately
                  ref
                      .read(aiTrustProvider.notifier)
                      .updateTrustLevel(
                        feature.key,
                        level,
                        updatedBy: 'current_user',
                      )
                      .then((_) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${feature.label} diubah ke level $level',
                            style: GoogleFonts.inter(fontSize: 13),
                          ),
                          backgroundColor: AppTheme.successColor,
                          behavior: SnackBarBehavior.floating,
                          duration:
                              const Duration(milliseconds: 1500),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                AppTheme.radiusM),
                          ),
                        ),
                      );
                    }
                  });
                },
                onToggle: (enabled) {
                  ref
                      .read(aiTrustProvider.notifier)
                      .toggleFeature(
                        feature.key,
                        isEnabled: enabled,
                        updatedBy: 'current_user',
                      );
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showResetConfirmation() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusL),
          ),
          title: Row(
            children: [
              Icon(
                Icons.restart_alt,
                size: 24,
                color: AppTheme.warningColor,
              ),
              const SizedBox(width: AppTheme.spacingS),
              Text(
                'Reset ke Default?',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: Text(
            'Semua pengaturan trust level akan dikembalikan ke "Inform Only" (level 0). '
            'Utter hanya akan memberitahu tanpa melakukan aksi otomatis.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Batal',
                style: GoogleFonts.inter(
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _resetToDefaults();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.warningColor,
              ),
              child: Text(
                'Reset',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _resetToDefaults() {
    final settings = ref.read(aiTrustProvider).settings;
    for (final setting in settings) {
      ref.read(aiTrustProvider.notifier).updateTrustLevel(
            setting.featureKey,
            0,
            updatedBy: 'current_user',
          );
    }
    setState(() {
      _pendingChanges.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Semua pengaturan telah direset ke default',
          style: GoogleFonts.inter(fontSize: 13),
        ),
        backgroundColor: AppTheme.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
        ),
      ),
    );
  }
}

/// Internal data class for feature configuration within a section.
class _FeatureConfig {
  final String key;
  final String label;
  final String description;

  const _FeatureConfig({
    required this.key,
    required this.label,
    required this.description,
  });
}
