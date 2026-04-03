import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'wiki_content.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  String? _selectedArticleId;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<WikiArticle> get _filteredArticles {
    if (_searchQuery.isEmpty) return wikiArticles;
    final query = _searchQuery.toLowerCase();
    return wikiArticles.where((a) {
      return a.title.toLowerCase().contains(query) ||
          a.tags.any((t) => t.contains(query)) ||
          a.markdown.toLowerCase().contains(query);
    }).toList();
  }

  WikiArticle? get _selectedArticle {
    if (_selectedArticleId == null) return null;
    return wikiArticles.where((a) => a.id == _selectedArticleId).firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNarrow = MediaQuery.of(context).size.width < 700;

    // Auf schmalen Screens: Liste ODER Artikel
    if (isNarrow && _selectedArticleId != null) {
      return _buildArticleView(theme, showBackButton: true);
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Hilfe & Dokumentation'),
      ),
      body: isNarrow
          ? _buildArticleList(theme)
          : Row(
              children: [
                // Linke Seite: Artikelliste
                SizedBox(
                  width: 300,
                  child: _buildArticleList(theme),
                ),
                const VerticalDivider(width: 1),
                // Rechte Seite: Artikel-Inhalt
                Expanded(
                  child: _selectedArticle != null
                      ? _buildArticleContent(theme)
                      : _buildWelcome(theme),
                ),
              ],
            ),
    );
  }

  Widget _buildArticleList(ThemeData theme) {
    final articles = _filteredArticles;

    return Column(
      children: [
        // Suchfeld
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Suchen...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
        ),
        // Artikelliste
        Expanded(
          child: ListView.builder(
            itemCount: articles.length,
            itemBuilder: (context, index) {
              final article = articles[index];
              final selected = article.id == _selectedArticleId;

              return ListTile(
                leading: Icon(article.icon,
                    color: selected ? theme.colorScheme.primary : null,
                    size: 22),
                title: Text(
                  article.title,
                  style: TextStyle(
                    fontWeight:
                        selected ? FontWeight.bold : FontWeight.normal,
                    color: selected ? theme.colorScheme.primary : null,
                  ),
                ),
                selected: selected,
                selectedTileColor:
                    theme.colorScheme.primary.withValues(alpha: 0.08),
                onTap: () =>
                    setState(() => _selectedArticleId = article.id),
                dense: true,
                visualDensity: VisualDensity.compact,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildArticleContent(ThemeData theme) {
    final article = _selectedArticle!;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Markdown(
        data: article.markdown,
        selectable: true,
        styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
          h1: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
          h2: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          p: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
          listBullet: theme.textTheme.bodyMedium,
          tableHead: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          blockquoteDecoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            border: Border(
              left: BorderSide(
                  color: theme.colorScheme.primary, width: 3),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArticleView(ThemeData theme, {bool showBackButton = false}) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _selectedArticleId = null),
        ),
        title: Text(_selectedArticle?.title ?? ''),
      ),
      body: _buildArticleContent(theme),
    );
  }

  Widget _buildWelcome(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.menu_book, size: 64,
              color: theme.colorScheme.outlineVariant),
          const SizedBox(height: 16),
          Text(
            'Wählen Sie ein Thema aus der Liste',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${wikiArticles.length} Artikel verfügbar',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
