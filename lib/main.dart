import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

import 'weather_animation.dart';
import 'weather_service.dart';

// ── WSD brand palette ─────────────────────────────────────────────────────────
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

  // Non-scrollable grid: fills available height exactly with Expanded rows/cols.
  Widget _buildGrid() {
    return LayoutBuilder(builder: (ctx, constraints) {
      final w = constraints.maxWidth;
      final cols = w > 1100 ? 3 : w > 600 ? 2 : 1;
      final rows = (kCities.length / cols).ceil();
      final pad = w > 660 ? 14.0 : 8.0;
      const gap = 10.0;

      return Padding(
        padding: EdgeInsets.fromLTRB(pad, 8, pad, 10),
        child: Column(
          children: List.generate(rows, (rowIdx) {
            final start = rowIdx * cols;
            final end = (start + cols).clamp(0, kCities.length);
            final rowItems = kCities.sublist(start, end);

            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: rowIdx > 0 ? gap : 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (int i = 0; i < rowItems.length; i++) ...[
                      if (i > 0) const SizedBox(width: gap),
                      Expanded(
                        child: ClockCard(
                          city: rowItems[i],
                          colonVisible: _colonVisible,
                          utcOffset: _utcOffset(rowItems[i].timezone),
                          weather: _weather[rowItems[i].timezone],
                          weatherLoading: !_weatherLoaded,
                          weatherError: _weatherLoaded &&
                                  _weather[rowItems[i].timezone] == null
                              ? WeatherService.errorFor(
                                  rowItems[i].lat, rowItems[i].lon)
                              : '',
                          onRetry: _fetchWeather,
                          liveDot: _liveDot,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ),
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
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SvgPicture.asset(
                'assets/wsd_logo.svg',
                height: 26,
                colorFilter: const ColorFilter.mode(
                  Color(0xFF001F3F),
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 12),
              _verticalDivider(),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GROUP',
                    style: GoogleFonts.orbitron(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: kPrimary,
                      letterSpacing: 5,
                    ),
                  ),
                  const SizedBox(height: 2),
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
                          fontSize: 8.5,
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
          const SizedBox(height: 8),
          _quote(),
          const SizedBox(height: 8),
          _divider(),
        ],
      ),
    );
  }

  Widget _verticalDivider() =>
      Container(width: 1, height: 32, color: const Color(0xFFE2E8F0));

  Widget _quote() {
    return RichText(
      text: TextSpan(
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.3,
        ),
        children: const [
          TextSpan(text: 'Innovate', style: TextStyle(color: kWsdCyan)),
          TextSpan(
            text: '  ●  ',
            style: TextStyle(color: kWsdBlue, fontSize: 7, fontWeight: FontWeight.w900),
          ),
          TextSpan(text: 'Collaborate', style: TextStyle(color: kWsdGreen)),
          TextSpan(
            text: '  ●  ',
            style: TextStyle(color: kWsdRed, fontSize: 7, fontWeight: FontWeight.w900),
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
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: GoogleFonts.inter(fontSize: 10, color: kTertiary, letterSpacing: 0.3),
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
  final String weatherError;
  final VoidCallback onRetry;
  final AnimationController liveDot;

  const ClockCard({
    super.key,
    required this.city,
    required this.colonVisible,
    required this.utcOffset,
    required this.weather,
    required this.weatherLoading,
    required this.weatherError,
    required this.onRetry,
    required this.liveDot,
  });

  @override
  Widget build(BuildContext context) {
    final loc = tz.getLocation(city.timezone);
    final now = tz.TZDateTime.now(loc);
    final hour   = DateFormat('HH').format(now);
    final minute = DateFormat('mm').format(now);
    final second = DateFormat('ss').format(now);
    final dateStr = DateFormat('EEE, dd MMM yyyy').format(now);
    final secFrac = now.second / 59.0;

    return LayoutBuilder(builder: (ctx, constraints) {
      // Scale content based on available card height
      final h = constraints.maxHeight;
      final xs = h < 200;       // extra small
      final sm = h < 260;       // small
      final md = h < 340;       // medium (no forecast strip)

      final vPad  = xs ? 5.0 : sm ? 7.0 : 10.0;
      final hPad  = xs ? 10.0 : sm ? 12.0 : 14.0;
      final gap1  = xs ? 2.0 : sm ? 3.0 : 4.0;   // after city row
      final gap2  = xs ? 3.0 : sm ? 5.0 : 6.0;   // after time row
      final gap3  = xs ? 3.0 : sm ? 4.0 : 6.0;   // after weather

      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: city.accent.withOpacity(0.10),
              blurRadius: 16,
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
          borderRadius: BorderRadius.circular(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(height: 3, color: city.accent),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(hPad, vPad, hPad, vPad),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _cityRow(xs, sm),
                      SizedBox(height: gap1),
                      _timeRow(hour, minute, second, xs, sm),
                      SizedBox(height: gap2),
                      Expanded(child: _weatherSection(sm, md)),
                      SizedBox(height: gap3),
                      _bottomRow(dateStr, secFrac, xs),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  // ── City header ──────────────────────────────────────────────────────────
  Widget _cityRow(bool xs, bool sm) {
    final flagSz = xs ? 16.0 : sm ? 18.0 : 20.0;
    final nameSz = xs ? 11.0 : sm ? 12.0 : 13.0;
    final ctrySz = xs ? 8.5 : sm ? 9.0 : 9.5;
    final badgeSz = xs ? 7.0 : 7.5;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(city.flag, style: TextStyle(fontSize: flagSz)),
            SizedBox(width: xs ? 6 : 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  city.name,
                  style: GoogleFonts.inter(
                    fontSize: nameSz,
                    fontWeight: FontWeight.w700,
                    color: kPrimary,
                  ),
                ),
                Text(
                  city.country,
                  style: GoogleFonts.inter(fontSize: ctrySz, color: kTertiary),
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
                width: 5,
                height: 5,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: city.accent.withOpacity(0.45 + liveDot.value * 0.55),
                  boxShadow: [
                    BoxShadow(
                      color: city.accent.withOpacity(liveDot.value * 0.45),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: xs ? 5 : 7,
                vertical: xs ? 2 : 3,
              ),
              decoration: BoxDecoration(
                color: city.accent.withOpacity(0.09),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: city.accent.withOpacity(0.28)),
              ),
              child: Text(
                utcOffset,
                style: GoogleFonts.orbitron(
                  fontSize: badgeSz,
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

  // ── Digital time ─────────────────────────────────────────────────────────
  Widget _timeRow(String hour, String minute, String second, bool xs, bool sm) {
    final digitSz = xs ? 24.0 : sm ? 28.0 : 34.0;
    final colonSz = xs ? 18.0 : sm ? 22.0 : 26.0;
    final secSz   = xs ? 10.0 : sm ? 11.0 : 13.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _digit(hour, digitSz),
        _colon(colonSz),
        _digit(minute, digitSz),
        const SizedBox(width: 4),
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(
            second,
            style: GoogleFonts.orbitron(
              fontSize: secSz,
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

  Widget _digit(String v, double sz) => Text(
        v,
        style: GoogleFonts.orbitron(
          fontSize: sz,
          fontWeight: FontWeight.w900,
          color: city.accent,
          letterSpacing: 2,
          height: 1,
        ),
      );

  Widget _colon(double sz) => Padding(
        padding: const EdgeInsets.only(bottom: 2, left: 2, right: 2),
        child: AnimatedOpacity(
          opacity: colonVisible ? 1.0 : 0.08,
          duration: const Duration(milliseconds: 250),
          child: Text(
            ':',
            style: GoogleFonts.orbitron(
              fontSize: sz,
              fontWeight: FontWeight.w900,
              color: city.accent,
              height: 1,
            ),
          ),
        ),
      );

  // ── Weather section ───────────────────────────────────────────────────────
  Widget _weatherSection(bool sm, bool md) {
    if (weatherLoading) return _loadingPlaceholder();
    if (weather == null) return _errorPlaceholder();
    return _weatherContent(weather!, showForecast: !md);
  }

  Widget _loadingPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: city.accent.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: city.accent.withOpacity(0.12)),
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: city.accent.withOpacity(0.4),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Fetching weather…',
              style: GoogleFonts.inter(fontSize: 11, color: kTertiary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorPlaceholder() {
    final hint = weatherError.length > 120
        ? '${weatherError.substring(0, 120)}…'
        : weatherError;
    return Container(
      decoration: BoxDecoration(
        color: kWsdRed.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kWsdRed.withOpacity(0.18)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_outlined, color: kWsdRed, size: 18),
          const SizedBox(height: 3),
          Text(
            'Weather unavailable',
            style: GoogleFonts.inter(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: kWsdRed,
            ),
          ),
          if (hint.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              hint,
              style: GoogleFonts.inter(fontSize: 8.5, color: kSecond),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 5),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: city.accent.withOpacity(0.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: city.accent.withOpacity(0.28)),
              ),
              child: Text(
                '↻  Retry',
                style: GoogleFonts.inter(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: city.accent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _weatherContent(WeatherData w, {required bool showForecast}) {
    return Column(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: city.accent.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: city.accent.withOpacity(0.13)),
            ),
            child: LayoutBuilder(builder: (ctx, bc) {
              final animSz = (bc.maxHeight * 0.65).clamp(32.0, 58.0);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  WeatherAnimation(iconCode: w.iconCode, size: animSz),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '${w.tempC.round()}°',
                              style: GoogleFonts.inter(
                                fontSize: (animSz * 0.42).clamp(16.0, 24.0),
                                fontWeight: FontWeight.w800,
                                color: city.accent,
                                height: 1,
                              ),
                            ),
                            Text(
                              'C',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: kSecond,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          _cap(w.description),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: kSecond,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Feels ${w.feelsLikeC.round()}°  ·  H:${w.highTempC.round()}°  L:${w.lowTempC.round()}°',
                          style: GoogleFonts.inter(fontSize: 9, color: kTertiary),
                        ),
                        const SizedBox(height: 3),
                        Wrap(
                          spacing: 4,
                          children: [
                            _chip('💧 ${w.humidity}%'),
                            _chip('🌬️ ${w.windKmh.round()} km/h'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
        if (showForecast && w.forecast.isNotEmpty) ...[
          const SizedBox(height: 5),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: w.forecast
                  .map((d) => Expanded(
                        child: _ForecastCell(day: d, accent: city.accent),
                      ))
                  .toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: city.accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 8.5,
          color: kSecond,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ── Date + seconds progress bar ───────────────────────────────────────────
  Widget _bottomRow(String dateStr, double secFrac, bool xs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          dateStr,
          style: GoogleFonts.inter(
            fontSize: xs ? 8.5 : 9.5,
            color: kTertiary,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 3),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withOpacity(0.14)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              day.dayLabel.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 7.5,
                fontWeight: FontWeight.w700,
                color: kSecond,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 2),
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 1),
            Text(
              '${day.maxTemp.round()}°',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
            Text(
              '${day.minTemp.round()}°',
              style: GoogleFonts.inter(fontSize: 8.5, color: kTertiary),
            ),
          ],
        ),
      ),
    );
  }
}
