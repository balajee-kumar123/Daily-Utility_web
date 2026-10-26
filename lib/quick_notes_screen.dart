import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

// =========================================================================
// 1. NOTE MODEL CLASS
// =========================================================================
class NoteItem {
  String id;
  String title;
  String content;
  DateTime date;
  int colorValue;
  bool isPinned;

  NoteItem({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
    this.colorValue = 0xFFFFF3E0, // Soft Orange / Amber default
    this.isPinned = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'date': date.toIso8601String(),
        'colorValue': colorValue,
        'isPinned': isPinned,
      };

  factory NoteItem.fromJson(Map<String, dynamic> json) => NoteItem(
        id: json['id'],
        title: json['title'],
        content: json['content'],
        date: DateTime.parse(json['date']),
        colorValue: json['colorValue'] ?? 0xFFFFF3E0,
        isPinned: json['isPinned'] ?? false,
      );
}

// =========================================================================
// 2. MAIN QUICK NOTES SCREEN
// =========================================================================
class QuickNotesScreen extends StatefulWidget {
  const QuickNotesScreen({super.key});

  @override
  State<QuickNotesScreen> createState() => _QuickNotesScreenState();
}

class _QuickNotesScreenState extends State<QuickNotesScreen> {
  List<NoteItem> _notes = [];
  List<NoteItem> _filteredNotes = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;

  final List<Color> _noteColors = [
    const Color(0xFFFFF3E0), // Soft Orange
    const Color(0xFFE1F5FE), // Light Blue
    const Color(0xFFE8F5E9), // Light Green
    const Color(0xFFF3E5F5), // Light Purple
    const Color(0xFFFFEBEE), // Light Pink
    const Color(0xFFFFFDE7), // Light Yellow
  ];

  @override
  void initState() {
    super.initState();
    _loadNotes();
    _searchController.addListener(_filterNotes);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- LOCAL STORAGE LOAD ---
  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final String? notesString = prefs.getString('quick_notes_data');
    if (notesString != null) {
      final List<dynamic> decoded = jsonDecode(notesString);
      setState(() {
        _notes = decoded.map((item) => NoteItem.fromJson(item)).toList();
        _sortNotes();
      });
    }
    setState(() {
      _filteredNotes = _notes;
      _isLoading = false;
    });
  }

  // --- LOCAL STORAGE SAVE ---
  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_notes.map((e) => e.toJson()).toList());
    await prefs.setString('quick_notes_data', encoded);
  }

  void _sortNotes() {
    _notes.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return b.date.compareTo(a.date);
    });
  }

  void _filterNotes() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredNotes = _notes;
      } else {
        _filteredNotes = _notes.where((note) {
          return note.title.toLowerCase().contains(query) ||
              note.content.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  void _addOrUpdateNote(NoteItem note) {
    final index = _notes.indexWhere((element) => element.id == note.id);
    setState(() {
      if (index != -1) {
        _notes[index] = note;
      } else {
        _notes.insert(0, note);
      }
      _sortNotes();
      _filterNotes();
    });
    _saveNotes();
  }

  void _deleteNote(String id) {
    setState(() {
      _notes.removeWhere((element) => element.id == id);
      _filterNotes();
    });
    _saveNotes();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Note deleted!'), duration: Duration(seconds: 2)),
    );
  }

  void _togglePin(NoteItem note) {
    setState(() {
      note.isPinned = !note.isPinned;
      _sortNotes();
      _filterNotes();
    });
    _saveNotes();
  }

  void _openNoteEditor([NoteItem? note]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _NoteEditorSheet(
        note: note,
        availableColors: _noteColors,
        onSave: _addOrUpdateNote,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Quick Voice & Notes', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orange.shade800,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openNoteEditor(),
        backgroundColor: Colors.orange.shade800,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Note', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : Column(
              children: [
                // --- SEARCH BAR ---
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search notes...',
                      prefixIcon: const Icon(Icons.search, color: Colors.orange),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () {
                                _searchController.clear();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
                      ),
                    ),
                  ),
                ),

                // --- NOTES GRID VIEW ---
                Expanded(
                  child: _filteredNotes.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.note_alt_outlined, size: 64, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              Text(
                                _searchController.text.isEmpty
                                    ? 'No notes yet. Tap + to add one!'
                                    : 'No matching notes found.',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.85,
                          ),
                          itemCount: _filteredNotes.length,
                          itemBuilder: (context, index) {
                            final note = _filteredNotes[index];
                            return _buildNoteCard(note);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildNoteCard(NoteItem note) {
    return GestureDetector(
      onTap: () => _openNoteEditor(note),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Color(note.colorValue),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: note.isPinned ? Colors.orange.shade600 : Colors.black.withValues(alpha: 0.06),
            width: note.isPinned ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Top Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    note.title.isEmpty ? 'Untitled' : note.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                InkWell(
                  onTap: () => _togglePin(note),
                  child: Icon(
                    note.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                    size: 18,
                    color: note.isPinned ? Colors.orange.shade800 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Content Preview
            Expanded(
              child: Text(
                note.content,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade800, height: 1.3),
              ),
            ),
            const SizedBox(height: 8),

            // Card Bottom Date & Actions Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('dd MMM').format(note.date),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                ),
                Row(
                  children: [
                    InkWell(
                      onTap: () => Share.share('${note.title}\n\n${note.content}'),
                      child: const Padding(
                        padding: EdgeInsets.all(4.0),
                        child: Icon(Icons.share_outlined, size: 16, color: Colors.black54),
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => _deleteNote(note.id),
                      child: const Padding(
                        padding: EdgeInsets.all(4.0),
                        child: Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// 3. NOTE EDITOR BOTTOM SHEET
// =========================================================================
class _NoteEditorSheet extends StatefulWidget {
  final NoteItem? note;
  final List<Color> availableColors;
  final Function(NoteItem) onSave;

  const _NoteEditorSheet({
    this.note,
    required this.availableColors,
    required this.onSave,
  });

  @override
  State<_NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends State<_NoteEditorSheet> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late int _selectedColor;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(text: widget.note?.content ?? '');
    _selectedColor = widget.note?.colorValue ?? widget.availableColors.first.toARGB32();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _saveNote() {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty) {
      Navigator.pop(context);
      return;
    }

    final newNote = NoteItem(
      id: widget.note?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: title.isEmpty ? 'Quick Note' : title,
      content: content,
      date: DateTime.now(),
      colorValue: _selectedColor,
      isPinned: widget.note?.isPinned ?? false,
    );

    widget.onSave(newNote);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 20,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: Color(_selectedColor),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.note == null ? 'New Note' : 'Edit Note',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 20),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(
                        text: '${_titleController.text}\n\n${_contentController.text}',
                      ));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied to Clipboard!')),
                      );
                    },
                  ),
                  ElevatedButton(
                    onPressed: _saveNote,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade800,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Title Field
          TextField(
            controller: _titleController,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              hintText: 'Note Title...',
              border: InputBorder.none,
            ),
          ),

          // Content Field
          TextField(
            controller: _contentController,
            maxLines: 6,
            minLines: 3,
            style: const TextStyle(fontSize: 15),
            decoration: const InputDecoration(
              hintText: 'Type your note details here...',
              border: InputBorder.none,
            ),
          ),
          const SizedBox(height: 16),

          // Color Palette Picker & Voice Option
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.availableColors.length,
                    itemBuilder: (context, index) {
                      final color = widget.availableColors[index];
                      final isSelected = _selectedColor == color.toARGB32();
                      return GestureDetector(
                        onTap: () => setState(() => _selectedColor = color.toARGB32()),
                        child: Container(
                          margin: const EdgeInsets.only(right: 10),
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.orange.shade800 : Colors.grey.shade400,
                              width: isSelected ? 2.5 : 1,
                            ),
                          ),
                          child: isSelected
                              ? Icon(Icons.check, size: 16, color: Colors.orange.shade800)
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
}