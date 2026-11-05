import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Aapke lib folder ki saari screens ke imports:
import 'bmi_screen.dart';
import 'calculator_hub_screen.dart';
import 'expense_screen.dart';
import 'image_resizer_screen.dart';
import 'measurement_screen.dart';
import 'news_screen.dart';
import 'password_screen.dart';
import 'pdf_studio_screen.dart';
import 'qr_barcode_screen.dart';
import 'quick_notes_screen.dart';
import 'study_timer_screen.dart';
import 'todo_screen.dart';
import 'weather_screen.dart';
import 'wifi_drop_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {}
  runApp(const DailyUtilityHubApp());
}

class DailyUtilityHubApp extends StatelessWidget {
  const DailyUtilityHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Daily Utility Hub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.light,
        ),
        fontFamily: 'Roboto',
      ),
      home: const HomeDashboardScreen(),
    );
  }
}

class ToolItem {
  final String id;
  final String title;
  final String subtitle;
  final String category;
  final IconData icon;
  final Color color;
  final Widget Function() screenBuilder;

  ToolItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.icon,
    required this.color,
    required this.screenBuilder,
  });
}

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  final String newsApiKey =
      dotenv.env['NEWSDATA_API_KEY'] ?? 'YAHAN_APNI_NEWSDATA_API_KEY_DALEIN';

  // News Headlines State
  List topHeadlines = [];
  bool isLoadingNews = true;
  int currentNewsIndex = 0;
  final PageController _newsPageController = PageController(
    viewportFraction: 0.93,
  );
  Timer? _autoScrollTimer;

  // Live Weather AppBar State (Free Open-Meteo API - No API Key Needed!)
  String liveTemp = '--°C';
  String liveCity = 'Patna';
  IconData weatherIcon = Icons.wb_sunny_rounded;
  bool isLoadingWeather = true;

  String selectedCategory = 'All';
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<String> categories = [
    'All',
    'Daily',
    'Productivity',
    'Finance',
    'Utilities',
    'Health',
  ];

  late final List<ToolItem> allTools = [
    ToolItem(
      id: 'news',
      title: 'Smart News',
      subtitle: 'Live Hindi & English headlines',
      category: 'Daily',
      icon: Icons.newspaper_rounded,
      color: const Color(0xFF2563EB),
      screenBuilder: () => const NewsScreen(),
    ),
    ToolItem(
      id: 'weather',
      title: 'Live Weather',
      subtitle: 'Real-time AQI & forecast',
      category: 'Daily',
      icon: Icons.wb_sunny_rounded,
      color: const Color(0xFFF59E0B),
      screenBuilder: () => const WeatherScreen(),
    ),
    ToolItem(
      id: 'expense',
      title: 'Expense Tracker',
      subtitle: 'Smart budget & cloud sync',
      category: 'Finance',
      icon: Icons.account_balance_wallet_rounded,
      color: const Color(0xFF10B981),
      screenBuilder: () => const ExpenseScreen(),
    ),
    ToolItem(
      id: 'todo',
      title: 'To-Do List',
      subtitle: 'Daily tasks & goals manager',
      category: 'Productivity',
      icon: Icons.check_circle_outline_rounded,
      color: const Color(0xFF6366F1),
      screenBuilder: () => const TodoScreen(),
    ),
    ToolItem(
      id: 'notes',
      title: 'Quick Notes',
      subtitle: 'Instant ideas & checklists',
      category: 'Productivity',
      icon: Icons.edit_note_rounded,
      color: const Color(0xFFEC4899),
      screenBuilder: () => const QuickNotesScreen(),
    ),
    ToolItem(
      id: 'timer',
      title: 'Study Timer',
      subtitle: 'Pomodoro focus booster',
      category: 'Productivity',
      icon: Icons.timer_rounded,
      color: const Color(0xFF8B5CF6),
      screenBuilder: () => const StudyTimerScreen(),
    ),
    ToolItem(
      id: 'pdf',
      title: 'PDF Studio',
      subtitle: 'Create & manage PDF docs',
      category: 'Utilities',
      icon: Icons.picture_as_pdf_rounded,
      color: const Color(0xFFEF4444),
      screenBuilder: () => const PdfStudioScreen(),
    ),
    ToolItem(
      id: 'resizer',
      title: 'Image Resizer',
      subtitle: 'Compress & resize for forms',
      category: 'Utilities',
      icon: Icons.photo_size_select_large_rounded,
      color: const Color(0xFF06B6D4),
      screenBuilder: () => const ImageResizerScreen(),
    ),
    ToolItem(
      id: 'qr',
      title: 'QR & Barcode',
      subtitle: 'Generate & scan codes',
      category: 'Utilities',
      icon: Icons.qr_code_scanner_rounded,
      color: const Color(0xFF0F172A),
      screenBuilder: () => const QrBarcodeScreen(),
    ),
    ToolItem(
      id: 'wifi',
      title: 'WiFi Drop',
      subtitle: 'Fast local file sharing',
      category: 'Utilities',
      icon: Icons.wifi_tethering_rounded,
      color: const Color(0xFF0EA5E9),
      screenBuilder: () => const WifiDropScreen(),
    ),
    ToolItem(
      id: 'password',
      title: 'Password Vault',
      subtitle: 'Generate strong passwords',
      category: 'Utilities',
      icon: Icons.lock_outline_rounded,
      color: const Color(0xFF14B8A6),
      screenBuilder: () => const PasswordScreen(),
    ),
    ToolItem(
      id: 'calculator',
      title: 'Calculator Hub',
      subtitle: 'EMI, GST & scientific calc',
      category: 'Finance',
      icon: Icons.calculate_rounded,
      color: const Color(0xFFF97316),
      screenBuilder: () => const CalculatorHubScreen(),
    ),
    ToolItem(
      id: 'measurement',
      title: 'Unit Converter',
      subtitle: 'Length, weight & area',
      category: 'Utilities',
      icon: Icons.straighten_rounded,
      color: const Color(0xFF64748B),
      screenBuilder: () => const MeasurementScreen(),
    ),
    ToolItem(
      id: 'bmi',
      title: 'BMI & Health',
      subtitle: 'Track body mass index',
      category: 'Health',
      icon: Icons.monitor_heart_rounded,
      color: const Color(0xFFE11D48),
      screenBuilder: () => const BmiScreen(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fetchLiveHeaderWeather();
    _fetchTopHeadlines();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _newsPageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // AppBar ke liye Live Weather Fetch (Patna coordinates default + OpenWeather fallback)
  Future<void> _fetchLiveHeaderWeather() async {
    try {
      // Direct fast weather API (bina key ke bhi hamesha live temp dikhayega)
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=25.5941&longitude=85.1376&current_weather=true',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final current = data['current_weather'];
        final double temp = (current['temperature'] as num).toDouble();
        final int code = (current['weathercode'] as num).toInt();

        if (mounted) {
          setState(() {
            liveTemp = '${temp.round()}°C';
            weatherIcon = _getWeatherIcon(code);
            isLoadingWeather = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => isLoadingWeather = false);
    }
  }

  IconData _getWeatherIcon(int code) {
    if (code == 0 || code == 1) return Icons.wb_sunny_rounded;
    if (code == 2 || code == 3) return Icons.wb_cloudy_rounded;
    if (code >= 51 && code <= 67) return Icons.grain_rounded;
    if (code >= 80 && code <= 99) return Icons.thunderstorm_rounded;
    return Icons.cloud_queue_rounded;
  }

  // Web CORS Problem fix karne ke liye Smart Image Proxy URL
  String _getSafeImageUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty || rawUrl == 'null') return '';
    if (kIsWeb) {
      // Flutter Web par blocked news images ko wsrv.nl proxy se load karega
      return 'https://wsrv.nl/?url=${Uri.encodeComponent(rawUrl)}&w=600&output=webp';
    }
    return rawUrl;
  }

  Future<void> _fetchTopHeadlines() async {
    setState(() => isLoadingNews = true);
    try {
      final url =
          'https://newsdata.io/api/1/latest?apikey=$newsApiKey&country=in&language=en&image=1';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final List results = data['results'] ?? [];

        // Sirf wahi news pehle rakhenge jinme image_url maujood hai
        final withImages = results
            .where(
              (item) =>
                  item['image_url'] != null &&
                  item['image_url'].toString().startsWith('http'),
            )
            .toList();

        final finalSelection = withImages.isNotEmpty
            ? withImages.take(6).toList()
            : results.take(5).toList();

        if (mounted) {
          setState(() {
            topHeadlines = finalSelection;
            isLoadingNews = false;
          });
          _startAutoScroll();
        }
      } else {
        if (mounted) setState(() => isLoadingNews = false);
      }
    } catch (_) {
      if (mounted) setState(() => isLoadingNews = false);
    }
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    if (topHeadlines.length <= 1) return;
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_newsPageController.hasClients && topHeadlines.isNotEmpty) {
        int nextPage = (currentNewsIndex + 1) % topHeadlines.length;
        _newsPageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  List<ToolItem> get filteredTools {
    return allTools.where((tool) {
      final matchesCategory =
          selectedCategory == 'All' || tool.category == selectedCategory;
      final matchesSearch =
          tool.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
          tool.subtitle.toLowerCase().contains(searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final int gridColumns = screenWidth > 900
        ? 4
        : screenWidth > 600
        ? 3
        : 2;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.bolt_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily Utility Hub',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.4,
                    ),
                  ),
                  Text(
                    'All-in-One Smart Workspace',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Upar AppBar mein Live Weather Pill Button
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WeatherScreen()),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(weatherIcon, color: const Color(0xFFD97706), size: 19),
                    const SizedBox(width: 6),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          liveTemp,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                            color: Color(0xFF92400E),
                            height: 1.0,
                          ),
                        ),
                        Text(
                          liveCity,
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFB45309),
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFF2563EB),
        onRefresh: () async {
          await _fetchLiveHeaderWeather();
          await _fetchTopHeadlines();
        },
        child: CustomScrollView(
          slivers: [
            // 1. Search Bar
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => searchQuery = val),
                  decoration: InputDecoration(
                    hintText:
                        'Search 14+ tools (e.g., Expense, PDF, News, Timer)...',
                    hintStyle: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF64748B),
                    ),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),

            // 2. Live News Headlines Carousel (With Clear Photo Thumbnail)
            if (searchQuery.isEmpty)
              SliverToBoxAdapter(child: _buildLiveNewsHeadlineBanner()),

            // 3. Category Filter Chips
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Explore Smart Tools',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: categories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final cat = categories[index];
                          final isSelected = selectedCategory == cat;
                          return ChoiceChip(
                            showCheckmark: false,
                            label: Text(cat),
                            selected: isSelected,
                            selectedColor: const Color(0xFF2563EB),
                            backgroundColor: Colors.white,
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF334155),
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              fontSize: 13,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isSelected
                                    ? const Color(0xFF2563EB)
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            onSelected: (_) =>
                                setState(() => selectedCategory = cat),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 4. All Tools Grid
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: gridColumns,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.25,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final tool = filteredTools[index];
                  return _buildToolCard(tool);
                }, childCount: filteredTools.length),
              ),
            ),
          ],
        ),
      ),

      // 5. Website Bottom APK Download Bar
      bottomNavigationBar: kIsWeb
          ? Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                border: Border(top: BorderSide(color: Color(0xFF1E293B))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.android_rounded,
                    color: Color(0xFF10B981),
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  const Flexible(
                    child: Text(
                      'Get the faster mobile experience on your phone:',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () async {
                      final Uri apkUrl = Uri.parse(
                        'https://github.com/balajee-kumar123/Daily-Utility_web/releases/download/v1.0.0/app-arm64-v8a-release.apk',
                      );
                      if (await canLaunchUrl(apkUrl)) {
                        await launchUrl(
                          apkUrl,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                    icon: const Icon(Icons.download_rounded, size: 17),
                    label: const Text(
                      'Download APK',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  // Updated Headlines Card with Clear Side Photo + Proxy Support
  Widget _buildLiveNewsHeadlineBanner() {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'LIVE HEADLINES',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: Color(0xFFEF4444),
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NewsScreen()),
                    );
                  },
                  icon: const Text(
                    'More News',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                  label: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 148,
            child: isLoadingNews
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      alignment: Alignment.center,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Loading top headlines...',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 13.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : topHeadlines.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const NewsScreen()),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.newspaper_rounded,
                              color: Colors.white,
                              size: 38,
                            ),
                            SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Smart News Hub',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Tap to read latest Hindi & English breaking news.',
                                    style: TextStyle(
                                      color: Color(0xFFDBEAFE),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : PageView.builder(
                    controller: _newsPageController,
                    onPageChanged: (idx) =>
                        setState(() => currentNewsIndex = idx),
                    itemCount: topHeadlines.length,
                    itemBuilder: (context, index) {
                      final Map article = Map.from(topHeadlines[index]);
                      final String title = (article['title'] ?? 'Breaking News')
                          .toString();
                      final String source =
                          (article['source_name'] ??
                                  article['source_id'] ??
                                  'News')
                              .toString();
                      final String safeImageUrl = _getSafeImageUrl(
                        article['image_url']?.toString(),
                      );

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const NewsScreen(),
                            ),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1E3A8A)
                                    .withOpacity(0.15),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              // Left Side: Headline Text & Source Badge
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF2563EB),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              source.toUpperCase(),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${index + 1}/${topHeadlines.length}',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      title,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        height: 1.3,
                                      ),
                                    ),
                                    const Row(
                                      children: [
                                        Text(
                                          'Read full story',
                                          style: TextStyle(
                                            color: Color(0xFF93C5FD),
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        SizedBox(width: 4),
                                        Icon(
                                          Icons.arrow_forward_rounded,
                                          color: Color(0xFF93C5FD),
                                          size: 13,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Right Side: Clear News Photo Box
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: safeImageUrl.isNotEmpty
                                    ? Image.network(
                                        safeImageUrl,
                                        width: 115,
                                        height: 120,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            _buildNewsThumbFallback(),
                                      )
                                    : _buildNewsThumbFallback(),
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
    );
  }

  Widget _buildNewsThumbFallback() {
    return Container(
      width: 115,
      height: 120,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.newspaper_rounded,
        color: Color(0xFF60A5FA),
        size: 36,
      ),
    );
  }

  Widget _buildToolCard(ToolItem tool) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => tool.screenBuilder()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: tool.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(tool.icon, color: tool.color, size: 24),
                ),
                const Icon(
                  Icons.arrow_outward_rounded,
                  size: 16,
                  color: Color(0xFF94A3B8),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tool.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  tool.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
