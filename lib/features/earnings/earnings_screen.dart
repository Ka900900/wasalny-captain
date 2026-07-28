import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:waslny_captain/core/theme/app_theme.dart';
import 'package:waslny_captain/core/models/earnings_data.dart';
import 'package:waslny_captain/core/repositories/earnings_repository.dart';

/// Period selector tabs.
enum EarningsTab { daily, weekly, monthly }

/// Full earnings screen with period switching, bar chart and trip statistics.
///
/// Data is fetched live from the Waslny Backend API via [EarningsRepository]
/// (`GET /api/v1/driver/earnings?period=...`). There is no fallback to fake
/// or sample data — if the request fails (expired token, server error, or no
/// connectivity) a clear Arabic error message with a retry button is shown to
/// the captain instead of silently hiding the problem.
class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  EarningsTab _currentTab = EarningsTab.daily;

  EarningsData? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = switch (_currentTab) {
        EarningsTab.daily => await EarningsRepository.instance.fetchDaily(),
        EarningsTab.weekly => await EarningsRepository.instance.fetchWeekly(),
        EarningsTab.monthly => await EarningsRepository.instance.fetchMonthly(),
      };
      if (mounted) setState(() => _data = data);
    } on EarningsException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'تعذر تحميل بيانات الأرباح، حاول مجدداً');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onTabChanged(EarningsTab tab) {
    if (tab == _currentTab) return;
    setState(() => _currentTab = tab);
    _fetchData();
  }

  // ══════════════════════════════════════════════════════
  // Build
  // ══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('الأرباح'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Tab selector
            _buildTabSelector(),
            const SizedBox(height: 8),
            // Content
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF7ED957),
                      ),
                    )
                  : _error != null
                  ? _buildError(_error!)
                  : _data == null
                  ? const Center(
                      child: Text(
                        'لا توجد بيانات',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    )
                  : _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab selector ─────────────────────────────────────

  Widget _buildTabSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            _tabItem(EarningsTab.monthly, 'شهري'),
            _tabItem(EarningsTab.weekly, 'أسبوعي'),
            _tabItem(EarningsTab.daily, 'يومي'),
          ],
        ),
      ),
    );
  }

  Widget _tabItem(EarningsTab tab, String label) {
    final isSelected = _currentTab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabChanged(tab),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF7ED957) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Error state ──────────────────────────────────────

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _fetchData,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7ED957),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Content (data available) ─────────────────────────

  Widget _buildContent() {
    final d = _data!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        children: [
          _buildEarningsHeader(d),
          const SizedBox(height: 24),
          _buildChart(d),
          const SizedBox(height: 24),
          _buildStatsRow(d),
          const SizedBox(height: 20),
          _buildPeriodsList(d),
        ],
      ),
    );
  }

  // ── Earnings total header ────────────────────────────

  Widget _buildEarningsHeader(EarningsData d) {
    final formatted = d.totalAmount.toStringAsFixed(2);
    final suffix = _currentTab == EarningsTab.daily
        ? 'أرباح اليوم'
        : _currentTab == EarningsTab.weekly
        ? 'أرباح هذا الأسبوع'
        : 'أرباح هذا الشهر';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A2A), Color(0xFF0D131E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF7ED957).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Text(
            '$formatted ج.م',
            style: const TextStyle(
              color: Color(0xFF7ED957),
              fontSize: 34,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            suffix,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ── Bar chart ────────────────────────────────────────

  Widget _buildChart(EarningsData d) {
    if (d.periods.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'لا توجد بيانات كافية',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      );
    }

    final maxY = d.periods.fold<double>(
      0,
      (m, p) => p.amount > m ? p.amount : m,
    );
    // Add a 20 % headroom so bars don't touch the top
    final ceiling = maxY > 0 ? maxY * 1.2 : 100.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 8, bottom: 16),
            child: Text(
              'تحليل الأرباح',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: ceiling,
                minY: 0,
                barGroups: List.generate(d.periods.length, (i) {
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: d.periods[i].amount,
                        color: const Color(0xFF7ED957),
                        width: _currentTab == EarningsTab.monthly ? 14 : 22,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                      ),
                    ],
                  );
                }),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= d.periods.length) {
                          return const SizedBox.shrink();
                        }
                        String label = d.periods[idx].label;
                        // Shorten labels for monthly view
                        if (_currentTab == EarningsTab.monthly &&
                            label.length > 4) {
                          label = label.substring(0, 4);
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            label,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: ceiling / 4,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(color: Colors.white10, strokeWidth: 1);
                  },
                ),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final period = d.periods[group.x];
                      return BarTooltipItem(
                        '${period.label}\n${period.amount.toStringAsFixed(0)} ج.م',
                        const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Statistics row ───────────────────────────────────

  Widget _buildStatsRow(EarningsData d) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem(Icons.trip_origin, '${d.totalTrips}', 'عدد الرحلات'),
          _divider(),
          _statItem(
            Icons.straighten,
            '${d.totalDistanceKm.toStringAsFixed(0)} كم',
            'المسافة',
          ),
          _divider(),
          _statItem(
            Icons.attach_money,
            '${d.averagePerTrip.toStringAsFixed(2)} ج.م',
            'متوسط الرحلة',
          ),
        ],
      ),
    );
  }

  Widget _statItem(IconData icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFF7ED957), size: 22),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
      ],
    );
  }

  Widget _divider() {
    return Container(width: 1, height: 48, color: Colors.white10);
  }

  // ── Periods detail list ──────────────────────────────

  Widget _buildPeriodsList(EarningsData d) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 4, bottom: 12),
            child: Text(
              'تفاصيل الأرباح',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ...d.periods.asMap().entries.map((entry) {
            final i = entry.key;
            final p = entry.value;
            final isLast = i == d.periods.length - 1;
            return Column(
              children: [
                Row(
                  children: [
                    // Color indicator
                    Container(
                      width: 4,
                      height: 32,
                      decoration: BoxDecoration(
                        color: p.amount > 0
                            ? const Color(0xFF7ED957)
                            : Colors.white12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Label
                    Expanded(
                      child: Text(
                        p.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    // Trips badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${p.tripCount} رحلات',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Amount
                    Text(
                      '${p.amount.toStringAsFixed(0)} ج.م',
                      style: const TextStyle(
                        color: Color(0xFF7ED957),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (!isLast)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(height: 1, color: Colors.white10),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}
