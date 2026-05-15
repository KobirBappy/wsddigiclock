import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

void main() {
  tz_data.initializeTimeZones();
  runApp(const WSDClockApp());
}

class CityData {
  final String name;
  final String country;
  final String timezone;
  final String flag;
  final Color accent;
  final Color accentDark;

  const CityData({
    required this.name,
    required this.country,
    required this.timezone,
    required this.flag,
    required this.accent,
    required this.accentDark,
  });
}

const List<CityData> kCities = [
  CityData(
    name: 'Dhaka',
    country: 'Bangladesh',
    timezone: 'Asia/Dhaka',
    flag: '🇧🇩',
    accent: Color(0xFF00E5CC),
    accentDark: Color(0xFF004D45),
  ),
  CityData(
    name: 'London',
    country: 'United Kingdom',
    timezone: 'Europe/London',
    flag: '🇬🇧',
    accent: Color(0xFF5B9CF6),
    accentDark: Color(0xFF1A2E52),
  ),
  CityData(
    name: 'Frankfurt',
    country: 'Germany',
    timezone: 'Europe/Berlin',
    flag: '🇩🇪',
    accent: Color(0xFFF97171),
    accentDark: Color(0xFF4D1E1E),
  ),
  CityData(
    name: 'São Paulo',
    country: 'Brazil',
    timezone: 'America/Sao_Paulo',
    flag: '🇧🇷',
    accent: Color(0xFF4EE59A),
    accentDark: Color(0xFF0D4028),
  ),
  CityData(
    name: 'Jakarta',
    country: 'Indonesia',
    timezone: 'Asia/Jakarta',
    flag: '🇮🇩',
    accent: Color(0xFFFFB347),
    accentDark: Color(0xFF4D3000),
  ),
  CityData(
    name: 'Hong Kong',
    country: 'China SAR',
    timezone: 'Asia/Hong_Kong',
    flag: '🇭🇰',
    accent: Color(0xFFC77DFF),
    accentDark: Color(0xFF3A1A5C),
  ),
];

class WSDClockApp extends StatelessWidget {
  const WSDClockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'WSD Group — World Time',
      debugShowCheckedModeBanner: false,
      home: ClockPage(),
    );
  }
}

class ClockPage extends StatefulWidget {
  const ClockPage({super.key});

  @override
  State<ClockPage> createState() => _ClockPageState();
}

class _ClockPageState extends State<ClockPage>
    with SingleTickerProviderStateMixin {
  late Timer _timer;
  late AnimationController _dotController;
  bool _colonVisible = true;

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _colonVisible = !_colonVisible);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _dotController.dispose();
    super.dispose();
  }

  String _utcOffset(String tzName) {
    final loc = tz.getLocation(tzName);
    final now = tz.TZDateTime.now(loc);
    final mins = now.timeZoneOffset.inMinutes;
    final sign = mins >= 0 ? '+' : '-';
    final h = mins.abs() ~/ 60;
    final m = mins.abs() % 60;
    return m == 0 ? 'UTC$sign$h' : 'UTC$sign$h:${m.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060C1C),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.6),
            radius: 1.4,
            colors: [
              Color(0xFF0E1B35),
              Color(0xFF060C1C),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _WSDHeader(dotController: _dotController),
              Expanded(
                child: _buildGrid(),
              ),
              _Footer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final cols = w > 1100 ? 3 : w > 660 ? 2 : 1;
        final ratio = cols == 3 ? 1.55 : cols == 2 ? 1.65 : 2.4;

        return GridView.builder(
          padding: EdgeInsets.fromLTRB(
            w > 660 ? 24 : 16,
            4,
            w > 660 ? 24 : 16,
            16,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            childAspectRatio: ratio,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: kCities.length,
          itemBuilder: (_, i) => ClockCard(
            city: kCities[i],
            colonVisible: _colonVisible,
            utcOffset: _utcOffset(kCities[i].timezone),
            dotController: _dotController,
          ),
        );
      },
    );
  }
}

class _WSDHeader extends StatelessWidget {
  final AnimationController dotController;

  const _WSDHeader({required this.dotController});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildLogoBadge(),
              const SizedBox(width: 22),
              _buildTitles(),
            ],
          ),
          const SizedBox(height: 22),
          _buildDivider(),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildLogoBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00E5CC), width: 2.0),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF00E5CC).withOpacity(0.18),
            const Color(0xFF00E5CC).withOpacity(0.04),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5CC).withOpacity(0.25),
            blurRadius: 28,
            spreadRadius: -6,
          ),
        ],
      ),
      child: Text(
        'WSD',
        style: GoogleFonts.orbitron(
          fontSize: 32,
          fontWeight: FontWeight.w900,
          color: const Color(0xFF00E5CC),
          letterSpacing: 10,
        ),
      ),
    );
  }

  Widget _buildTitles() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'GROUP',
          style: GoogleFonts.orbitron(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 7,
          ),
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            AnimatedBuilder(
              animation: dotController,
              builder: (_, __) => Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 7),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF00E5CC).withOpacity(
                    0.4 + dotController.value * 0.6,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E5CC).withOpacity(
                        dotController.value * 0.5,
                      ),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
            Text(
              'LIVE WORLD TIME DASHBOARD',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Colors.white38,
                letterSpacing: 3,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            const Color(0xFF00E5CC).withOpacity(0.7),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        '© ${DateTime.now().year} WSD Group  ·  Powered by Real-Time World Clock',
        style: GoogleFonts.inter(
          fontSize: 11,
          color: Colors.white24,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class ClockCard extends StatelessWidget {
  final CityData city;
  final bool colonVisible;
  final String utcOffset;
  final AnimationController dotController;

  const ClockCard({
    super.key,
    required this.city,
    required this.colonVisible,
    required this.utcOffset,
    required this.dotController,
  });

  @override
  Widget build(BuildContext context) {
    final loc = tz.getLocation(city.timezone);
    final now = tz.TZDateTime.now(loc);
    final hour = DateFormat('HH').format(now);
    final minute = DateFormat('mm').format(now);
    final second = DateFormat('ss').format(now);
    final date = DateFormat('EEEE, dd MMM yyyy').format(now);
    final secProgress = now.second / 59.0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            city.accent.withOpacity(0.07),
            const Color(0xFF060C1C).withOpacity(0.95),
          ],
        ),
        border: Border.all(
          color: city.accent.withOpacity(0.2),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: city.accent.withOpacity(0.09),
            blurRadius: 32,
            spreadRadius: -8,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Subtle glow blob in top-right corner
            Positioned(
              top: -40,
              right: -40,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      city.accent.withOpacity(0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildTopRow(),
                  _buildTimeRow(hour, minute, second),
                  _buildBottomRow(date, secProgress),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(city.flag, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  city.name,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  city.country,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.4),
                  ),
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            AnimatedBuilder(
              animation: dotController,
              builder: (_, __) => Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: city.accent.withOpacity(
                    0.5 + dotController.value * 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: city.accent.withOpacity(
                        dotController.value * 0.7,
                      ),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: city.accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: city.accent.withOpacity(0.28),
                ),
              ),
              child: Text(
                utcOffset,
                style: GoogleFonts.orbitron(
                  fontSize: 9,
                  color: city.accent,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeRow(String hour, String minute, String second) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _timeSegment(hour, 48),
        _colonWidget(48),
        _timeSegment(minute, 48),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            second,
            style: GoogleFonts.orbitron(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: city.accent.withOpacity(0.55),
              letterSpacing: 1,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _timeSegment(String value, double size) {
    return Text(
      value,
      style: GoogleFonts.orbitron(
        fontSize: size,
        fontWeight: FontWeight.w900,
        color: city.accent,
        letterSpacing: 2,
        height: 1,
      ),
    );
  }

  Widget _colonWidget(double size) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, left: 3, right: 3),
      child: AnimatedOpacity(
        opacity: colonVisible ? 1.0 : 0.12,
        duration: const Duration(milliseconds: 250),
        child: Text(
          ':',
          style: GoogleFonts.orbitron(
            fontSize: size - 8,
            fontWeight: FontWeight.w900,
            color: city.accent,
            height: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomRow(String date, double secProgress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          date,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            color: Colors.white.withOpacity(0.4),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 7),
        Stack(
          children: [
            Container(
              height: 2,
              decoration: BoxDecoration(
                color: city.accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            FractionallySizedBox(
              widthFactor: secProgress,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [city.accent.withOpacity(0.5), city.accent],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
