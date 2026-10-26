import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<String> _pinnedCities = [
    'Patna',
    'Munger',
    'New Delhi',
    'Mumbai',
    'Bengaluru',
  ];

  String _activeQuery = 'Patna';
  bool _useFahrenheit = false;
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _weatherData;

  @override
  void initState() {
    super.initState();
    _fetchLiveWeather(_activeQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchLiveWeather(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return;

    final apiKey = (dotenv.env['WEATHER_API_KEY'] ?? '').trim();
    if (apiKey.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'WEATHER_API_KEY not found in .env file.\nPlease add WEATHER_API_KEY=your_key in your root .env file and restart the app.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final uri = Uri.https('api.weatherapi.com', '/v1/forecast.json', {
        'key': apiKey,
        'q': cleanQuery,
        'days': '3',
        'aqi': 'yes',
        'alerts': 'yes',
      });

      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      final Map<String, dynamic> body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        setState(() {
          _weatherData = body;
          _activeQuery = body['location']?['name']?.toString() ?? cleanQuery;
          _isLoading = false;
        });
      } else {
        final apiErr =
            body['error']?['message']?.toString() ??
            'Failed to load weather data (HTTP ${response.statusCode})';
        setState(() {
          _errorMessage = apiErr;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error while fetching live weather:\n$e';
        _isLoading = false;
      });
    }
  }

  void _togglePinCurrentCity() {
    if (_weatherData == null) return;
    final cityName =
        _weatherData!['location']?['name']?.toString() ?? _activeQuery;
    setState(() {
      if (_pinnedCities.contains(cityName)) {
        if (_pinnedCities.length > 1) _pinnedCities.remove(cityName);
      } else {
        _pinnedCities.insert(0, cityName);
      }
    });
  }

  String _formatTemp(num? c, num? f) {
    if (c == null || f == null) return '--';
    return _useFahrenheit ? '${f.round()}°F' : '${c.round()}°C';
  }

  String _formatDecimalTemp(num? c, num? f) {
    if (c == null || f == null) return '--';
    return _useFahrenheit
        ? '${f.toStringAsFixed(1)}°F'
        : '${c.toStringAsFixed(1)}°C';
  }

  String fixIconUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.isEmpty) return '';
    if (rawUrl.startsWith('//')) return 'https:$rawUrl';
    return rawUrl;
  }

  Map<String, dynamic> _epaMeta(int index) {
    switch (index) {
      case 1:
        return {
          'label': 'Good',
          'color': const Color(0xFF10B981),
          'advice': 'Air quality is clean & ideal for outdoor activities.',
        };
      case 2:
        return {
          'label': 'Moderate',
          'color': const Color(0xFFF59E0B),
          'advice': 'Acceptable air quality; sensitive individuals should limit prolonged exertion.',
        };
      case 3:
        return {
          'label': 'Sensitive Caution',
          'color': const Color(0xFFF97316),
          'advice':
              'Sensitive groups may experience minor breathing discomfort.',
        };
      case 4:
        return {
          'label': 'Unhealthy',
          'color': const Color(0xFFEF4444),
          'advice':
              'Avoid prolonged outdoor workouts; wear a mask if sensitive.',
        };
      case 5:
        return {
          'label': 'Very Unhealthy',
          'color': const Color(0xFF8B5CF6),
          'advice': 'Health alert: everyone should reduce outdoor exposure.',
        };
      case 6:
        return {
          'label': 'Hazardous',
          'color': const Color(0xFF7F1D1D),
          'advice':
              'Severe pollution warning: remain indoors as much as possible.',
        };
      default:
        return {
          'label': 'Unknown',
          'color': const Color(0xFF64748B),
          'advice': 'Real-time EPA index not reported for this station.',
        };
    }
  }

  String _uvCategory(num uv) {
    if (uv <= 2) return 'Low';
    if (uv <= 5) return 'Moderate';
    if (uv <= 7) return 'High';
    if (uv <= 10) return 'Very High';
    return 'Extreme';
  }

  String _smartAdvisory(
    Map<String, dynamic> current,
    Map<String, dynamic>? todayDay,
  ) {
    final rainChance =
        (todayDay?['daily_chance_of_rain'] as num?)?.toInt() ?? 0;
    final uv = (current['uv'] as num?)?.toDouble() ?? 0;
    final tempC = (current['temp_c'] as num?)?.toDouble() ?? 25;
    final windKph = (current['wind_kph'] as num?)?.toDouble() ?? 0;

    if (rainChance >= 60) {
      return '🌧️ $rainChance% chance of rain today — carry an umbrella before heading out.';
    }
    if (uv >= 7) {
      return '☀️ High UV Index ($uv) — apply sunscreen and wear sunglasses outdoors.';
    }
    if (tempC >= 36) {
      return '🔥 High heat ($tempC°C) — stay hydrated and avoid direct afternoon sun.';
    }
    if (tempC <= 12) {
      return '🧥 Chilly weather ($tempC°C) — layer up with warm clothing.';
    }
    if (windKph >= 30) {
      return '💨 Breezy conditions (${windKph.toStringAsFixed(1)} km/h winds) expected.';
    }
    return '✨ Pleasant atmospheric conditions right now — great weather for outdoor tasks.';
  }

  @override
  Widget build(BuildContext context) {
    final loc = _weatherData?['location'] as Map<String, dynamic>?;
    final current = _weatherData?['current'] as Map<String, dynamic>?;
    final forecastDays =
        (_weatherData?['forecast']?['forecastday'] as List?) ?? [];
    final alertsList = (_weatherData?['alerts']?['alert'] as List?) ?? [];

    final currentCityName = loc?['name']?.toString() ?? _activeQuery;
    final isCurrentPinned = _pinnedCities.contains(currentCityName);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: const Text(
          'Live Weather & AQI Studio',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 19,
            color: Color(0xFF0F172A),
          ),
        ),
        actions: [
          // Celsius / Fahrenheit Toggle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text(
                    '°C',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
                ButtonSegment(
                  value: true,
                  label: Text(
                    '°F',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
              selected: {_useFahrenheit},
              onSelectionChanged: (s) =>
                  setState(() => _useFahrenheit = s.first),
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
            ),
          ),
          IconButton(
            tooltip: isCurrentPinned ? 'Unpin City' : 'Pin Current City',
            icon: Icon(
              isCurrentPinned
                  ? Icons.push_pin_rounded
                  : Icons.push_pin_outlined,
              color: isCurrentPinned
                  ? const Color(0xFF4F46E5)
                  : const Color(0xFF64748B),
            ),
            onPressed: _togglePinCurrentCity,
          ),
          IconButton(
            tooltip: 'Refresh Live Data',
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0F172A)),
            onPressed: () => _fetchLiveWeather(_activeQuery),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: Column(
            children: [
              // ==========================================
              // 1. TOP SEARCH BAR & QUICK PINNED CITIES
              // ==========================================
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (val) {
                          if (val.trim().isNotEmpty) {
                            _fetchLiveWeather(val);
                            FocusScope.of(context).unfocus();
                          }
                        },
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search any city, pin code, or lat,lon (e.g. Patna, Munger, London)...',
                          hintStyle: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 13.5,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Color(0xFF4F46E5),
                          ),
                          suffixIcon: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                            ),
                            onPressed: () {
                              if (_searchController.text.trim().isNotEmpty) {
                                _fetchLiveWeather(_searchController.text);
                                FocusScope.of(context).unfocus();
                              }
                            },
                            child: const Text(
                              'Search',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 34,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _pinnedCities.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final city = _pinnedCities[index];
                          final isSelected =
                              city.toLowerCase() ==
                              currentCityName.toLowerCase();
                          return InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => _fetchLiveWeather(city),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF4F46E5)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF4F46E5)
                                      : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.location_on_rounded,
                                    size: 13,
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    city,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: isSelected
                                          ? Colors.white
                                          : const Color(0xFF334155),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // ==========================================
              // BODY CONTENT (LOADING / ERROR / LIVE DATA)
              // ==========================================
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Color(0xFF4F46E5)),
                            SizedBox(height: 14),
                            Text(
                              'Fetching real-time satellite & station telemetry...',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: const Color(0xFFFECACA),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  color: Color(0xFFEF4444),
                                  size: 48,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Unable to Fetch Weather Data',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    color: Color(0xFF64748B),
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                FilledButton.icon(
                                  onPressed: () =>
                                      _fetchLiveWeather(_activeQuery),
                                  icon: const Icon(
                                    Icons.refresh_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Try Again'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : _buildLiveWeatherContent(
                        loc!,
                        current!,
                        forecastDays,
                        alertsList,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveWeatherContent(
    Map<String, dynamic> loc,
    Map<String, dynamic> current,
    List<dynamic> forecastDays,
    List<dynamic> alertsList,
  ) {
    final todayMap = forecastDays.isNotEmpty
        ? forecastDays.first as Map<String, dynamic>
        : null;
    final todayDay = todayMap?['day'] as Map<String, dynamic>?;
    final todayAstro = todayMap?['astro'] as Map<String, dynamic>?;
    final todayHours = (todayMap?['hour'] as List?) ?? [];

    final condition = current['condition'] as Map<String, dynamic>?;
    final iconUrl = fixIconUrl(condition?['icon']?.toString());
    final conditionText = condition?['text']?.toString() ?? '';

    final aqiMap = current['air_quality'] as Map<String, dynamic>?;
    final usEpaIndex = (aqiMap?['us-epa-index'] as num?)?.toInt() ?? 0;
    final ukDefraIndex = (aqiMap?['gb-defra-index'] as num?)?.toInt() ?? 0;
    final epaInfo = _epaMeta(usEpaIndex);

    return RefreshIndicator(
      onRefresh: () => _fetchLiveWeather(_activeQuery),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==========================================
            // 2. HERO LIVE WEATHER CARD
            // ==========================================
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF0EA5E9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.25),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Location & Time Metadata Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.place_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    '${loc['name']}, ${loc['region']}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${loc['country']} • Lat ${loc['lat']}, Lon ${loc['lon']} • TZ: ${loc['tz_id']}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          'Local: ${loc['localtime']}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Main Temperature & Condition Icon Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatTemp(
                              current['temp_c'] as num?,
                              current['temp_f'] as num?,
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 56,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Feels like ${_formatDecimalTemp(current['feelslike_c'] as num?, current['feelslike_f'] as num?)}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (todayDay != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'High: ${_formatTemp(todayDay['maxtemp_c'] as num?, todayDay['maxtemp_f'] as num?)}  •  Low: ${_formatTemp(todayDay['mintemp_c'] as num?, todayDay['mintemp_f'] as num?)}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (iconUrl.isNotEmpty)
                            Image.network(
                              iconUrl,
                              width: 72,
                              height: 72,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.wb_cloudy_rounded,
                                color: Colors.white,
                                size: 56,
                              ),
                            ),
                          Text(
                            conditionText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Updated: ${current['last_updated']}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Smart Advisory Strip
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      _smartAdvisory(current, todayDay),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ==========================================
            // GOVERNMENT WEATHER ALERTS (IF ACTIVE)
            // ==========================================
            if (alertsList.isNotEmpty) ...[
              const SizedBox(height: 16),
              ...alertsList.map((rawAlert) {
                final alert = rawAlert as Map<String, dynamic>;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFDC2626),
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              alert['event']?.toString() ?? 'Weather Alert',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                color: Color(0xFF991B1B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              alert['headline']?.toString() ?? '',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF7F1D1D),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],

            const SizedBox(height: 20),

            // ==========================================
            // 3. 24-HOUR TIMELINE STRIP
            // ==========================================
            if (todayHours.isNotEmpty) ...[
              const Text(
                '24-HOUR TIMELINE (TODAY)',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF64748B),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 132,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: todayHours.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final hr = todayHours[index] as Map<String, dynamic>;
                    final timeRaw = hr['time']?.toString() ?? '';
                    final hourLabel = timeRaw.contains(' ')
                        ? timeRaw.split(' ').last
                        : timeRaw;
                    final hrIcon = fixIconUrl(
                      hr['condition']?['icon']?.toString(),
                    );
                    final rainChance =
                        (hr['chance_of_rain'] as num?)?.toInt() ?? 0;

                    return Container(
                      width: 78,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            hourLabel,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF475569),
                            ),
                          ),
                          if (hrIcon.isNotEmpty)
                            Image.network(
                              hrIcon,
                              width: 34,
                              height: 34,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.wb_sunny_outlined,
                                size: 24,
                                color: Color(0xFF4F46E5),
                              ),
                            ),
                          Text(
                            _formatTemp(
                              hr['temp_c'] as num?,
                              hr['temp_f'] as num?,
                            ),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.water_drop_rounded,
                                size: 11,
                                color: Color(0xFF0EA5E9),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '$rainChance%',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0284C7),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 22),
            ],

            // ==========================================
            // 4. AIR QUALITY INDEX (AQI) & POLLUTION STUDIO
            // ==========================================
            if (aqiMap != null) ...[
              const Text(
                'AIR QUALITY & POLLUTION TELEMETRY',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF64748B),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: (epaInfo['color'] as Color).withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.air_rounded,
                                color: epaInfo['color'] as Color,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'AQI Status: ${epaInfo['label']}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  'US-EPA Band: $usEpaIndex / 6  •  UK DEFRA Index: $ukDefraIndex',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: (epaInfo['color'] as Color).withValues(
                              alpha: 0.14,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'EPA $usEpaIndex',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              color: epaInfo['color'] as Color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      epaInfo['advice'] as String,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _PollutantChip(
                          label: 'PM2.5',
                          value:
                              '${(aqiMap['pm2_5'] as num?)?.toStringAsFixed(1) ?? '--'} μg/m³',
                        ),
                        _PollutantChip(
                          label: 'PM10',
                          value:
                              '${(aqiMap['pm10'] as num?)?.toStringAsFixed(1) ?? '--'} μg/m³',
                        ),
                        _PollutantChip(
                          label: 'CO',
                          value:
                              '${(aqiMap['co'] as num?)?.toStringAsFixed(1) ?? '--'} μg/m³',
                        ),
                        _PollutantChip(
                          label: 'NO₂',
                          value:
                              '${(aqiMap['no2'] as num?)?.toStringAsFixed(1) ?? '--'} μg/m³',
                        ),
                        _PollutantChip(
                          label: 'O₃ (Ozone)',
                          value:
                              '${(aqiMap['o3'] as num?)?.toStringAsFixed(1) ?? '--'} μg/m³',
                        ),
                        _PollutantChip(
                          label: 'SO₂',
                          value:
                              '${(aqiMap['so2'] as num?)?.toStringAsFixed(1) ?? '--'} μg/m³',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
            ],

            // ==========================================
            // 5. 8-CARD ATMOSPHERIC BENTO GRID
            // ==========================================
            const Text(
              'COMPLETE ATMOSPHERIC METRICS',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                color: Color(0xFF64748B),
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: MediaQuery.of(context).size.width > 640 ? 4 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.42,
              children: [
                _BentoMetricCard(
                  title: 'WIND & DIRECTION',
                  value: '${current['wind_kph']} km/h',
                  sub:
                      '${current['wind_mph']} mph • ${current['wind_dir']} (${current['wind_degree']}°)',
                  icon: Icons.air_rounded,
                  color: const Color(0xFF3B82F6),
                ),
                _BentoMetricCard(
                  title: 'WIND GUSTS',
                  value: '${current['gust_kph']} km/h',
                  sub: 'Peak: ${current['gust_mph']} mph',
                  icon: Icons.cyclone_rounded,
                  color: const Color(0xFF6366F1),
                ),
                _BentoMetricCard(
                  title: 'HUMIDITY & DEW',
                  value: '${current['humidity']}%',
                  sub:
                      'Dew Point: ${_formatDecimalTemp(current['dewpoint_c'] as num?, current['dewpoint_f'] as num?)}',
                  icon: Icons.water_drop_outlined,
                  color: const Color(0xFF0EA5E9),
                ),
                _BentoMetricCard(
                  title: 'UV INDEX',
                  value:
                      '${current['uv']} (${_uvCategory((current['uv'] as num?) ?? 0)})',
                  sub: 'Solar radiation level',
                  icon: Icons.wb_sunny_outlined,
                  color: const Color(0xFFF59E0B),
                ),
                _BentoMetricCard(
                  title: 'PRESSURE',
                  value: '${current['pressure_mb']} mb',
                  sub: '${current['pressure_in']} inHg atmospheric',
                  icon: Icons.speed_rounded,
                  color: const Color(0xFF8B5CF6),
                ),
                _BentoMetricCard(
                  title: 'VISIBILITY',
                  value: '${current['vis_km']} km',
                  sub: '${current['vis_miles']} miles clear view',
                  icon: Icons.visibility_outlined,
                  color: const Color(0xFF10B981),
                ),
                _BentoMetricCard(
                  title: 'PRECIPITATION & CLOUD',
                  value: '${current['precip_mm']} mm',
                  sub: 'Cloud Cover: ${current['cloud']}%',
                  icon: Icons.umbrella_outlined,
                  color: const Color(0xFF06B6D4),
                ),
                _BentoMetricCard(
                  title: 'THERMAL INDICES',
                  value:
                      'Heat: ${_formatDecimalTemp(current['heatindex_c'] as num?, current['heatindex_f'] as num?)}',
                  sub:
                      'Windchill: ${_formatDecimalTemp(current['windchill_c'] as num?, current['windchill_f'] as num?)}',
                  icon: Icons.thermostat_rounded,
                  color: const Color(0xFFEC4899),
                ),
              ],
            ),

            const SizedBox(height: 22),

            // ==========================================
            // 6. 3-DAY FORECAST BREAKDOWN
            // ==========================================
            if (forecastDays.isNotEmpty) ...[
              const Text(
                '3-DAY WEATHER FORECAST',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF64748B),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 10),
              ...forecastDays.map((rawDay) {
                final dayObj = rawDay as Map<String, dynamic>;
                final dateStr = dayObj['date']?.toString() ?? '';
                final d = dayObj['day'] as Map<String, dynamic>;
                final cond = d['condition'] as Map<String, dynamic>?;
                final dIcon = fixIconUrl(cond?['icon']?.toString());
                final rainProb =
                    (d['daily_chance_of_rain'] as num?)?.toInt() ?? 0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dateStr,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${cond?['text'] ?? ''} • Avg Hum: ${d['avghumidity']}%',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          if (dIcon.isNotEmpty)
                            Image.network(
                              dIcon,
                              width: 34,
                              height: 34,
                              errorBuilder: (_, __, ___) => const SizedBox(),
                            ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '💧 $rainProb%',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0369A1),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${_formatTemp(d['maxtemp_c'] as num?, d['maxtemp_f'] as num?)} / ${_formatTemp(d['mintemp_c'] as num?, d['mintemp_f'] as num?)}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 14),
            ],

            // ==========================================
            // 7. SUN & MOON ASTRONOMY CARD
            // ==========================================
            if (todayAstro != null) ...[
              const Text(
                'SUN & MOON ASTRONOMY',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF64748B),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _AstroTile(
                            icon: Icons.wb_twilight_rounded,
                            color: const Color(0xFFF59E0B),
                            label: 'Sunrise',
                            value: todayAstro['sunrise']?.toString() ?? '--',
                          ),
                        ),
                        Expanded(
                          child: _AstroTile(
                            icon: Icons.nights_stay_outlined,
                            color: const Color(0xFF4F46E5),
                            label: 'Sunset',
                            value: todayAstro['sunset']?.toString() ?? '--',
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24, color: Color(0xFFE2E8F0)),
                    Row(
                      children: [
                        Expanded(
                          child: _AstroTile(
                            icon: Icons.brightness_3_rounded,
                            color: const Color(0xFF0EA5E9),
                            label: 'Moonrise / Set',
                            value:
                                '${todayAstro['moonrise']} / ${todayAstro['moonset']}',
                          ),
                        ),
                        Expanded(
                          child: _AstroTile(
                            icon: Icons.auto_awesome_rounded,
                            color: const Color(0xFF8B5CF6),
                            label:
                                'Moon Phase (${todayAstro['moon_illumination']}%)',
                            value: todayAstro['moon_phase']?.toString() ?? '--',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PollutantChip extends StatelessWidget {
  final String label;
  final String value;

  const _PollutantChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}

class _BentoMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String sub;
  final IconData icon;
  final Color color;

  const _BentoMetricCard({
    required this.title,
    required this.value,
    required this.sub,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 17),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            sub,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _AstroTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _AstroTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
