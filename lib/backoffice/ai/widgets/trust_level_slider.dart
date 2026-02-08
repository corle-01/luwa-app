import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:utter_app/shared/themes/app_theme.dart';

/// A custom slider widget for configuring AI trust levels.
///
/// Displays a 4-stop slider (0-3) with color-coded levels,
/// descriptive labels, and an enable/disable toggle.
class TrustLevelSlider extends ConsumerStatefulWidget {
  /// The feature key this slider controls.
  final String featureKey;

  /// The current trust level (0-3).
  final int currentLevel;

  /// Whether this feature is currently enabled.
  final bool isEnabled;

  /// Human-readable label for this feature.
  final String label;

  /// Optional description text.
  final String? description;

  /// Callback when the trust level changes.
  final ValueChanged<int> onChanged;

  /// Callback when the enabled state toggles.
  final ValueChanged<bool>? onToggle;

  const TrustLevelSlider({
    super.key,
    required this.featureKey,
    required this.currentLevel,
    this.isEnabled = true,
    required this.label,
    this.description,
    required this.onChanged,
    this.onToggle,
  });

  @override
  ConsumerState<TrustLevelSlider> createState() => _TrustLevelSliderState();
}

class _TrustLevelSliderState extends ConsumerState<TrustLevelSlider>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  static const List<String> _levelLabels = [
    'Inform',
    'Suggest',
    'Auto',
    'Silent',
  ];

  static const List<String> _levelDescriptions = [
    'Utter hanya memberitahu kamu',
    'Utter memberi saran dan minta konfirmasi',
    'Utter jalankan otomatis dan notify kamu',
    'Utter jalankan tanpa pemberitahuan',
  ];

  static const List<Color> _levelColors = [
    AppTheme.trustLevelInform,
    AppTheme.trustLevelSuggest,
    AppTheme.trustLevelAuto,
    AppTheme.trustLevelSilent,
  ];

  static const List<IconData> _levelIcons = [
    Icons.info_outline,
    Icons.lightbulb_outline,
    Icons.flash_on,
    Icons.auto_awesome,
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Color get _activeColor {
    final level = widget.currentLevel.clamp(0, 3);
    return _levelColors[level];
  }

  @override
  Widget build(BuildContext context) {
    final level = widget.currentLevel.clamp(0, 3);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Opacity(
        opacity: widget.isEnabled ? 1.0 : 0.5,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppTheme.spacingS,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: label + toggle
              Row(
                children: [
                  Icon(
                    _levelIcons[level],
                    size: 20,
                    color: widget.isEnabled
                        ? _activeColor
                        : AppTheme.textTertiary,
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.label,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        if (widget.description != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.description!,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppTheme.textTertiary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (widget.onToggle != null)
                    Switch(
                      value: widget.isEnabled,
                      onChanged: widget.onToggle,
                      activeThumbColor: _activeColor,
                    ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingS),

              // Slider
              IgnorePointer(
                ignoring: !widget.isEnabled,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: _activeColor.withValues(alpha: 0.8),
                    inactiveTrackColor: AppTheme.dividerColor,
                    thumbColor: _activeColor,
                    overlayColor: _activeColor.withValues(alpha: 0.15),
                    trackHeight: 6,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 10,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 20,
                    ),
                    tickMarkShape: const RoundSliderTickMarkShape(
                      tickMarkRadius: 4,
                    ),
                    activeTickMarkColor: Colors.white,
                    inactiveTickMarkColor: AppTheme.borderColor,
                  ),
                  child: Slider(
                    value: level.toDouble(),
                    min: 0,
                    max: 3,
                    divisions: 3,
                    onChanged: (value) {
                      widget.onChanged(value.round());
                    },
                  ),
                ),
              ),

              // Level labels row
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppTheme.spacingXS),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(4, (index) {
                    final isActive = index == level;
                    return Text(
                      _levelLabels[index],
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight:
                            isActive ? FontWeight.w600 : FontWeight.normal,
                        color: isActive ? _activeColor : AppTheme.textTertiary,
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: AppTheme.spacingS),

              // Current level description
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Container(
                  key: ValueKey(level),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingM,
                    vertical: AppTheme.spacingS,
                  ),
                  decoration: BoxDecoration(
                    color: _activeColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    border: Border.all(
                      color: _activeColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _levelIcons[level],
                        size: 16,
                        color: _activeColor,
                      ),
                      const SizedBox(width: AppTheme.spacingS),
                      Expanded(
                        child: Text(
                          _levelDescriptions[level],
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: _activeColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
