import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';

// Aapke lib folder ki saari 12 tool screens ke imports:
import 'bmi_screen.dart';
import 'calculator_hub_screen.dart';
import 'expense_screen.dart';
import 'image_resizer_screen.dart';
import 'measurement_screen.dart';
import 'pdf_studio_screen.dart';
import 'qr_barcode_screen.dart';
import 'quick_notes_screen.dart';
import 'study_timer_screen.dart';
import 'todo_screen.dart';
import 'weather_screen.dart';
import 'wifi_drop_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Load Environment Variables from .env root file
  await dotenv.load(fileName: ".env");

  // 2. Initialize Firebase strictly using .env configuration
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: dotenv.env['FIREBASE_API_KEY']!,
      appId: kIsWeb
          ? dotenv.env['FIREBASE_WEB_APP_ID']!
          : dotenv.env['FIREBASE_ANDROID_APP_ID']!,
      messagingSenderId: dotenv.env['FIREBASE_MESSAGING_SENDER_ID']!,
      projectId: dotenv.env['FIREBASE_PROJECT_ID']!,
    ),
  );

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const DailyUtilityApp());
}

class DailyUtilityApp extends StatelessWidget {
  const DailyUtilityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Daily Utility Hub Pro',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F46E5),
          brightness: Brightness.light,
          primary: const Color(0xFF4F46E5),
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF8FAFC),
          foregroundColor: Color(0xFF0F172A),
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
      ),
      home: const UtilityDashboardScreen(),
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
  final String badge;
  final Widget Function() screenBuilder;

  const ToolItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.icon,
    required this.color,
    this.badge = '',
    required this.screenBuilder,
  });
}

class UtilityDashboardScreen extends StatefulWidget {
  const UtilityDashboardScreen({super.key});

  @override
  State<UtilityDashboardScreen> createState() => _UtilityDashboardScreenState();
}

class _UtilityDashboardScreenState extends State<UtilityDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';
  final Set<String> _pinnedIds = {'wifi_drop', 'expense', 'bmi', 'pdf'};
  final List<String> _recentIds = [];

  late final List<ToolItem> _allTools = [
    ToolItem(
      id: 'wifi_drop',
      title: 'Wi-Fi Drop',
      subtitle: 'Share files & text across devices',
      category: 'Utilities',
      icon: Icons.wifi_tethering_rounded,
      color: const Color(0xFF4F46E5),
      screenBuilder: () => const WifiDropScreen(),
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
      id: 'bmi',
      title: 'BMI & Health',
      subtitle: 'Biometrics, BMR & macro split',
      category: 'Health',
      icon: Icons.monitor_heart_rounded,
      color: const Color(0xFFEC4899),

      screenBuilder: () => const BmiScreen(),
    ),
    ToolItem(
      id: 'pdf',
      title: 'PDF Studio',
      subtitle: 'Create, merge & manage PDFs',
      category: 'Media',
      icon: Icons.picture_as_pdf_rounded,
      color: const Color(0xFFEF4444),
      screenBuilder: () => const PdfStudioScreen(),
    ),
    ToolItem(
      id: 'image_resizer',
      title: 'Image Resizer',
      subtitle: 'Compress & resize photos fast',
      category: 'Media',
      icon: Icons.photo_size_select_large_rounded,
      color: const Color(0xFF8B5CF6),
      screenBuilder: () => const ImageResizerScreen(),
    ),
    ToolItem(
      id: 'qr_barcode',
      title: 'QR & Barcode',
      subtitle: 'Generate & scan custom codes',
      category: 'Utilities',
      icon: Icons.qr_code_2_rounded,
      color: const Color(0xFF0EA5E9),
      screenBuilder: () => const QrBarcodeScreen(),
    ),
    ToolItem(
      id: 'calc_hub',
      title: 'Calculator Hub',
      subtitle: 'Scientific, GST, EMI & age calc',
      category: 'Finance',
      icon: Icons.calculate_rounded,
      color: const Color(0xFFF59E0B),
      screenBuilder: () => const CalculatorHubScreen(),
    ),
    ToolItem(
      id: 'measurement',
      title: 'Unit Converter',
      subtitle: 'Length, weight, area & temp',
      category: 'Utilities',
      icon: Icons.straighten_rounded,
      color: const Color(0xFF14B8A6),
      screenBuilder: () => const MeasurementScreen(),
    ),
    ToolItem(
      id: 'quick_notes',
      title: 'Quick Notes',
      subtitle: 'Instant ideas, code & memos',
      category: 'Productivity',
      icon: Icons.sticky_note_2_rounded,
      color: const Color(0xFFEAB308),
      screenBuilder: () => const QuickNotesScreen(),
    ),
    ToolItem(
      id: 'todo',
      title: 'Task Manager',
      subtitle: 'Daily goals & checklists',
      category: 'Productivity',
      icon: Icons.task_alt_rounded,
      color: const Color(0xFF3B82F6),
      screenBuilder: () => const TodoScreen(),
    ),
    ToolItem(
      id: 'study_timer',
      title: 'Focus Pomodoro',
      subtitle: 'Deep work & study sessions',
      category: 'Productivity',
      icon: Icons.timer_rounded,
      color: const Color(0xFFF97316),
      screenBuilder: () => const StudyTimerScreen(),
    ),
    ToolItem(
      id: 'weather',
      title: 'Live Weather',
      subtitle: 'Forecast, AQI & humidity',
      category: 'Utilities',
      icon: Icons.wb_sunny_rounded,
      color: const Color(0xFF06B6D4),
      screenBuilder: () => const WeatherScreen(),
    ),
  ];

  static const List<String> _categories = [
    'All',

    'Utilities',
    'Productivity',
    'Finance',
    'Media',
    'Health',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  List<ToolItem> get _filteredTools {
    return _allTools.where((tool) {
      final matchesCategory = _selectedCategory == 'All'
          ? true
          : (_selectedCategory == 'Favorites'
                ? _pinnedIds.contains(tool.id)
                : tool.category == _selectedCategory);

      final q = _searchQuery.trim().toLowerCase();
      final matchesSearch =
          q.isEmpty ||
          tool.title.toLowerCase().contains(q) ||
          tool.subtitle.toLowerCase().contains(q) ||
          tool.category.toLowerCase().contains(q);

      return matchesCategory && matchesSearch;
    }).toList();
  }

  void _openTool(ToolItem tool) {
    setState(() {
      _recentIds.remove(tool.id);
      _recentIds.insert(0, tool.id);
      if (_recentIds.length > 5) _recentIds.removeLast();
    });
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => tool.screenBuilder()),
    );
  }

  void _togglePin(String id) {
    setState(() {
      if (_pinnedIds.contains(id)) {
        _pinnedIds.remove(id);
      } else {
        _pinnedIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tools = _filteredTools;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1020),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: CustomScrollView(
                slivers: [
                  // 1. TOP PREMIUM HEADER BAR
                  SliverToBoxAdapter(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '$_greeting 👋',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Daily Utility Hub',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.apps_rounded,
                                color: Color(0xFF4F46E5),
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${_allTools.length} Pro Tools',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 18)),

                  // 2. HERO BANNER CARD
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4F46E5)
                                .withValues(alpha: 0.25),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'CLOUD SECURED WORKSPACE',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Professional Tools & Secure Sync',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF4F46E5),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () => _openTool(_allTools.first),
                            icon: const Icon(
                              Icons.wifi_tethering_rounded,
                              size: 18,
                            ),
                            label: const Text(
                              'Wi-Fi Drop',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 18)),

                  // 3. SEARCH BAR
                  SliverToBoxAdapter(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search tools (e.g. Expense, BMI, PDF, Wi-Fi Drop)...',
                          hintStyle: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 13.5,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Color(0xFF64748B),
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 15,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 14)),

                  // 4. CATEGORY PILLS
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _categories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final cat = _categories[index];
                          final isSelected = _selectedCategory == cat;
                          return InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () =>
                                setState(() => _selectedCategory = cat),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
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
                                  if (cat == 'Favorites') ...[
                                    Icon(
                                      Icons.star_rounded,
                                      size: 15,
                                      color: isSelected
                                          ? Colors.amberAccent
                                          : const Color(0xFFF59E0B),
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(
                                    cat,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: isSelected
                                          ? Colors.white
                                          : const Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),



                  // 6. TOOLS GRID
                  if (tools.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: Center(
                          child: Text(
                            'No matching tools found.',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverGrid(
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 260,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio:
                            MediaQuery.of(context).size.width > 600
                            ? 1.25
                            : 1.12,
                      ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final tool = tools[index];
                        final isPinned = _pinnedIds.contains(tool.id);
                        return _ToolCard(
                          tool: tool,
                          isPinned: isPinned,
                          onTap: () => _openTool(tool),
                          onTogglePin: () => _togglePin(tool.id),
                        );
                      }, childCount: tools.length),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 36)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final ToolItem tool;
  final bool isPinned;
  final VoidCallback onTap;
  final VoidCallback onTogglePin;

  const _ToolCard({
    required this.tool,
    required this.isPinned,
    required this.onTap,
    required this.onTogglePin,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isPinned
                  ? tool.color.withValues(alpha: 0.45)
                  : const Color(0xFFE2E8F0),
              width: isPinned ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: tool.color.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 6),
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
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: tool.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(tool.icon, color: tool.color, size: 24),
                  ),
                  Row(
                    children: [
                      if (tool.badge.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(right: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: tool.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            tool.badge,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              color: tool.color,
                            ),
                          ),
                        ),
                    ],
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
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    tool.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color.fromARGB(255, 17, 79, 166),
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
