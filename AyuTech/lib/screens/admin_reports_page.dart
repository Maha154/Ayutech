// lib/screens/admin_reports_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({Key? key}) : super(key: key);

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  static const Color sideGreen = Color(0xFF154E46);
  static const Color accentGold = Color(0xFFD6A657);
  static const Color pageBg = Color(0xFFF7F3EE);
  static const Color tileBg = Color(0xFFFFFFFF);
  static const Color lightTileBg = Color(0xFFF7F5EC);

  final TextEditingController _search = TextEditingController();

  // KPI sample
  final int totalAppointments = 3450;
  String get netProfit {
  final total = profit.reduce((a, b) => a + b);
  return '₹${(total / 1000).toStringAsFixed(1)}k';
}

  final String avgWait = '14 min';

  // sample charts data
  final List<int> booked = [42, 58, 45, 72, 63, 55, 35];
  final List<int> walkIn = [8, 14, 7, 18, 16, 18, 6];
List<double> revenue = List.filled(7, 0);
List<double> profit = List.filled(7, 0);
bool loadingCharts = true;


  @override
  Widget build(BuildContext context) {
    // tighter overall horizontal padding and narrower sidebar
    return Scaffold(
      backgroundColor: pageBg,
      body: SafeArea(
        child: Row(
          children: [
            // Sidebar (slightly narrower)
            Container(
              width: 240,
              color: sideGreen,
              child: Column(
                children: [
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14.0),
                    child: Row(children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.local_hospital, color: sideGreen),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                          Text('AyuTech', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                          SizedBox(height: 3),
                          Text('MEDICAL ADMIN', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)),
                        ]),
                      )
                    ]),
                  ),
                  const SizedBox(height: 24),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Align(alignment: Alignment.centerLeft, child: Text('MAIN', style: TextStyle(color: Colors.white.withOpacity(0.6), fontWeight: FontWeight.w700)))),
                  const SizedBox(height: 6),
                  _sideNavItem('Dashboard', Icons.dashboard_outlined),
                  _sideNavItem('Staffs', Icons.group_outlined),
                  _sideNavItem('Doctors', Icons.medical_services_outlined),
                  _sideNavItem('Billing & Patients', Icons.receipt_long_outlined),
                  const SizedBox(height: 14),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Align(alignment: Alignment.centerLeft, child: Text('REPORTS', style: TextStyle(color: Colors.white.withOpacity(0.6), fontWeight: FontWeight.w700)))),
                  const SizedBox(height: 6),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8), border: const Border(left: BorderSide(color: accentGold, width: 4))),
                    child: Row(children: const [
                      Icon(Icons.bar_chart, color: Colors.white70, size: 16),
                      SizedBox(width: 8),
                      Expanded(child: Text('Reports & Insights', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                    ]),
                  ),
                  const Spacer(),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0x15555555)))),
                    child: Row(children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
                        child: const CircleAvatar(radius: 20, backgroundColor: Colors.white, child: Icon(Icons.person, color: sideGreen)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                        Text('Dr. James Smith', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                        SizedBox(height: 3),
                        Text('Chief Resident', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      ])),
                    ]),
                  )
                ],
              ),
            ),

            // Main content (reduced horizontal padding)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Title row (smaller) with BACK button added
                    Row(children: [
                      // Back button (tries pop; if can't, pushes a named admin-home route)
                      Container(
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back),
                          tooltip: 'Back to Admin Home',
                          onPressed: () {
                            // prefer popping if there's history
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                              return;
                            }
                            // fallback: try navigating to a reasonable admin-home route name
                            // adjust route name below to your actual route if different.
                            Navigator.pushReplacementNamed(context, '/admin_homepage_all_in_one');
                          },
                        ),
                      ),

                      Container(
                        decoration: BoxDecoration(border: Border(left: BorderSide(color: sideGreen, width: 4))),
                        padding: const EdgeInsets.only(left: 10, top: 4, bottom: 4),
                        child: const Text('Reports & Insights', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                      ),
                      const Spacer(),
                      // narrower search field
                      SizedBox(
                        width: 300,
                        child: TextField(
                          controller: _search,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search),
                            hintText: 'Search...',
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                        child: IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.add),
                        label: const Text('+ New Appointment'),
                        style: ElevatedButton.styleFrom(backgroundColor: accentGold, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.download_outlined),
                        label: const Text('PDF'),
                        style: OutlinedButton.styleFrom(backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      ),
                    ]),
                    const SizedBox(height: 14),

                    // KPI row (more compact)
                    Row(
                      children: [
                        Expanded(
                          child: _kpiCardCompact(
                            title: 'Total Appointments',
                            valueWidget: Text(totalAppointments.toString(), style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.w900)),
                            color: sideGreen,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _kpiCardCompact(
                            title: 'Net Profit',
                            valueWidget: Text(netProfit, style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.w900)),
                            color: accentGold,
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 220,
                          child: _kpiCardCompact(
                            title: 'Avg. Wait Time',
                            valueWidget: Text(avgWait, style: const TextStyle(fontSize: 18, color: sideGreen, fontWeight: FontWeight.w900)),
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Charts row (reduced heights)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left: stacked bar (shorter)
                        Expanded(
                          flex: 3,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(color: lightTileBg, borderRadius: BorderRadius.circular(10)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Appointments: Booked vs Walk-in', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: sideGreen)),
                                const SizedBox(height: 8),
                                Row(children: [
                                  Row(children: const [CircleAvatar(radius: 5, backgroundColor: Color(0xFF2F6A5A)), SizedBox(width: 6), Text('Online/Call')]),
                                  const SizedBox(width: 12),
                                  Row(children: const [CircleAvatar(radius: 5, backgroundColor: Color(0xFFD6A657)), SizedBox(width: 6), Text('Walk-in')]),
                                ]),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 260, // reduced
                                  child: _buildStackedBarChart(),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(width: 14),

                        // Right: revenue/profit (reduced height)
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(color: lightTileBg, borderRadius: BorderRadius.circular(10)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Revenue vs Profit', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: sideGreen)),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 300, // reduced
                                  child: _buildRevenueAreaChart(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    // placeholder smaller
                    Container(
                      height: 100,
                      decoration: BoxDecoration(color: tileBg, borderRadius: BorderRadius.circular(10)),
                      child: const Center(child: Text('Additional content area (reports list, table, etc.)', style: TextStyle(color: Colors.black54))),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sideNavItem(String title, IconData icon, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(children: [
          Icon(icon, color: Colors.white70, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13))),
        ]),
      ),
    );
  }



Future<void> _loadRevenueProfit() async {
  final snap = await FirebaseFirestore.instance
      .collectionGroup('billings')
      .get();

  final now = DateTime.now();
  final Map<int, double> revenueMap = {};
  final Map<int, double> profitMap = {};

  for (final doc in snap.docs) {
    final data = doc.data();
    if (!data.containsKey('createdAt')) continue;

    final dt = (data['createdAt'] as Timestamp).toDate();
    if (dt.year != now.year) continue;

    final monthIndex = dt.month - 1; // Jan = 0

    final amount = (data['amount'] ?? data['total'] ?? 0).toDouble();
    final cost = (data['cost'] ?? 0).toDouble();

    revenueMap[monthIndex] =
        (revenueMap[monthIndex] ?? 0) + amount;

    profitMap[monthIndex] =
        (profitMap[monthIndex] ?? 0) + (amount - cost);
  }

  setState(() {
    revenue = List.generate(7, (i) => revenueMap[i] ?? 0);
    profit = List.generate(7, (i) => profitMap[i] ?? 0);
    loadingCharts = false;
  });
}


@override
void initState() {
  super.initState();
  _loadRevenueProfit();
}

  Widget _kpiCardCompact({required String title, required Widget valueWidget, required Color color}) {
    return Container(
      height: 88,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10), boxShadow: color == Colors.white ? null : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 6))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(color: color == Colors.white ? Colors.black54 : Colors.white70, fontWeight: FontWeight.w600, fontSize: 12)),
        const SizedBox(height: 8),
        valueWidget,
      ]),
    );
  }

  Widget _buildStackedBarChart() {
    final maxY = (booked + walkIn).reduce((a, b) => a > b ? a : b) + 20;
    return BarChart(
      BarChartData(
        maxY: maxY.toDouble(),
        alignment: BarChartAlignment.spaceAround,
        barGroups: List.generate(7, (i) {
          final bookedVal = booked[i].toDouble();
          final walkInVal = walkIn[i].toDouble();
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: bookedVal + walkInVal,
                width: 18,
                rodStackItems: [
                  BarChartRodStackItem(0, bookedVal, const Color(0xFF2F6A5A)),
                  BarChartRodStackItem(bookedVal, bookedVal + walkInVal, const Color(0xFFD6A657)),
                ],
                borderRadius: BorderRadius.circular(8),
              ),
            ],
          );
        }),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, getTitlesWidget: (value, meta) {
            const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
            final idx = value.toInt().clamp(0, 6);
            return Padding(padding: const EdgeInsets.only(top: 6.0), child: Text(labels[idx], style: const TextStyle(fontSize: 12)));
          })),
        ),
        gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 25, getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.withOpacity(0.12), strokeWidth: 1)),
        borderData: FlBorderData(show: false),
      ),
    );
  }

  Widget _buildRevenueAreaChart() {
    final spotsRevenue = <FlSpot>[];
    final spotsProfit = <FlSpot>[];
    for (var i = 0; i < revenue.length; i++) {
      spotsRevenue.add(FlSpot(i.toDouble(), revenue[i]));
      spotsProfit.add(FlSpot(i.toDouble(), profit[i]));
    }

    final maxY = (revenue.reduce((a, b) => a > b ? a : b) * 1.12);

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(show: true, horizontalInterval: maxY / 4, getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.withOpacity(0.12), strokeWidth: 1)),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) {
            const labels = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul'];
            final idx = value.toInt().clamp(0, labels.length - 1);
            return Padding(padding: const EdgeInsets.only(top: 6.0), child: Text(labels[idx], style: const TextStyle(fontSize: 11)));
          })),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spotsRevenue,
            isCurved: true,
            barWidth: 2.2,
            color: const Color(0xFF2F6A5A),
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: const Color(0xFF2F6A5A).withOpacity(0.08)),
          ),
          LineChartBarData(
            spots: spotsProfit,
            isCurved: true,
            barWidth: 2.6,
            color: const Color(0xFFD6A657),
            dotData: FlDotData(
              show: true,
              getDotPainter: (FlSpot spot, double percent, LineChartBarData bar, int index) {
                return FlDotCirclePainter(radius: 3.6, color: const Color(0xFFD6A657), strokeWidth: 0, strokeColor: Colors.transparent);
              },
            ),
            belowBarData: BarAreaData(show: false),
          ),
        ],
      ),
    );
  }
}
