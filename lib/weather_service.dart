import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class DayForecast {
  final String dayLabel;
  final double maxTemp;
  final double minTemp;
  final String iconCode;

  const DayForecast({
    required this.dayLabel,
    required this.maxTemp,
    required this.minTemp,
    required this.iconCode,
  });
}

class WeatherData {
  final double tempC;
  final double feelsLikeC;
  final String description;
  final String iconCode;
  final int humidity;
  final double windKmh;
  final double highTempC;
  final double lowTempC;
  final List<DayForecast> forecast;

  const WeatherData({
    required this.tempC,
    required this.feelsLikeC,
    required this.description,
    required this.iconCode,
    required this.humidity,
    required this.windKmh,
    required this.highTempC,
    required this.lowTempC,
    required this.forecast,
  });
}

// Open-Meteo — free, no API key required.
// Docs: https://open-meteo.com/en/docs
class WeatherService {
  static const _baseUrl = 'https://api.open-meteo.com/v1/forecast';

  static bool get hasApiKey => true; // no key needed

  static final Map<String, _CachedEntry> _cache = {};
  static final Map<String, String> _errors = {};

  static String errorFor(double lat, double lon) {
    final key = '${lat.toStringAsFixed(3)}_${lon.toStringAsFixed(3)}';
    return _errors[key] ?? '';
  }

  static Future<WeatherData?> fetch(
    double lat,
    double lon,
    String tzName,
  ) async {
    final cacheKey = '${lat.toStringAsFixed(3)}_${lon.toStringAsFixed(3)}';
    final cached = _cache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt).inMinutes < 10) {
      return cached.data;
    }

    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'latitude': lat.toString(),
        'longitude': lon.toString(),
        'current': [
          'temperature_2m',
          'relative_humidity_2m',
          'apparent_temperature',
          'weather_code',
          'wind_speed_10m',
          'is_day',
        ].join(','),
        'daily': [
          'weather_code',
          'temperature_2m_max',
          'temperature_2m_min',
        ].join(','),
        'wind_speed_unit': 'kmh',
        'timezone': tzName,
        'forecast_days': '5',
      });

      final res = await http.get(uri).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        _errors[cacheKey] = 'HTTP ${res.statusCode} — ${res.body}';
        return null;
      }

      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final cur = j['current'] as Map<String, dynamic>;
      final daily = j['daily'] as Map<String, dynamic>;

      final tempC = (cur['temperature_2m'] as num).toDouble();
      final feelsLike = (cur['apparent_temperature'] as num).toDouble();
      final humidity = (cur['relative_humidity_2m'] as num).toInt();
      final windKmh = (cur['wind_speed_10m'] as num).toDouble();
      final wmoCode = (cur['weather_code'] as num).toInt();
      final isDay = (cur['is_day'] as num?)?.toInt() ?? 1;

      final iconCode = _wmoToIconCode(wmoCode, isDay == 1);
      final description = _wmoToDescription(wmoCode);

      final maxTemps = (daily['temperature_2m_max'] as List).cast<num>();
      final minTemps = (daily['temperature_2m_min'] as List).cast<num>();
      final wmoCodes = (daily['weather_code'] as List).cast<num>();
      final times = (daily['time'] as List).cast<String>();

      final highT = maxTemps.isNotEmpty ? maxTemps[0].toDouble() : tempC;
      final lowT = minTemps.isNotEmpty ? minTemps[0].toDouble() : tempC;

      final forecasts = <DayForecast>[];
      for (int i = 1; i < times.length && forecasts.length < 4; i++) {
        final date = DateTime.parse(times[i]);
        forecasts.add(DayForecast(
          dayLabel: DateFormat('EEE').format(date),
          maxTemp: maxTemps[i].toDouble(),
          minTemp: minTemps[i].toDouble(),
          iconCode: _wmoToIconCode(wmoCodes[i].toInt(), true),
        ));
      }

      final data = WeatherData(
        tempC: tempC,
        feelsLikeC: feelsLike,
        description: description,
        iconCode: iconCode,
        humidity: humidity,
        windKmh: windKmh,
        highTempC: highT,
        lowTempC: lowT,
        forecast: forecasts,
      );

      _cache[cacheKey] = _CachedEntry(data, DateTime.now());
      _errors.remove(cacheKey);
      return data;
    } catch (e) {
      _errors[cacheKey] = e.toString();
    }
    return null;
  }

  // WMO Weather Interpretation Codes → internal icon codes
  static String _wmoToIconCode(int code, bool isDay) {
    final s = isDay ? 'd' : 'n';
    if (code == 0) return '01$s';
    if (code <= 2) return '02$s';
    if (code == 3) return '04$s';
    if (code >= 45 && code <= 48) return '50$s'; // fog
    if (code >= 51 && code <= 55) return '09$s'; // drizzle
    if (code >= 56 && code <= 57) return '09$s'; // freezing drizzle
    if (code >= 61 && code <= 65) return '10$s'; // rain
    if (code >= 66 && code <= 67) return '10$s'; // freezing rain
    if (code >= 71 && code <= 77) return '13$s'; // snow
    if (code >= 80 && code <= 82) return '09$s'; // rain showers
    if (code == 85 || code == 86) return '13$s'; // snow showers
    if (code >= 95 && code <= 99) return '11$s'; // thunderstorm
    return '01$s';
  }

  // Human-readable description from WMO code
  static String _wmoToDescription(int code) {
    if (code == 0) return 'Clear sky';
    if (code == 1) return 'Mainly clear';
    if (code == 2) return 'Partly cloudy';
    if (code == 3) return 'Overcast';
    if (code == 45 || code == 48) return 'Foggy';
    if (code >= 51 && code <= 55) return 'Drizzle';
    if (code >= 56 && code <= 57) return 'Freezing drizzle';
    if (code == 61) return 'Slight rain';
    if (code == 63) return 'Moderate rain';
    if (code == 65) return 'Heavy rain';
    if (code >= 66 && code <= 67) return 'Freezing rain';
    if (code == 71) return 'Slight snow';
    if (code == 73) return 'Moderate snow';
    if (code == 75) return 'Heavy snow';
    if (code == 77) return 'Snow grains';
    if (code >= 80 && code <= 82) return 'Rain showers';
    if (code == 85 || code == 86) return 'Snow showers';
    if (code == 95) return 'Thunderstorm';
    if (code == 96 || code == 99) return 'Thunderstorm w/ hail';
    return 'Unknown';
  }

  static String iconToEmoji(String code) {
    if (code.length < 2) return '🌡️';
    switch (code.substring(0, 2)) {
      case '01': return '☀️';
      case '02': return '⛅';
      case '03': return '☁️';
      case '04': return '☁️';
      case '09': return '🌧️';
      case '10': return '🌦️';
      case '11': return '⛈️';
      case '13': return '❄️';
      case '50': return '🌫️';
      default:   return '🌡️';
    }
  }
}

class _CachedEntry {
  final WeatherData data;
  final DateTime fetchedAt;
  _CachedEntry(this.data, this.fetchedAt);
}
