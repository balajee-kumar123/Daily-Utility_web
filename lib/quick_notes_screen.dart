import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QuickNotesScreen extends StatefulWidget {
  const QuickNotesScreen({super.key});

  @override
  State<QuickNotesScreen> createState() => _QuickNotesScreenState();
}

class _QuickNotesScreenState extends State<QuickNotesScreen> {
  List notes = [];
  String searchQuery = '';
  String selectedTagFilter = 'All';
  bool isGridView = true;
  final TextEditingController searchController = TextEditingController();

  final List<String> tags = ['All', 'Personal', 'Study', 'Work', 'Ideas', 'Todo'];

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final String? saved = prefs.getString('premium_quick_notes_v2');
    if (saved != null) {
      setState(() {
        notes = jsonDecode(saved);
      });
    }
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('premium_quick_notes_v2', jsonEncode(notes));
  }

  void _openNoteEditor({Map? existingNote, int? index}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PremiumNoteEditorScreen(existingNote: existingNote),
      ),
    );

    if (result != null && result is Map) {
      setState(() {
        if (index != null) {
          notes[index] = result;
        } else {
          notes.insert(0, result);
        }
        // Pinned notes ko hamesha sabse upar rakhna
        notes.sort((a, b) {
          final bool pinA = a['isPinned'] == true;
          final bool pinB = b['isPinned'] == true;
          if (pinA && !pinB) return -1;
          if (!pinA && pinB) return 1;
          return 0;
        });
      });
      _saveNotes();
    }
  }

  void _deleteNote(int index) {
    setState(() {
      notes.removeAt(index);
    });
    _saveNotes();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Note deleted'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _togglePin(int index) {
    setState(() {
      notes[index]['isPinned'] = !(notes[index]['isPinned'] == true);
      notes.sort((a, b) {
        final bool pinA = a['isPinned'] == true;
        final bool pinB = b['isPinned'] == true;
        if (pinA && !pinB) return -1;
        if (!pinA && pinB) return 1;
        return 0;
      });
    });
    _saveNotes();
  }

  List get filteredNotes {
    return notes.where((n) {
      final String title = (n['title'] ?? '').toString().toLowerCase();
      final String content = (n['content'] ?? '').toString().toLowerCase();
      final String tag = (n['tag'] ?? 'Personal').toString();

      final bool matchesSearch = title.contains(searchQuery.toLowerCase()) ||
          content.contains(searchQuery.toLowerCase());
      final bool matchesTag =
          selectedTagFilter == 'All' || tag == selectedTagFilter;

      return matchesSearch && matchesTag;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final displayNotes = filteredNotes;

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
                color: const Color(0xFFEC4899).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.draw_rounded, color: Color(0xFFEC4899), size: 22),
            ),
            const SizedBox(width: 10),
            const Text(
              'Smart Notes Studio',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: isGridView ? 'Switch to List' : 'Switch to Grid',
            onPressed: () => setState(() => isGridView = !isGridView),
            icon: Icon(
              isGridView ? Icons.view_agenda_outlined : Icons.grid_view_rounded,
              color: const Color(0xFF475569),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        onPressed: () => _openNoteEditor(),
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'New Note / Sketch',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          // Search & Tag Filter Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
            child: Column(
              children: [
                TextField(
                  controller: searchController,
                  onChanged: (val) => setState(() => searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search notes, ideas or sketches...',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              searchController.clear();
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
                const SizedBox(height: 12),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: tags.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final tag = tags[index];
                      final isSelected = selectedTagFilter == tag;
                      return ChoiceChip(
                        showCheckmark: false,
                        label: Text(tag),
                        selected: isSelected,
                        selectedColor: const Color(0xFF0F172A),
                        backgroundColor: const Color(0xFFF1F5F9),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF475569),
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide.none,
                        ),
                        onSelected: (_) => setState(() => selectedTagFilter = tag),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Notes Display Area
          Expanded(
            child: displayNotes.isEmpty
                ? _buildEmptyState()
                : isGridView
                    ? GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount:
                              MediaQuery.of(context).size.width > 700 ? 3 : 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.88,
                        ),
                        itemCount: displayNotes.length,
                        itemBuilder: (context, index) {
                          final note = Map.from(displayNotes[index]);
                          final realIndex = notes.indexOf(displayNotes[index]);
                          return _buildNoteCard(note, realIndex);
                        },
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: displayNotes.length,
                        itemBuilder: (context, index) {
                          final note = Map.from(displayNotes[index]);
                          final realIndex = notes.indexOf(displayNotes[index]);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: SizedBox(
                              height: 155,
                              child: _buildNoteCard(note, realIndex),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteCard(Map note, int realIndex) {
    final String title = (note['title'] ?? 'Untitled Note').toString();
    final String content = (note['content'] ?? '').toString();
    final String tag = (note['tag'] ?? 'Personal').toString();
    final String date = (note['date'] ?? '').toString();
    final int bgColorValue = note['bgColor'] ?? 0xFFFFFFFF;
    final bool isPinned = note['isPinned'] == true;
    final List strokes = note['strokes'] ?? [];
    final String fontStyle = (note['fontStyle'] ?? 'Sans').toString();

    return GestureDetector(
      onTap: () => _openNoteEditor(existingNote: note, index: realIndex),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Color(bgColorValue),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isPinned ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
            width: isPinned ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
                if (strokes.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.brush_rounded, size: 14, color: Color(0xFFEC4899)),
                ],
                const Spacer(),
                InkWell(
                  onTap: () => _togglePin(realIndex),
                  child: Icon(
                    isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                    size: 17,
                    color: isPinned ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => _deleteNote(realIndex),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    size: 17,
                    color: Color(0xFFEF4444),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title.isEmpty ? 'Untitled Note' : title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _getCustomTextStyle(
                fontStyle: fontStyle,
                fontSize: 15.5,
                isBold: true,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: content.isNotEmpty
                  ? Text(
                      content,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: _getCustomTextStyle(
                        fontStyle: fontStyle,
                        fontSize: 13,
                        color: const Color(0xFF475569),
                      ),
                    )
                  : strokes.isNotEmpty
                      ? Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.gesture_rounded, color: Color(0xFF2563EB), size: 18),
                              SizedBox(width: 6),
                              Text(
                                'Handwritten Sketch',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ],
                          ),
                        )
                      : const Text(
                          'Empty note...',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
                        ),
            ),
            const SizedBox(height: 6),
            Text(
              date,
              style: const TextStyle(
                fontSize: 10.5,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFEC4899).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.edit_note_rounded, size: 54, color: Color(0xFFEC4899)),
          ),
          const SizedBox(height: 14),
          const Text(
            'Your Smart Notes Studio is Empty',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tap "New Note / Sketch" to write with custom fonts,\npen, pencil, highlighter & colorful paper!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// PREMIUM NOTE & SKETCH EDITOR SCREEN
// ============================================================================
class PremiumNoteEditorScreen extends StatefulWidget {
  final Map? existingNote;

  const PremiumNoteEditorScreen({super.key, this.existingNote});

  @override
  State<PremiumNoteEditorScreen> createState() => _PremiumNoteEditorScreenState();
}

class _PremiumNoteEditorScreenState extends State<PremiumNoteEditorScreen> {
  late TextEditingController titleController;
  late TextEditingController contentController;

  // Mode: false = Typing Mode, true = Drawing/Sketch Mode
  bool isDrawingMode = false;

  // Typography & Styling States
  String selectedFontStyle = 'Sans'; // Sans, Serif, Mono, Cursive, Heavy
  double fontSize = 16.0;
  bool isBold = false;
  bool isItalic = false;
  bool isUnderline = false;
  int selectedTextColor = 0xFF0F172A;
  int selectedBgColor = 0xFFFFFFFF;
  String selectedTag = 'Personal';
  bool isPinned = false;

  // Drawing Tool States (Pen, Pencil, Highlighter, Eraser)
  String activeBrushTool = 'Pen'; // Pen, Pencil, Highlighter, Eraser
  int selectedInkColor = 0xFF1E293B;
  double penStrokeWidth = 3.5;
  List strokes = [];
  List currentPoints = [];

  final List<String> fontOptions = ['Sans', 'Serif', 'Mono', 'Cursive', 'Display'];
  final List<String> tags = ['Personal', 'Study', 'Work', 'Ideas', 'Todo'];

  // 10 Rich Ink & Text Colors
  final List<int> inkColors = [
    0xFF0F172A, // Charcoal Black
    0xFF2563EB, // Royal Blue
    0xFFDC2626, // Crimson Red
    0xFF16A34A, // Emerald Green
    0xFF9333EA, // Vivid Purple
    0xFFEA580C, // Sunset Orange
    0xFFDB2777, // Hot Pink
    0xFF0891B2, // Cyan Teal
    0xFFCA8A04, // Golden Yellow
    0xFF475569, // Slate Grey
  ];

  // 6 Pastel Paper Background Colors
  final List<int> paperColors = [
    0xFFFFFFFF, // Pure White
    0xFFFEF9C3, // Warm Yellow Note
    0xFFE0F2FE, // Sky Blue Note
    0xFFDCFCE7, // Mint Green Note
    0xFFFCE7F3, // Rose Pink Note
    0xFFF3E8FF, // Lavender Note
  ];

  @override
  void initState() {
    super.initState();
    final note = widget.existingNote;
    titleController = TextEditingController(text: (note?['title'] ?? '').toString());
    contentController = TextEditingController(text: (note?['content'] ?? '').toString());
    selectedFontStyle = (note?['fontStyle'] ?? 'Sans').toString();
    fontSize = (note?['fontSize'] ?? 16.0).toDouble();
    isBold = note?['isBold'] == true;
    isItalic = note?['isItalic'] == true;
    isUnderline = note?['isUnderline'] == true;
    selectedTextColor = note?['textColor'] ?? 0xFF0F172A;
    selectedBgColor = note?['bgColor'] ?? 0xFFFFFFFF;
    selectedTag = (note?['tag'] ?? 'Personal').toString();
    isPinned = note?['isPinned'] == true;

    if (note?['strokes'] != null) {
      strokes = List.from(jsonDecode(jsonEncode(note!['strokes'])));
    }
  }

  void _saveAndExit() {
    if (titleController.text.trim().isEmpty &&
        contentController.text.trim().isEmpty &&
        strokes.isEmpty) {
      Navigator.pop(context);
      return;
    }

    final now = DateTime.now();
    final formattedDate =
        '${now.day}/${now.month}/${now.year} • ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final noteData = {
      'title': titleController.text.trim().isEmpty
          ? 'Quick Note'
          : titleController.text.trim(),
      'content': contentController.text,
      'fontStyle': selectedFontStyle,
      'fontSize': fontSize,
      'isBold': isBold,
      'isItalic': isItalic,
      'isUnderline': isUnderline,
      'textColor': selectedTextColor,
      'bgColor': selectedBgColor,
      'tag': selectedTag,
      'isPinned': isPinned,
      'strokes': strokes,
      'date': formattedDate,
    };

    Navigator.pop(context, noteData);
  }

  // Tool ke hisab se stroke width aur opacity decide karna
  double _getEffectiveWidth() {
    if (activeBrushTool == 'Pencil') return 1.8;
    if (activeBrushTool == 'Highlighter') return 14.0;
    if (activeBrushTool == 'Eraser') return 22.0;
    return penStrokeWidth;
  }

  double _getEffectiveOpacity() {
    if (activeBrushTool == 'Highlighter') return 0.35;
    if (activeBrushTool == 'Pencil') return 0.75;
    return 1.0;
  }

  int _getEffectiveColor() {
    if (activeBrushTool == 'Eraser') return selectedBgColor;
    return selectedInkColor;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(selectedBgColor),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Color(selectedBgColor),
        foregroundColor: const Color(0xFF0F172A),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _saveAndExit,
        ),
        title: Container(
          height: 38,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.06),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildModeTab(
                label: 'Type Text',
                icon: Icons.keyboard_alt_outlined,
                selected: !isDrawingMode,
                onTap: () => setState(() => isDrawingMode = false),
              ),
              _buildModeTab(
                label: 'Pen / Sketch',
                icon: Icons.gesture_rounded,
                selected: isDrawingMode,
                onTap: () => setState(() => isDrawingMode = true),
              ),
            ],
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Pin Note',
            onPressed: () => setState(() => isPinned = !isPinned),
            icon: Icon(
              isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              color: isPinned ? const Color(0xFF2563EB) : const Color(0xFF475569),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _saveAndExit,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Top Tag & Paper Background Picker Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.06))),
            ),
            child: Row(
              children: [
                // Tag Dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedTag,
                      isDense: true,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                      items: tags
                          .map((t) => DropdownMenuItem(value: t, child: Text('🏷️ $t')))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => selectedTag = val);
                      },
                    ),
                  ),
                ),
                const Spacer(),
                const Text(
                  'Paper:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                ),
                const SizedBox(width: 8),
                // Paper Color Circles
                Row(
                  children: paperColors.map((colorVal) {
                    final bool isSelected = selectedBgColor == colorVal;
                    return GestureDetector(
                      onTap: () => setState(() => selectedBgColor = colorVal),
                      child: Container(
                        margin: const EdgeInsets.only(left: 6),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Color(colorVal),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                            width: isSelected ? 2.2 : 1,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // Main Workspace (Combined Title + Text + Drawing Canvas Layer)
          Expanded(
            child: Stack(
              children: [
                // Layer 1: Background Sketch / Drawing Canvas
                Positioned.fill(
                  child: CustomPaint(
                    painter: _NoteSketchPainter(strokes: strokes),
                  ),
                ),

                // Layer 2: Text Input Layer
                SingleChildScrollView(
                  physics: isDrawingMode
                      ? const NeverScrollableScrollPhysics()
                      : const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: titleController,
                        enabled: !isDrawingMode,
                        style: _getCustomTextStyle(
                          fontStyle: selectedFontStyle,
                          fontSize: 22,
                          isBold: true,
                          color: Color(selectedTextColor),
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Note Title...',
                          hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                          border: InputBorder.none,
                        ),
                      ),
                      const Divider(height: 12),
                      TextField(
                        controller: contentController,
                        enabled: !isDrawingMode,
                        maxLines: null,
                        minLines: 14,
                        style: _getCustomTextStyle(
                          fontStyle: selectedFontStyle,
                          fontSize: fontSize,
                          isBold: isBold,
                          isItalic: isItalic,
                          isUnderline: isUnderline,
                          color: Color(selectedTextColor),
                        ),
                        decoration: InputDecoration(
                          hintText: isDrawingMode
                              ? 'Drawing Mode Active — Use your finger or mouse to sketch anywhere!'
                              : 'Start typing your ideas, lecture notes, or checklist here...',
                          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
                          border: InputBorder.none,
                        ),
                      ),
                    ],
                  ),
                ),

                // Layer 3: Active Touch Gesture Layer (Only captures touches when in Drawing Mode)
                if (isDrawingMode)
                  Positioned.fill(
                    child: GestureDetector(
                      onPanStart: (details) {
                        setState(() {
                          currentPoints = [
                            {'x': details.localPosition.dx, 'y': details.localPosition.dy}
                          ];
                          strokes.add({
                            'tool': activeBrushTool,
                            'color': _getEffectiveColor(),
                            'width': _getEffectiveWidth(),
                            'opacity': _getEffectiveOpacity(),
                            'points': currentPoints,
                          });
                        });
                      },
                      onPanUpdate: (details) {
                        setState(() {
                          currentPoints.add({
                            'x': details.localPosition.dx,
                            'y': details.localPosition.dy,
                          });
                        });
                      },
                      onPanEnd: (_) {
                        currentPoints = [];
                      },
                      child: Container(color: Colors.transparent),
                    ),
                  ),
              ],
            ),
          ),

          // Bottom Premium Studio Toolbar (Changes based on Typing vs Drawing Mode)
          isDrawingMode ? _buildDrawingToolbar() : _buildTypographyToolbar(),
        ],
      ),
    );
  }

  Widget _buildModeTab({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2563EB) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 15,
              color: selected ? Colors.white : const Color(0xFF475569),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Toolbar 1: Rich Typography & Font Picker
  Widget _buildTypographyToolbar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Font Family Chips
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: fontOptions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final font = fontOptions[index];
                final isSelected = selectedFontStyle == font;
                return ChoiceChip(
                  showCheckmark: false,
                  label: Text(
                    font,
                    style: _getCustomTextStyle(
                      fontStyle: font,
                      fontSize: 12.5,
                      isBold: isSelected,
                      color: isSelected ? Colors.white : const Color(0xFF334155),
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: const Color(0xFF2563EB),
                  backgroundColor: const Color(0xFFF1F5F9),
                  onSelected: (_) => setState(() => selectedFontStyle = font),
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          // Row 2: Bold, Italic, Underline, Font Size & Text Color
          Row(
            children: [
              _buildFormatIconBtn(
                icon: Icons.format_bold_rounded,
                active: isBold,
                onTap: () => setState(() => isBold = !isBold),
              ),
              const SizedBox(width: 6),
              _buildFormatIconBtn(
                icon: Icons.format_italic_rounded,
                active: isItalic,
                onTap: () => setState(() => isItalic = !isItalic),
              ),
              const SizedBox(width: 6),
              _buildFormatIconBtn(
                icon: Icons.format_underlined_rounded,
                active: isUnderline,
                onTap: () => setState(() => isUnderline = !isUnderline),
              ),
              const SizedBox(width: 10),
              // Font Size Decrease / Increase
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () {
                        if (fontSize > 12) setState(() => fontSize -= 2);
                      },
                      child: const Icon(Icons.remove_rounded, size: 18),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        '${fontSize.toInt()}px',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        if (fontSize < 30) setState(() => fontSize += 2);
                      },
                      child: const Icon(Icons.add_rounded, size: 18),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Scrollable Text Color Picker
              Expanded(
                child: SizedBox(
                  height: 28,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: inkColors.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final colorVal = inkColors[index];
                      final isSelected = selectedTextColor == colorVal;
                      return GestureDetector(
                        onTap: () => setState(() => selectedTextColor = colorVal),
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: Color(colorVal),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, color: Colors.white, size: 14)
                              : null,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Toolbar 2: Pen, Pencil, Highlighter, Eraser & Color Palette
  Widget _buildDrawingToolbar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Brush Tools (Pen, Pencil, Highlighter, Eraser, Undo, Clear)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBrushToolBtn('Pen', Icons.edit_rounded, const Color(0xFF2563EB)),
              _buildBrushToolBtn('Pencil', Icons.create_outlined, const Color(0xFF475569)),
              _buildBrushToolBtn('Highlighter', Icons.border_color_rounded, const Color(0xFFD97706)),
              _buildBrushToolBtn('Eraser', Icons.auto_fix_normal_rounded, const Color(0xFFEC4899)),
              IconButton(
                tooltip: 'Undo Last Stroke',
                onPressed: strokes.isEmpty
                    ? null
                    : () => setState(() => strokes.removeLast()),
                icon: const Icon(Icons.undo_rounded),
              ),
              IconButton(
                tooltip: 'Clear Sketch',
                onPressed: strokes.isEmpty
                    ? null
                    : () => setState(() => strokes.clear()),
                icon: const Icon(Icons.delete_sweep_rounded, color: Color(0xFFEF4444)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Row 2: Color Palette + Thickness Slider
          Row(
            children: [
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 30,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: inkColors.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final colorVal = inkColors[index];
                      final isSelected = selectedInkColor == colorVal && activeBrushTool != 'Eraser';
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedInkColor = colorVal;
                            if (activeBrushTool == 'Eraser') activeBrushTool = 'Pen';
                          });
                        },
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Color(colorVal),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? const Color(0xFF2563EB) : Colors.white,
                              width: 2.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, color: Colors.white, size: 15)
                              : null,
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (activeBrushTool == 'Pen') ...[
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                    ),
                    child: Slider(
                      value: penStrokeWidth,
                      min: 1.5,
                      max: 10.0,
                      activeColor: Color(selectedInkColor),
                      onChanged: (val) => setState(() => penStrokeWidth = val),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormatIconBtn({
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 18,
          color: active ? Colors.white : const Color(0xFF334155),
        ),
      ),
    );
  }

  Widget _buildBrushToolBtn(String name, IconData icon, Color activeColor) {
    final bool isSelected = activeBrushTool == name;
    return GestureDetector(
      onTap: () => setState(() => activeBrushTool = name),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.14) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? activeColor : const Color(0xFF64748B)),
            const SizedBox(width: 4),
            Text(
              name,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: isSelected ? activeColor : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// CUSTOM PAINTER FOR PEN, PENCIL & HIGHLIGHTER STROKES
// ============================================================================
class _NoteSketchPainter extends CustomPainter {
  final List strokes;

  _NoteSketchPainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    for (final rawStroke in strokes) {
      final Map stroke = Map.from(rawStroke);
      final List points = stroke['points'] ?? [];
      if (points.isEmpty) continue;

      final int colorVal = stroke['color'] ?? 0xFF0F172A;
      final double width = (stroke['width'] ?? 3.5).toDouble();
      final double opacity = (stroke['opacity'] ?? 1.0).toDouble();

      final Paint paint = Paint()
        ..color = Color(colorVal).withOpacity(opacity)
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final Path path = Path();
      final Map firstPt = Map.from(points.first);
      path.moveTo((firstPt['x'] as num).toDouble(), (firstPt['y'] as num).toDouble());

      for (int i = 1; i < points.length; i++) {
        final Map pt = Map.from(points[i]);
        path.lineTo((pt['x'] as num).toDouble(), (pt['y'] as num).toDouble());
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Helper for 5 Distinct Font Styles (Works across Android & Web out of the box)
TextStyle _getCustomTextStyle({
  required String fontStyle,
  required double fontSize,
  bool isBold = false,
  bool isItalic = false,
  bool isUnderline = false,
  required Color color,
}) {
  String? family;
  double letterSpacing = 0.0;

  switch (fontStyle) {
    case 'Serif':
      family = 'Georgia';
      letterSpacing = 0.2;
      break;
    case 'Mono':
      family = 'monospace';
      letterSpacing = -0.3;
      break;
    case 'Cursive':
      family = 'cursive';
      letterSpacing = 0.5;
      break;
    case 'Display':
      family = 'Roboto';
      letterSpacing = 0.8;
      break;
    default:
      family = 'Roboto';
  }

  return TextStyle(
    fontFamily: family,
    fontSize: fontSize,
    fontWeight: isBold || fontStyle == 'Display' ? FontWeight.w800 : FontWeight.w500,
    fontStyle: isItalic || fontStyle == 'Cursive' ? FontStyle.italic : FontStyle.normal,
    decoration: isUnderline ? TextDecoration.underline : TextDecoration.none,
    letterSpacing: letterSpacing,
    color: color,
    height: 1.45,
  );
}