import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:open_chess/l10n/app_localizations.dart';
import 'package:open_chess/src/features/analysis/analysis_screen.dart';
import 'package:open_chess/src/state/game_import.dart';
import 'package:open_chess/src/state/l10n_labels.dart';

/// Paste or open a PGN/FEN and analyse it. The text is untrusted: bounded,
/// parsed defensively, and every failure is shown, never thrown.
class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final _ctl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  String _message(AppLocalizations t, ImportError e) => switch (e.kind) {
    ImportErrorKind.empty => t.importEmpty,
    ImportErrorKind.tooLarge => t.importTooLarge,
    ImportErrorKind.tooLong => t.importTooLong(maxImportPlies),
    ImportErrorKind.badFen => t.importBadFen(e.detail),
    ImportErrorKind.badMove => t.importBadMove(e.detail),
    ImportErrorKind.unsupported => t.importUnsupported(e.detail),
  };

  Future<void> _paste() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text ?? '';
      if (!mounted) return;
      _setText(text);
    } catch (_) {
      // No clipboard access: the user can still paste into the field.
    }
  }

  Future<void> _openFile() async {
    final t = AppLocalizations.of(context);
    try {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(label: 'PGN / FEN', extensions: ['pgn', 'fen', 'txt']),
        ],
      );
      if (file == null) return;
      // Check the size before reading so a huge file is never loaded.
      if (await file.length() > maxImportChars * 4) {
        setState(() => _error = t.importTooLarge);
        return;
      }
      final text = utf8.decode(await file.readAsBytes(), allowMalformed: true);
      if (!mounted) return;
      _setText(text);
    } catch (e) {
      if (mounted) setState(() => _error = t.importReadFailed);
    }
  }

  void _setText(String text) {
    final t = AppLocalizations.of(context);
    if (text.length > maxImportChars) {
      setState(() => _error = t.importTooLarge);
      return;
    }
    _ctl.text = text;
    setState(() => _error = null);
  }

  void _analyse() {
    final t = AppLocalizations.of(context);
    final ImportedGame game;
    try {
      game = importGame(_ctl.text);
    } on ImportError catch (e) {
      setState(() => _error = _message(t, e));
      return;
    }
    setState(() => _error = null);
    if (game.notes.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(game.notes.map((n) => fenNoteText(t, n)).join(' ')),
          duration: const Duration(seconds: 8),
        ),
      );
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AnalysisScreen(
          moves: game.movesUci,
          startFen: game.startFen,
          variant: game.variant,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.importGame)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _paste,
                    icon: const Icon(Icons.content_paste),
                    label: Text(t.importFromClipboard),
                  ),
                  OutlinedButton.icon(
                    onPressed: _openFile,
                    icon: const Icon(Icons.folder_open),
                    label: Text(t.importFromFile),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TextField(
                  controller: _ctl,
                  maxLines: null,
                  expands: true,
                  maxLength: maxImportChars,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    hintText: t.importHint,
                    border: const OutlineInputBorder(),
                    errorText: _error,
                    errorMaxLines: 4,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _analyse,
                icon: const Icon(Icons.analytics_outlined),
                label: Text(t.analyzeGame),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
