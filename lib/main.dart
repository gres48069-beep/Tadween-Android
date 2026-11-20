import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const NotesApp());
}

class NotesApp extends StatelessWidget {
  const NotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      debugShowCheckedModeBanner: false,
      title: 'تدوين',
      theme: CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: Color(0xFFD4A000),
        scaffoldBackgroundColor: Color(0xFFF2F2F7),
      ),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: NotesHomePage(),
      ),
    );
  }
}

class Note {
  String id;
  String title;
  String content;
  String date;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'date': date,
      };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
        id: json['id'],
        title: json['title'],
        content: json['content'],
        date: json['date'],
      );
}

class NotesHomePage extends StatefulWidget {
  const NotesHomePage({super.key});

  @override
  State<NotesHomePage> createState() => _NotesHomePageState();
}

class _NotesHomePageState extends State<NotesHomePage> {
  List<Note> _notes = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedData = prefs.getString('ios_notes_data');
    if (savedData != null) {
      final List<dynamic> decoded = jsonDecode(savedData);
      setState(() {
        _notes = decoded.map((item) => Note.fromJson(item)).toList();
      });
    }
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_notes.map((n) => n.toJson()).toList());
    await prefs.setString('ios_notes_data', encoded);
  }

  void _openEditor({Note? existingNote}) async {
    final result = await Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => Directionality(
          textDirection: TextDirection.rtl,
          child: NoteEditorPage(note: existingNote),
        ),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        if (result['action'] == 'delete' && existingNote != null) {
          _notes.removeWhere((n) => n.id == existingNote.id);
        } else if (result['action'] == 'save') {
          final now = DateTime.now();
          final dateStr = '${now.year}/${now.month}/${now.day}';
          if (existingNote != null) {
            existingNote.title = result['title'];
            existingNote.content = result['content'];
            existingNote.date = dateStr;
          } else {
            _notes.insert(
              0,
              Note(
                id: now.millisecondsSinceEpoch.toString(),
                title: result['title'],
                content: result['content'],
                date: dateStr,
              ),
            );
          }
        }
      });
      await _saveNotes();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredNotes = _notes.where((note) {
      final q = _searchQuery.toLowerCase();
      return note.title.toLowerCase().contains(q) ||
          note.content.toLowerCase().contains(q);
    }).toList();

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('تدوين'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.square_pencil, size: 26),
          onPressed: () => _openEditor(),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: CupertinoSearchTextField(
                placeholder: 'بحث في الملاحظات...',
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
            Expanded(
              child: filteredNotes.isEmpty
                  ? const Center(
                      child: Text(
                        'لا توجد ملاحظات بعد.\nاضغط على أيقونة القلم بالأعلى للإضافة.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: CupertinoColors.systemGrey,
                          fontSize: 16,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: filteredNotes.length,
                      itemBuilder: (context, index) {
                        final note = filteredNotes[index];
                        return GestureDetector(
                          onTap: () => _openEditor(existingNote: note),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: CupertinoColors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  note.title.isEmpty ? 'بدون عنوان' : note.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  note.content.isEmpty
                                      ? 'لا يوجد نص إضافي'
                                      : note.content,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: CupertinoColors.systemGrey,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  note.date,
                                  style: const TextStyle(
                                    color: CupertinoColors.systemGrey2,
                                    fontSize: 12,
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
    );
  }
}

class NoteEditorPage extends StatefulWidget {
  final Note? note;
  const NoteEditorPage({super.key, this.note});

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(text: widget.note?.content ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _saveAndExit() {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty && content.isEmpty) {
      Navigator.pop(context);
      return;
    }
    Navigator.pop(context, {
      'action': 'save',
      'title': title,
      'content': content,
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.white,
      navigationBar: CupertinoNavigationBar(
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _saveAndExit,
          child: const Text(
            'تم',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        trailing: widget.note != null
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () =>
                    Navigator.pop(context, {'action': 'delete'}),
                child: const Icon(
                  CupertinoIcons.delete,
                  color: CupertinoColors.destructiveRed,
                ),
              )
            : null,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              CupertinoTextField(
                controller: _titleController,
                placeholder: 'عنوان الملاحظة',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                decoration: null,
              ),
              const Divider(height: 20),
              Expanded(
                child: CupertinoTextField(
                  controller: _contentController,
                  placeholder: 'اكتب ملاحظتك هنا...',
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(fontSize: 17, height: 1.5),
                  decoration: null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
