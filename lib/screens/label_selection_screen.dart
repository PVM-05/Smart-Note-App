// lib/screens/label_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/note_provider.dart';
import '../core/design/app_colors.dart';
import '../core/app_localizations.dart';

class LabelSelectionScreen extends StatefulWidget {
  final List<String> initialTags;
  final ValueChanged<List<String>> onTagsChanged;

  const LabelSelectionScreen({
    super.key,
    required this.initialTags,
    required this.onTagsChanged,
  });

  @override
  State<LabelSelectionScreen> createState() => _LabelSelectionScreenState();
}

class _LabelSelectionScreenState extends State<LabelSelectionScreen> {
  late List<String> _selectedTags;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedTags = List.from(widget.initialTags);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<NoteProvider>(context);
    final allLabels = provider.allLabels;
    final filteredLabels = allLabels
        .where((l) => l.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
    final showCreate = _searchQuery.trim().isNotEmpty &&
        !allLabels.any((l) => l.toLowerCase() == _searchQuery.trim().toLowerCase());

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.background(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary(context)),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: GoogleFonts.inter(color: AppColors.textPrimary(context)),
          decoration: InputDecoration(
            hintText: AppLocalizations.translate(context, 'labelSearchHint'),
            border: InputBorder.none,
            hintStyle: GoogleFonts.inter(color: AppColors.placeholder(context)),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, size: 20, color: AppColors.textSecondary(context)),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
          ),
          onChanged: (val) => setState(() => _searchQuery = val),
        ),
      ),
      body: Column(
        children: [
          Divider(height: 1, color: AppColors.divider(context)),
          Expanded(
            child: ListView(
              children: [
                if (showCreate)
                  ListTile(
                    leading: Icon(Icons.add, color: AppColors.textPrimary(context)),
                    title: Text(
                      AppLocalizations.translate(context, 'createLabelOption')
                          .replaceAll('{name}', _searchQuery.trim()),
                      style: GoogleFonts.inter(color: AppColors.textPrimary(context)),
                    ),
                    onTap: () {
                      final newTag = _searchQuery.trim();
                      provider.addLabel(newTag);
                      setState(() {
                        if (!_selectedTags.contains(newTag)) _selectedTags.add(newTag);
                        _searchQuery = '';
                        _searchController.clear();
                      });
                      widget.onTagsChanged(_selectedTags);
                    },
                  ),
                ...filteredLabels.map((label) {
                  final isChecked = _selectedTags.contains(label);
                  return CheckboxListTile(
                    title: Text(label, style: GoogleFonts.inter(color: AppColors.textPrimary(context))),
                    value: isChecked,
                    activeColor: AppColors.textPrimary(context),
                    checkColor: AppColors.background(context),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedTags.add(label);
                        } else {
                          _selectedTags.remove(label);
                        }
                      });
                      widget.onTagsChanged(_selectedTags);
                    },
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
