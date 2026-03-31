import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../pseudonymization/providers/pseudonym_providers.dart';

class DictionaryScreen extends ConsumerStatefulWidget {
  const DictionaryScreen({super.key});

  @override
  ConsumerState<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends ConsumerState<DictionaryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _addController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _addController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dictionary = ref.watch(userDictionaryProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/settings'),
        ),
        title: const Text('Wörterbuch verwalten'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.block), text: 'Ausgeschlossene Wörter'),
            Tab(icon: Icon(Icons.person_add), text: 'Gelernte Namen'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildWordList(
            dictionary.excludedWordsList,
            'Wörter die NICHT als Namen erkannt werden sollen.\n'
            'Wenn die Pseudonymisierung ein normales Wort fälschlich als '
            'Name markiert (z.B. "Rose", "Werkstatt"), trage es hier ein. '
            'Es wird dann nie mehr als Name erkannt.',
            'Wort eingeben das kein Name ist...',
            (word) => dictionary.excludeWord(word),
            (word) => dictionary.removeExcludedWord(word),
            theme,
          ),
          _buildWordList(
            dictionary.learnedNamesList,
            'Namen die IMMER pseudonymisiert werden sollen.\n'
            'Wenn ein Name im Text nicht automatisch erkannt wird '
            '(z.B. ein seltener Vorname wie "Dode" oder "Zygmunt"), '
            'trage ihn hier ein. Er wird dann in jedem Bericht '
            'automatisch durch einen Platzhalter ersetzt.',
            'Name eingeben der erkannt werden soll...',
            (word) => dictionary.learnName(word),
            (word) => dictionary.removeLearnedName(word),
            theme,
          ),
        ],
      ),
    );
  }

  Widget _buildWordList(
    List<String> words,
    String description,
    String addHint,
    Future<void> Function(String) onAdd,
    Future<void> Function(String) onRemove,
    ThemeData theme,
  ) {
    return Column(
      children: [
        // Beschreibung
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: theme.colorScheme.surfaceContainerLow,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(description, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 4),
              Text(
                '${words.length} Einträge',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        // Eingabefeld
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _addController,
                  decoration: InputDecoration(
                    hintText: addHint,
                    isDense: true,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () async {
                        final word = _addController.text.trim();
                        if (word.isEmpty) return;
                        await onAdd(word);
                        _addController.clear();
                        setState(() {});
                      },
                    ),
                  ),
                  onSubmitted: (word) async {
                    if (word.trim().isEmpty) return;
                    await onAdd(word.trim());
                    _addController.clear();
                    setState(() {});
                  },
                ),
              ),
            ],
          ),
        ),

        // Liste
        Expanded(
          child: words.isEmpty
              ? Center(
                  child: Text(
                    'Noch keine Einträge.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: words.length,
                  itemBuilder: (context, index) {
                    final word = words[index];
                    return ListTile(
                      title: Text(word),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () async {
                          await onRemove(word);
                          setState(() {});
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
