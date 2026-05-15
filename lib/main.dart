import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

import 'weather_animation.dart';
import 'weather_service.dart';

// ── WSD brand palette (light-theme) ──────────────────────────────────────────
const kWsdCyan  = Color(0xFF00838F);
const kWsdBlue  = Color(0xFF1565C0);
const kWsdRed   = Color(0xFFC62828);
const kWsdGreen = Color(0xFF2E7D32);

const kPageBg   = Color(0xFFF0F4FB);
const kPrimary  = Color(0xFF0F172A);
const kSecond   = Color(0xFF64748B);
const kTertiary = Color(0xFF94A3B8);

// ── Entry point ───────────────────────────────────────────────────────────────
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  tz_data.initializeTimeZones();
  runApp(const WSDClockApp());
}

// ── City data ─────────────────────────────────────────────────────────────────
class CityData {
  final String name;
  final String country;
  final String timezone;
  final String flag;
  final Color accent;
  final double lat;
  final double lon;

  const CityData({
    required this.name,
    required this.country,
    required this.timezone,
    required this.flag,
    required this.accent,
    required this.lat,
    required this.lon,
  });
}

const List<CityData> kCities = [
  CityData(
    name: 'Dhaka',
    country: 'Bangladesh',
    timezone: 'Asia/Dhaka',
    flag: '🇧🇩',
    accent: kWsdCyan,
    lat: 23.7104,
    lon: 90.4074,
  ),
  CityData(
    name: 'London',
    country: 'United Kingdom',
    timezone: 'Europe/London',
    flag: '🇬🇧',
    accent: kWsdBlue,
    lat: 51.5074,
    lon: -0.1278,
  ),
  CityData(
    name: 'Frankfurt',
    country: 'Germany',
    timezone: 'Europe/Berlin',
    flag: '🇩🇪',
    accent: kWsdRed,
    lat: 50.1109,
    lon: 8.6821,
  ),
  CityData(
    name: 'São Paulo',
    country: 'Brazil',
    timezone: 'America/Sao_Paulo',
    flag: '🇧🇷',
    accent: kWsdGreen,
    lat: -23.5505,
    lon: -46.6333,
  ),
  CityData(
    name: 'Jakarta',
    country: 'Indonesia',
    timezone: 'Asia/Jakarta',
    flag: '🇮🇩',
    accent: Color(0xFF00695C),
    lat: -6.2088,
    lon: 106.8456,
  ),
  CityData(
    name: 'Hong Kong',
    country: 'China SAR',
    timezone: 'Asia/Hong_Kong',
    flag: '🇭🇰',
    accent: Color(0xFF3949AB),
    lat: 22.3193,
    lon: 114.1694,
  ),
];

// ── App root ──────────────────────────────────────────────────────────────────
class WSDClockApp extends StatelessWidget {
  const WSDClockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WSD Group — World Time',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: kWsdCyan,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: kPageBg,
        useMaterial3: true,
      ),
      home: const ClockPage(),
    );
  }
}

// ── Main page ─────────────────────────────────────────────────────────────────
class ClockPage extends StatefulWidget {
  const ClockPage({super.key});

  @override
  State<ClockPage> createState() => _ClockPageState();
}

class _ClockPageState extends State<ClockPage>
    with SingleTickerProviderStateMixin {
  late Timer _clockTimer;
  late Timer _weatherTimer;
  late AnimationController _liveDot;

  bool _colonVisible = true;
  bool _weatherLoaded = false;
  final Map<String, WeatherData?> _weather = {};

  @override
  void initState() {
    super.initState();

    _liveDot = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _clockTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() => _colonVisible = !_colonVisible),
    );

    _fetchWeather();

    _weatherTimer = Timer.periodic(
      const Duration(minutes: 10),
      (_) => _fetchWeather(),
    );
  }

  Future<void> _fetchWeather() async {
    final results = await Future.wait(
      kCities.map((c) => WeatherService.fetch(c.lat, c.lon, c.timezone)),
    );
    if (!mounted) return;
    setState(() {
      _weatherLoaded = true;
      for (var i = 0; i < kCities.length; i++) {
        _weather[kCities[i].timezone] = results[i];
      }
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _weatherTimer.cancel();
    _liveDot.dispose();
    super.dispose();
  }

  // ── UTC offset ──────────────────────────────────────────────────────────────
  String _utcOffset(String tzName) {
    final loc = tz.getLocation(tzName);
    final now = tz.TZDateTime.now(loc);
    final mins = now.timeZoneOffset.inMinutes;
    final sign = mins >= 0 ? '+' : '-';
    final h = mins.abs() ~/ 60;
    final m = mins.abs() % 60;
    return m == 0
        ? 'UTC$sign$h'
        : 'UTC$sign$h:${m.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPageBg,
      body: SafeArea(
        child: Column(
          children: [
            _WSDHeader(liveDot: _liveDot),
            Expanded(child: _buildGrid()),
            _Footer(),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid() {
    return LayoutBuilder(builder: (ctx, constraints) {
      final w = constraints.maxWidth;
      final cols = w > 1100 ? 3 : w > 660 ? 2 : 1;
      final ratio = cols == 3 ? 0.92 : cols == 2 ? 1.05 : 0.88;
      final pad = w > 660 ? 22.0 : 12.0;

      return GridView.builder(
        padding: EdgeInsets.fromLTRB(pad, 8, pad, 16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          childAspectRatio: ratio,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemCount: kCities.length,
        itemBuilder: (_, i) {
          final city = kCities[i];
          return ClockCard(
            city: city,
            colonVisible: _colonVisible,
            utcOffset: _utcOffset(city.timezone),
            weather: _weather[city.timezone],
            weatherLoading: !_weatherLoaded,
            liveDot: _liveDot,
          );
        },
      );
    });
  }
}

// ── Header ────────────────────────────────────────────────────────────────────
class _WSDHeader extends StatelessWidget {
  final AnimationController liveDot;

  const _WSDHeader({required this.liveDot});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // WSD official SVG logo
              SvgPicture.asset(
                'assets/wsd_logo.svg',
                height: 30,
                colorFilter: const ColorFilter.mode(
                  Color(0xFF001F3F),
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 14),
              _verticalDivider(),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GROUP',
                    style: GoogleFonts.orbitron(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: kPrimary,
                      letterSpacing: 5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      AnimatedBuilder(
                        animation: liveDot,
                        builder: (_, __) => Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: kWsdGreen
                                .withOpacity(0.45 + liveDot.value * 0.55),
                            boxShadow: [
                              BoxShadow(
                                color: kWsdGreen
                                    .withOpacity(liveDot.value * 0.45),
                                blurRadius: 7,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Text(
                        'LIVE WORLD TIME & WEATHER',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: kSecond,
                          letterSpacing: 2.2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          _quote(),
          const SizedBox(height: 12),
          _divider(),
        ],
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(width: 1, height: 36, color: const Color(0xFFE2E8F0));
  }

  Widget _quote() {
    return RichText(
      text: TextSpan(
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.3,
        ),
        children: const [
          TextSpan(text: 'Innovate', style: TextStyle(color: kWsdCyan)),
          TextSpan(
            text: '  ●  ',
            style: TextStyle(
              color: kWsdBlue,
              fontSize: 8,
              fontWeight: FontWeight.w900,
            ),
          ),
          TextSpan(text: 'Collaborate', style: TextStyle(color: kWsdGreen)),
          TextSpan(
            text: '  ●  ',
            style: TextStyle(
              color: kWsdRed,
              fontSize: 8,
              fontWeight: FontWeight.w900,
            ),
          ),
          TextSpan(text: 'Excellence', style: TextStyle(color: kPrimary)),
          TextSpan(
            text: '!',
            style: TextStyle(color: kWsdRed, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      height: 3,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [kWsdCyan, kWsdBlue, kWsdGreen, kWsdRed],
        ),
      ),
    );
  }
}

// ── Footer ────────────────────────────────────────────────────────────────────
class _Footer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: GoogleFonts.inter(
            fontSize: 10.5,
            color: kTertiary,
            letterSpacing: 0.3,
          ),
          children: [
            TextSpan(text: '© ${DateTime.now().year} '),
            const TextSpan(
              text: 'WSD Group',
              style: TextStyle(color: kWsdCyan, fontWeight: FontWeight.w600),
            ),
            const TextSpan(text: '  ·  All Rights Reserved'),
          ],
        ),
      ),
    );
  }
}

// ── Clock card ────────────────────────────────────────────────────────────────
class ClockCard extends StatelessWidget {
  final CityData city;
  final bool colonVisible;
  final String utcOffset;
  final WeatherData? weather;
  final bool weatherLoading;
  final AnimationController liveDot;

  const ClockCard({
    super.key,
    required this.city,
    required this.colonVisible,
    required this.utcOffset,
    required this.weather,
    required this.weatherLoading,
    required this.liveDot,
  });

  @override
  Widget build(BuildContext context) {
    final loc = tz.getLocation(city.timezone);
    final now = tz.TZDateTime.now(loc);
    final hour = DateFormat('HH').format(now);
    final minute = DateFormat('mm').format(now);
    final second = DateFormat('ss').format(now);
    final dateStr = DateFormat('EEEE, dd MMMM yyyy').format(now);
    final secFrac = now.second / 59.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: city.accent.withOpacity(0.10),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Colored accent bar
            Container(height: 4, color: city.accent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 11, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _cityRow(),
                    const SizedBox(height: 5),
                    _timeRow(hour, minute, second),
                    const SizedBox(height: 8),
                    Expanded(child: _weatherSection()),
                    const SizedBox(height: 8),
                    _bottomRow(dateStr, secFrac),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── City header ─────────────────────────────────────────────────────────
  Widget _cityRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(city.flag, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 9),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  city.name,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: kPrimary,
                  ),
                ),
                Text(
                  city.country,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: kTertiary,
                  ),
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            AnimatedBuilder(
              animation: liveDot,
              builder: (_, __) => Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 7),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: city.accent.withOpacity(0.45 + liveDot.value * 0.55),
                  boxShadow: [
                    BoxShadow(
                      color: city.accent.withOpacity(liveDot.value * 0.45),
                      blurRadius: 7,
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: city.accent.withOpacity(0.09),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: city.accent.withOpacity(0.28)),
              ),
              child: Text(
                utcOffset,
                style: GoogleFonts.orbitron(
                  fontSize: 8,
                  color: city.accent,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Digital time ────────────────────────────────────────────────────────
  Widget _timeRow(String hour, String minute, String second) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _digit(hour),
        _colon(),
        _digit(minute),
        const SizedBox(width: 5),
        Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Text(
            second,
            style: GoogleFonts.orbitron(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: city.accent.withOpacity(0.5),
              letterSpacing: 1,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _digit(String v) => Text(
        v,
        style: GoogleFonts.orbitron(
          fontSize: 38,
          fontWeight: FontWeight.w900,
          color: city.accent,
          letterSpacing: 2,
          height: 1,
        ),
      );

  Widget _colon() => Padding(
        padding: const EdgeInsets.only(bottom: 3, left: 2, right: 2),
        child: AnimatedOpacity(
          opacity: colonVisible ? 1.0 : 0.08,
          duration: const Duration(milliseconds: 250),
          child: Text(
            ':',
            style: GoogleFonts.orbitron(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: city.accent,
              height: 1,
            ),
          ),
        ),
      );

  // ── Weather section (fills remaining space) ──────────────────────────────
  Widget _weatherSection() {
    if (weatherLoading || weather == null) {
      return _loadingPlaceholder();
    }
    return _weatherContent(weather!);
  }

  Widget _loadingPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: city.accent.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: city.accent.withOpacity(0.12)),
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: city.accent.withOpacity(0.4),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Fetching weather…',
              style: GoogleFonts.inter(fontSize: 12, color: kTertiary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _weatherContent(WeatherData w) {
    return Column(
      children: [
        // Current weather panel
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: city.accent.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: city.accent.withOpacity(0.13)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              WeatherAnimation(iconCode: w.iconCode, size: 68),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${w.tempC.round()}°',
                          style: GoogleFonts.inter(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: city.accent,
                            height: 1,
                          ),
                        ),
                        Text(
                          'C',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: kSecond,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _cap(w.description),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: kSecond,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Feels ${w.feelsLikeC.round()}°  ·  H:${w.highTempC.round()}°  L:${w.lowTempC.round()}°',
                      style: GoogleFonts.inter(
                        fontSize: 9.5,
                        color: kTertiary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 5,
                      children: [
                        _chip('💧 ${w.humidity}%'),
                        _chip('🌬️ ${w.windKmh.round()} km/h'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Forecast strip
        if (w.forecast.isNotEmpty) ...[
          const SizedBox(height: 7),
          Row(
            children: w.forecast
                .map(
                  (d) => Expanded(
                    child: _ForecastCell(day: d, accent: city.accent),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: city.accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 9,
          color: kSecond,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ── Date + seconds progress bar ──────────────────────────────────────────
  Widget _bottomRow(String dateStr, double secFrac) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          dateStr,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: kTertiary,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 4),
        Stack(
          children: [
            Container(
              height: 3,
              decoration: BoxDecoration(
                color: city.accent.withOpacity(0.10),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            FractionallySizedBox(
              widthFactor: secFrac,
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [city.accent.withOpacity(0.4), city.accent],
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

  String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ── Forecast cell ─────────────────────────────────────────────────────────────
class _ForecastCell extends StatelessWidget {
  final DayForecast day;
  final Color accent;

  const _ForecastCell({required this.day, required this.accent});

  @override
  Widget build(BuildContext context) {
    final emoji = WeatherService.iconToEmoji(day.iconCode);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.06),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: accent.withOpacity(0.14)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            day.dayLabel.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              color: kSecond,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 3),
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 2),
          Text(
            '${day.maxTemp.round()}°',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          Text(
            '${day.minTemp.round()}°',
            style: GoogleFonts.inter(
              fontSize: 9.5,
              color: kTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
