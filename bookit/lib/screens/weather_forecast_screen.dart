import 'package:flutter/material.dart';

class WeatherForecastScreen extends StatelessWidget {
  const WeatherForecastScreen({
    super.key,
    required this.forecast,
    required this.location,
    required this.onRefresh,
  });

  final List<Map<String, dynamic>> forecast;
  final String location;
  final Future<void> Function() onRefresh;

  static const _weekdays = <String>[
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday',
  ];
  static const _months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _dateLabel(dynamic value, int index) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return index == 0 ? 'Today' : 'Day ${index + 1}';
    final today = DateTime.now();
    final isToday = date.year == today.year &&
        date.month == today.month && date.day == today.day;
    return isToday
        ? 'Today · ${_months[date.month - 1]} ${date.day}'
        : '${_weekdays[date.weekday - 1]} · ${_months[date.month - 1]} ${date.day}';
  }

  String _description(dynamic value) {
    final code = value is num ? value.toInt() : int.tryParse('${value ?? ''}');
    if (code == null) return 'Conditions unavailable';
    if (code == 0) return 'Clear sky';
    if (code == 1) return 'Mainly clear';
    if (code == 2) return 'Partly cloudy';
    if (code == 3) return 'Overcast';
    if (code == 45 || code == 48) return 'Fog';
    if (code >= 51 && code <= 57) return 'Drizzle';
    if (code >= 61 && code <= 67) return 'Rain';
    if (code >= 71 && code <= 77) return 'Snow';
    if (code >= 80 && code <= 82) return 'Rain showers';
    if (code >= 85 && code <= 86) return 'Snow showers';
    if (code >= 95) return 'Thunderstorm';
    return 'Variable conditions';
  }

  IconData _icon(dynamic value) {
    final code = value is num ? value.toInt() : int.tryParse('${value ?? ''}');
    if (code == null) return Icons.cloud_outlined;
    if (code == 0) return Icons.wb_sunny_rounded;
    if (code <= 3) return Icons.cloud_rounded;
    if (code == 45 || code == 48) return Icons.cloud_queue_rounded;
    if ((code >= 51 && code <= 67) ||
        (code >= 80 && code <= 82) || code >= 95) {
      return Icons.thunderstorm_rounded;
    }
    if (code >= 71 && code <= 86) return Icons.ac_unit_rounded;
    return Icons.cloud_outlined;
  }

  String _temperature(dynamic value) {
    if (value is num) return '${value.round()}°';
    final parsed = double.tryParse('${value ?? ''}');
    return parsed == null ? '—' : '${parsed.round()}°';
  }

  String _timeLabel(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) return '—';
    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = theme.colorScheme.onSurface;
    final muted = theme.colorScheme.onSurface.withValues(alpha: .65);
    return Scaffold(
      appBar: AppBar(
        title: const Text('7-day weather'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF075985), Color(0xFF0288D1), Color(0xFF38BDF8)],
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on_outlined, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(location,
                            style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        const Text('Plan ahead with the daily forecast',
                            style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                  const Icon(Icons.calendar_month_outlined, color: Colors.white, size: 28),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text('Coming up this week',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('Temperature and rain chances can change. Pull down to refresh before travelling.',
                style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
            const SizedBox(height: 14),
            if (forecast.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(Icons.cloud_off_outlined, size: 42),
                      const SizedBox(height: 10),
                      const Text('Weekly forecast is not available yet',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text('Check your internet connection and pull down to retry.',
                          textAlign: TextAlign.center, style: TextStyle(color: muted)),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: onRefresh,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh forecast'),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...forecast.asMap().entries.map((entry) {
                final index = entry.key;
                final day = entry.value;
                final rain = day['rain_probability'];
                final rainText = rain is num ? '${rain.round()}%' : '—';
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: .10),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Icon(_icon(day['weather_code']),
                                  color: theme.colorScheme.primary, size: 27),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_dateLabel(day['date'], index),
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                                  const SizedBox(height: 3),
                                  Text(_description(day['weather_code']),
                                      style: TextStyle(color: muted)),
                                ],
                              ),
                            ),
                            Text('${_temperature(day['high'])} / ${_temperature(day['low'])}',
                                style: TextStyle(color: foreground, fontWeight: FontWeight.w800, fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Divider(height: 1, color: theme.dividerColor),
                        const SizedBox(height: 11),
                        Row(
                          children: [
                            Icon(Icons.water_drop_outlined, size: 17, color: muted),
                            const SizedBox(width: 5),
                            Text('Rain chance $rainText', style: TextStyle(color: muted, fontSize: 12)),
                            const Spacer(),
                            Icon(Icons.wb_twilight_outlined, size: 17, color: muted),
                            const SizedBox(width: 5),
                            Text(_timeLabel(day['sunrise']), style: TextStyle(color: muted, fontSize: 12)),
                            const SizedBox(width: 10),
                            Icon(Icons.nights_stay_outlined, size: 16, color: muted),
                            const SizedBox(width: 4),
                            Text(_timeLabel(day['sunset']), style: TextStyle(color: muted, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 8),
            Text('Forecast provided by Open-Meteo. Use it as a planning guide, not a guarantee of road conditions.',
                style: theme.textTheme.bodySmall?.copyWith(color: muted)),
          ],
        ),
      ),
    );
  }
}
