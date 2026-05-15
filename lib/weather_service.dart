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

class WeatherService {
  // Compile-time key — CI/CD injects via --dart-define=WEATHER_API_KEY=xxx.
  // The defaultValue is the project key; CI/CD secret overrides it if provided.
  static const _compiledKey = String.fromEnvironment(
    'WEATHER_API_KEY',
    defaultValue: 'AIzaSyDnPdPmh_pu7-IsBflwMFeStUziPpZp2Xs',
  );

  // Runtime override (kept for programmatic use; not exposed in UI)
  static String _runtimeKey = '';

  static const _baseUrl = 'https://weather.googleapis.com/v1';

  static String get _apiKey =>
      _runtimeKey.isNotEmpty ? _runtimeKey : _compiledKey;

  static bool get hasApiKey => _apiKey.isNotEmpty;
  static String get currentKey => _apiKey;

  /// Called on startup (from SharedPreferences) and when user saves via dialog.
  static void setRuntimeKey(String key) {
    _runtimeKey = key.trim();
    _cache.clear();
  }

  static final Map<String, _CachedEntry> _cache = {};

  static Future<WeatherData?> fetch(
    double lat,
    double lon,
    String tzName,
  ) async {
    if (!hasApiKey) return null;

    final cacheKey = '${lat.toStringAsFixed(3)}_${lon.toStringAsFixed(3)}';
    final cached = _cache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt).inMinutes < 10) {
      return cached.data;
    }

    try {
      final params =
          'key=$_apiKey'
          '&location.latitude=$lat'
          '&location.longitude=$lon'
          '&unitsSystem=METRIC'
          '&languageCode=en';

      final results = await Future.wait([
        http
            .get(Uri.parse('$_baseUrl/currentConditions:lookup?$params'))
            .timeout(const Duration(seconds: 8)),
        http
            .get(Uri.parse('$_baseUrl/forecast/days:lookup?$params&days=5'))
            .timeout(const Duration(seconds: 8)),
      ]);

      final currentRes = results[0];
      final forecastRes = results[1];

      if (currentRes.statusCode != 200) return null;

      final cc = jsonDecode(currentRes.body) as Map<String, dynamic>;

      final temp = (cc['temperature'] as Map)['degrees'] as num;
      final feelsLike = (cc['feelsLikeTemperature'] as Map)['degrees'] as num;
      final humidity = (cc['relativeHumidity'] as num).toInt();
      final windSpeed =
          ((cc['wind'] as Map)['speed'] as Map)['value'] as num;
      final condition = cc['weatherCondition'] as Map<String, dynamic>;
      final condType = condition['type'] as String;
      final description = (condition['description'] as Map)['text'] as String;
      final isDaytime = cc['isDaytime'] as bool? ?? true;
      final iconCode = _conditionToIconCode(condType, isDaytime);

      // Today's high/low: prefer from forecast day 0, fall back to history
      double highT = temp.toDouble();
      double lowT = temp.toDouble();
      final history = cc['currentConditionsHistory'] as Map<String, dynamic>?;
      if (history != null) {
        highT = ((history['maxTemperature'] as Map)['degrees'] as num).toDouble();
        lowT = ((history['minTemperature'] as Map)['degrees'] as num).toDouble();
      }

      List<DayForecast> forecast = [];
      if (forecastRes.statusCode == 200) {
        final fj = jsonDecode(forecastRes.body) as Map<String, dynamic>;
        final days = fj['forecastDays'] as List;
        if (days.isNotEmpty) {
          final today = days[0] as Map<String, dynamic>;
          highT = ((today['maxTemperature'] as Map)['degrees'] as num).toDouble();
          lowT = ((today['minTemperature'] as Map)['degrees'] as num).toDouble();
        }
        forecast = _parseForecast(days);
      }

      final data = WeatherData(
        tempC: temp.toDouble(),
        feelsLikeC: feelsLike.toDouble(),
        description: description,
        iconCode: iconCode,
        humidity: humidity,
        windKmh: windSpeed.toDouble(),
        highTempC: highT,
        lowTempC: lowT,
        forecast: forecast,
      );
      _cache[cacheKey] = _CachedEntry(data, DateTime.now());
      return data;
    } catch (_) {}
    return null;
  }

  static List<DayForecast> _parseForecast(List<dynamic> days) {
    final forecasts = <DayForecast>[];
    // Skip index 0 (today), take up to next 4 days
    for (int i = 1; i < days.length && forecasts.length < 4; i++) {
      final day = days[i] as Map<String, dynamic>;

      final dd = day['displayDate'] as Map<String, dynamic>;
      final date = DateTime(
        (dd['year'] as num).toInt(),
        (dd['month'] as num).toInt(),
        (dd['day'] as num).toInt(),
      );

      final maxT = ((day['maxTemperature'] as Map)['degrees'] as num).toDouble();
      final minT = ((day['minTemperature'] as Map)['degrees'] as num).toDouble();

      // Prefer daytime condition for the icon
      final daytime = day['daytimeForecast'] as Map<String, dynamic>?;
      final night = day['nighttimeForecast'] as Map<String, dynamic>?;
      final condMap =
          (daytime ?? night)?['weatherCondition'] as Map<String, dynamic>?;
      final condType = condMap?['type'] as String? ?? 'CLEAR';

      forecasts.add(DayForecast(
        dayLabel: DateFormat('EEE').format(date),
        maxTemp: maxT,
        minTemp: minT,
        iconCode: _conditionToIconCode(condType, true),
      ));
    }
    return forecasts;
  }

  // Maps Google WeatherCondition enum strings to internal 2-digit icon codes
  static String _conditionToIconCode(String type, bool isDaytime) {
    final s = isDaytime ? 'd' : 'n';
    switch (type) {
      case 'CLEAR':
      case 'MOSTLY_CLEAR':
        return '01$s';
      case 'PARTLY_CLOUDY':
      case 'CHANCE_OF_SHOWERS':
      case 'CHANCE_OF_SNOW_SHOWERS':
        return '02$s';
      case 'MOSTLY_CLOUDY':
      case 'CLOUDY':
      case 'WINDY':
        return '03$s';
      case 'OVERCAST':
        return '04$s';
      case 'LIGHT_RAIN_SHOWERS':
      case 'SCATTERED_SHOWERS':
      case 'RAIN_SHOWERS':
      case 'HEAVY_RAIN_SHOWERS':
      case 'LIGHT_RAIN':
      case 'LIGHT_TO_MODERATE_RAIN':
        return '09$s';
      case 'RAIN':
      case 'MODERATE_TO_HEAVY_RAIN':
      case 'HEAVY_RAIN':
      case 'RAIN_PERIODICALLY_HEAVY':
      case 'WIND_AND_RAIN':
      case 'FREEZING_RAIN':
      case 'RAIN_AND_SNOW':
      case 'HAIL':
      case 'HAIL_SHOWERS':
        return '10$s';
      case 'THUNDERSTORM':
      case 'THUNDERSHOWER':
      case 'LIGHT_THUNDERSTORM_RAIN':
      case 'SCATTERED_THUNDERSTORMS':
      case 'HEAVY_THUNDERSTORM':
        return '11$s';
      case 'SNOW':
      case 'LIGHT_SNOW':
      case 'HEAVY_SNOW':
      case 'LIGHT_TO_MODERATE_SNOW':
      case 'MODERATE_TO_HEAVY_SNOW':
      case 'SNOW_PERIODICALLY_HEAVY':
      case 'HEAVY_SNOW_STORM':
      case 'SNOWSTORM':
      case 'LIGHT_SNOW_SHOWERS':
      case 'SCATTERED_SNOW_SHOWERS':
      case 'SNOW_SHOWERS':
      case 'HEAVY_SNOW_SHOWERS':
      case 'BLOWING_SNOW':
        return '13$s';
      case 'FOG':
      case 'HAZE':
      case 'SMOKE':
      case 'DUST':
      case 'SAND':
        return '50$s';
      default:
        return '01$s';
    }
  }

  static String iconToEmoji(String code) {
    if (code.length < 2) return '🌡️';
    switch (code.substring(0, 2)) {
      case '01':
        return '☀️';
      case '02':
        return '⛅';
      case '03':
        return '☁️';
      case '04':
        return '☁️';
      case '09':
        return '🌧️';
      case '10':
        return '🌦️';
      case '11':
        return '⛈️';
      case '13':
        return '❄️';
      case '50':
        return '🌫️';
      default:
        return '🌡️';
    }
  }
}

class _CachedEntry {
  final WeatherData data;
  final DateTime fetchedAt;
  _CachedEntry(this.data, this.fetchedAt);
}
