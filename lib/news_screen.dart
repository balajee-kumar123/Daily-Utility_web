import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  final String apiKey =
      dotenv.env['NEWSDATA_API_KEY'] ?? 'YAHAN_APNI_NEWSDATA_API_KEY_DALEIN';

  List articles = [];
  List bookmarkedArticles = [];
  bool isLoading = true;
  bool showBookmarksOnly = false;
  String? errorMessage;

  String selectedCategory = 'top';
  String selectedLanguage = 'en'; // 'en' for English, 'hi' for Hindi
  final TextEditingController searchController = TextEditingController();

  final List categories = [
    {
      'id': 'top',
      'name': 'Top News',
      'icon': Icons.local_fire_department_rounded,
    },
    {'id': 'technology', 'name': 'Tech', 'icon': Icons.memory_rounded},
    {'id': 'business', 'name': 'Business', 'icon': Icons.trending_up_rounded},
    {'id': 'sports', 'name': 'Sports', 'icon': Icons.sports_cricket_rounded},
    {'id': 'education', 'name': 'Education', 'icon': Icons.school_rounded},
    {'id': 'science', 'name': 'Science', 'icon': Icons.science_rounded},
    {
      'id': 'entertainment',
      'name': 'Movies',
      'icon': Icons.movie_creation_outlined,
    },
    {'id': 'health', 'name': 'Health', 'icon': Icons.favorite_border_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
    fetchNews();
  }

  Future<void> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedData = prefs.getString('saved_news_bookmarks');
    if (savedData != null) {
      setState(() {
        bookmarkedArticles = jsonDecode(savedData);
      });
    }
  }

  Future<void> _toggleBookmark(Map article) async {
    final prefs = await SharedPreferences.getInstance();
    final String articleId = (article['article_id'] ?? article['link'] ?? '')
        .toString();

    final existingIndex = bookmarkedArticles.indexWhere(
      (item) => (item['article_id'] ?? item['link']).toString() == articleId,
    );

    setState(() {
      if (existingIndex >= 0) {
        bookmarkedArticles.removeAt(existingIndex);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Removed from Saved News'),
            duration: Duration(seconds: 1),
          ),
        );
      } else {
        bookmarkedArticles.insert(0, article);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved for offline reading!'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    });

    await prefs.setString(
      'saved_news_bookmarks',
      jsonEncode(bookmarkedArticles),
    );
  }

  bool _isBookmarked(Map article) {
    final String articleId = (article['article_id'] ?? article['link'] ?? '')
        .toString();
    return bookmarkedArticles.any(
      (item) => (item['article_id'] ?? item['link']).toString() == articleId,
    );
  }

  Future<void> fetchNews({String? searchQuery}) async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      showBookmarksOnly = false;
    });

    try {
      String url =
          'https://newsdata.io/api/1/latest?apikey=$apiKey&country=in&language=$selectedLanguage';

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        url += '&q=${Uri.encodeComponent(searchQuery.trim())}';
      } else {
        url += '&category=$selectedCategory';
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          articles = data['results'] ?? [];
          isLoading = false;
        });
      } else {
        final errData = jsonDecode(response.body);
        setState(() {
          errorMessage =
              errData['results']?['message'] ??
              'Failed to load news (Code: ${response.statusCode})';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Internet connection ya API key check karein.';
        isLoading = false;
      });
    }
  }

  Future<void> _openFullArticle(String? urlString) async {
    if (urlString == null || urlString.isEmpty) return;
    final Uri uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List displayList = showBookmarksOnly ? bookmarkedArticles : articles;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.newspaper_rounded,
                color: Color(0xFF2563EB),
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Smart News Hub',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 19,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                setState(() {
                  selectedLanguage = selectedLanguage == 'en' ? 'hi' : 'en';
                });
                fetchNews(searchQuery: searchController.text);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                alignment: Alignment.center,
                child: Text(
                  selectedLanguage == 'en' ? '🇬🇧 EN' : '🇮🇳 हिंदी',
                  style: const TextStyle(
                    color: Color(0xFF1D4ED8),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Saved News',
            onPressed: () {
              setState(() {
                showBookmarksOnly = !showBookmarksOnly;
              });
            },
            icon: Badge(
              isLabelVisible: bookmarkedArticles.isNotEmpty,
              label: Text('${bookmarkedArticles.length}'),
              backgroundColor: const Color(0xFF2563EB),
              child: Icon(
                showBookmarksOnly
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                color: showBookmarksOnly
                    ? const Color(0xFF2563EB)
                    : const Color(0xFF475569),
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Column(
              children: [
                TextField(
                  controller: searchController,
                  onSubmitted: (value) => fetchNews(searchQuery: value),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    hintText: selectedLanguage == 'en'
                        ? 'Search topics (e.g. Cricket, AI, Bihar, Stocks)...'
                        : 'खबरें खोजें (जैसे क्रिकेट, बिहार, टेक्नोलॉजी)...',
                    hintStyle: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 13.5,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF64748B),
                      size: 20,
                    ),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              searchController.clear();
                              fetchNews();
                            },
                          )
                        : IconButton(
                            icon: const Icon(
                              Icons.arrow_forward_rounded,
                              color: Color(0xFF2563EB),
                              size: 20,
                            ),
                            onPressed: () =>
                                fetchNews(searchQuery: searchController.text),
                          ),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final Map cat = categories[index];
                      final bool isSelected =
                          !showBookmarksOnly &&
                          selectedCategory == cat['id'] &&
                          searchController.text.isEmpty;

                      return ChoiceChip(
                        showCheckmark: false,
                        avatar: Icon(
                          cat['icon'],
                          size: 16,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF475569),
                        ),
                        label: Text(cat['name'].toString()),
                        selected: isSelected,
                        selectedColor: const Color(0xFF2563EB),
                        backgroundColor: const Color(0xFFF1F5F9),
                        labelStyle: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF334155),
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
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
                        onSelected: (_) {
                          searchController.clear();
                          setState(() {
                            selectedCategory = cat['id'].toString();
                          });
                          fetchNews();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Expanded(
            child: isLoading && !showBookmarksOnly
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Color(0xFF2563EB)),
                        SizedBox(height: 14),
                        Text(
                          'Fetching latest headlines...',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : errorMessage != null && !showBookmarksOnly
                ? _buildErrorState()
                : displayList.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    color: const Color(0xFF2563EB),
                    onRefresh: () =>
                        fetchNews(searchQuery: searchController.text),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: displayList.length,
                      itemBuilder: (context, index) {
                        final Map article = Map.from(displayList[index]);
                        if (index == 0 && !showBookmarksOnly) {
                          return _buildFeaturedHeroCard(article);
                        }
                        return _buildStandardNewsCard(article);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedHeroCard(Map article) {
    final String title = (article['title'] ?? 'No Title Available').toString();
    final String source =
        (article['source_name'] ?? article['source_id'] ?? 'News Desk')
            .toString();
    final String? imageUrl = article['image_url']?.toString();
    final String pubDate = (article['pubDate'] ?? '')
        .toString()
        .split(' ')
        .first;
    final bool isSaved = _isBookmarked(article);

    return GestureDetector(
      onTap: () => _showArticleReaderModal(article),
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.05),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              child: Stack(
                children: [
                  imageUrl != null && imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _buildImageFallback(height: 200),
                        )
                      : _buildImageFallback(height: 200),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'TOP STORY',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        source.toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFF2563EB),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '•  $pubDate',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: () => _toggleBookmark(article),
                        child: Icon(
                          isSaved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_add_outlined,
                          color: isSaved
                              ? const Color(0xFF2563EB)
                              : const Color(0xFF64748B),
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 17.5,
                      fontWeight: FontWeight.w800,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStandardNewsCard(Map article) {
    final String title = (article['title'] ?? 'No Title').toString();
    final String source =
        (article['source_name'] ?? article['source_id'] ?? 'News').toString();
    final String? imageUrl = article['image_url']?.toString();
    final String pubDate = (article['pubDate'] ?? '')
        .toString()
        .split(' ')
        .first;
    final bool isSaved = _isBookmarked(article);

    return GestureDetector(
      onTap: () => _showArticleReaderModal(article),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      width: 95,
                      height: 95,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _buildImageFallback(width: 95, height: 95),
                    )
                  : _buildImageFallback(width: 95, height: 95),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          source,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF2563EB),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '• $pubDate',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      InkWell(
                        onTap: () => _toggleBookmark(article),
                        child: Icon(
                          isSaved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          size: 19,
                          color: isSaved
                              ? const Color(0xFF2563EB)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showArticleReaderModal(Map article) {
    final String title = (article['title'] ?? 'No Title').toString();
    final String description =
        (article['description'] ??
                'Full story details are available on the official publisher website.')
            .toString();
    final String source =
        (article['source_name'] ?? article['source_id'] ?? 'News Source')
            .toString();
    final String? imageUrl = article['image_url']?.toString();
    final String? link = article['link']?.toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          maxChildSize: 0.92,
          minChildSize: 0.5,
          builder: (_, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (imageUrl != null && imageUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        imageUrl,
                        height: 210,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      source.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF1D4ED8),
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 15.5,
                      color: Color(0xFF334155),
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () => _openFullArticle(link),
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: const Text(
                        'Read Full Article on Website',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildImageFallback({double? width, double? height}) {
    return Container(
      width: width ?? double.infinity,
      height: height ?? 150,
      color: const Color(0xFFEFF6FF),
      alignment: Alignment.center,
      child: const Icon(
        Icons.newspaper_rounded,
        color: Color(0xFF93C5FD),
        size: 36,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            showBookmarksOnly
                ? Icons.bookmark_border_rounded
                : Icons.search_off_rounded,
            size: 56,
            color: const Color(0xFF94A3B8),
          ),
          const SizedBox(height: 12),
          Text(
            showBookmarksOnly ? 'No Saved Articles Yet' : 'No News Found',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            showBookmarksOnly
                ? 'Bookmark any news headline to read it later.'
                : 'Try changing the category or search keyword.',
            style: const TextStyle(fontSize: 13.5, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 54,
              color: Color(0xFFEF4444),
            ),
            const SizedBox(height: 12),
            Text(
              errorMessage ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
              ),
              onPressed: () => fetchNews(),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
