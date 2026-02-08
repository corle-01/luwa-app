import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shared/themes/app_theme.dart';
import 'report_page.dart';
import 'hpp_report_page.dart';
import 'monthly_analytics_page.dart';
import 'advanced_analytics_page.dart';

class ReportHubPage extends StatefulWidget {
  const ReportHubPage({super.key});

  @override
  State<ReportHubPage> createState() => _ReportHubPageState();
}

class _ReportHubPageState extends State<ReportHubPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          // Tab bar header
          Container(
            color: AppTheme.surfaceColor,
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Text(
                      'Laporan',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TabBar(
                    controller: _tabController,
                    labelColor: AppTheme.primaryColor,
                    unselectedLabelColor: AppTheme.textSecondary,
                    indicatorColor: AppTheme.primaryColor,
                    indicatorWeight: 3,
                    labelStyle: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    unselectedLabelStyle: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    isScrollable: true,
                    tabs: const [
                      Tab(text: 'Penjualan'),
                      Tab(text: 'HPP'),
                      Tab(text: 'Analitik'),
                      Tab(text: 'Advanced'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                ReportPage(),
                HppReportPage(),
                MonthlyAnalyticsPage(),
                AdvancedAnalyticsPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
