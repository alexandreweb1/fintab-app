import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Renders a legal document (Privacy Policy, Terms of Use, ...) natively inside
/// the app — no external link, no webview. Content is provided as a list of
/// [LegalBlock]s; rendering (typography, links, tables) lives here so every
/// legal screen looks consistent.
class LegalDocumentScreen extends StatelessWidget {
  final String title;
  final List<LegalBlock> blocks;
  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.blocks,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final b in blocks) _BlockView(block: b),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Block model — content is plain data; rendering lives in _BlockView.
// Inline markup supported in text: **bold**, `code`, plus auto-linked emails
// and https URLs (tappable).
// ─────────────────────────────────────────────────────────────────────────────

sealed class LegalBlock {
  const LegalBlock();
}

/// "Last updated" highlight banner.
class Updated extends LegalBlock {
  final String text;
  const Updated(this.text);
}

/// Section (level 2) or subsection (level 3) heading.
class Heading extends LegalBlock {
  final int level;
  final String text;
  const Heading(this.level, this.text);
}

class Para extends LegalBlock {
  final String text;
  const Para(this.text);
}

class Bullets extends LegalBlock {
  final List<String> items;
  final bool indent;
  const Bullets(this.items, {this.indent = false});
}

class Numbered extends LegalBlock {
  final List<String> items;
  const Numbered(this.items);
}

class Quote extends LegalBlock {
  final String text;
  const Quote(this.text);
}

/// Each row renders as a compact card: [title, 'Label: value', ...].
class TableBlock extends LegalBlock {
  final List<List<String>> rows;
  const TableBlock(this.rows);
}

class Rule extends LegalBlock {
  const Rule();
}

// ─────────────────────────────────────────────────────────────────────────────
// Rendering
// ─────────────────────────────────────────────────────────────────────────────

class _BlockView extends StatelessWidget {
  final LegalBlock block;
  const _BlockView({required this.block});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final base = (theme.textTheme.bodyMedium ?? const TextStyle())
        .copyWith(height: 1.55, color: cs.onSurface);

    switch (block) {
      case Updated(:final text):
        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border(left: BorderSide(color: cs.primary, width: 3)),
          ),
          child: Text(text,
              style: base.copyWith(
                  fontSize: (base.fontSize ?? 14) - 1,
                  color: cs.onSurfaceVariant)),
        );

      case Heading(:final level, :final text):
        if (level == 2) {
          return Padding(
            padding: const EdgeInsets.only(top: 26, bottom: 10),
            child: Text(text,
                style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.primary,
                    height: 1.3)),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 6),
          child: Text(text,
              style: base.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: (base.fontSize ?? 14) + 1)),
        );

      case Para(:final text):
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _RichLine(text: text, base: base),
        );

      case Quote(:final text):
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(8),
            border: Border(left: BorderSide(color: cs.primary, width: 3)),
          ),
          child: _RichLine(
              text: text,
              base: base.copyWith(
                  color: cs.onSurfaceVariant,
                  fontSize: (base.fontSize ?? 14) - 0.5)),
        );

      case Bullets(:final items, :final indent):
        return Padding(
          padding: EdgeInsets.only(left: indent ? 16 : 0, bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final it in items)
                _ListItem(marker: '•', text: it, base: base),
            ],
          ),
        );

      case Numbered(:final items):
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < items.length; i++)
                _ListItem(marker: '${i + 1}.', text: items[i], base: base),
            ],
          ),
        );

      case TableBlock(:final rows):
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final row in rows) _RowCard(row: row, base: base),
            ],
          ),
        );

      case Rule():
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Divider(height: 1, color: cs.outlineVariant),
        );
    }
  }
}

/// A bullet/number list item: marker + rich text body.
class _ListItem extends StatelessWidget {
  final String marker;
  final String text;
  final TextStyle base;
  const _ListItem(
      {required this.marker, required this.text, required this.base});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            child: Text(marker,
                style: base.copyWith(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: _RichLine(text: text, base: base)),
        ],
      ),
    );
  }
}

/// A "table row" rendered as a compact card (mobile-friendly vs. 3 columns).
class _RowCard extends StatelessWidget {
  final List<String> row; // [title, 'Label: value', 'Label: value', ...]
  final TextStyle base;
  const _RowCard({required this.row, required this.base});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RichLine(
              text: row.first,
              base: base.copyWith(fontWeight: FontWeight.w700)),
          for (final line in row.skip(1))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: _RichLine(
                  text: line,
                  base: base.copyWith(
                      fontSize: (base.fontSize ?? 14) - 0.5,
                      color: cs.onSurfaceVariant)),
            ),
        ],
      ),
    );
  }
}

/// Renders a line supporting **bold**, `code`, and tappable emails / URLs.
class _RichLine extends StatelessWidget {
  final String text;
  final TextStyle base;
  const _RichLine({required this.text, required this.base});

  static final RegExp _inline = RegExp(
    r'\*\*(.+?)\*\*'
    r'|`([^`]+)`'
    r'|([\w.+%-]+@(?:[\w-]+\.)+[\w-]+)'
    r'|(https?://[^\s)]*[\w/])',
  );

  Future<void> _launch(String target) async {
    final uri = Uri.parse(target);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final link = cs.primary;
    final spans = <InlineSpan>[];
    var i = 0;
    for (final m in _inline.allMatches(text)) {
      if (m.start > i) spans.add(TextSpan(text: text.substring(i, m.start)));
      if (m.group(1) != null) {
        spans.add(TextSpan(
            text: m.group(1),
            style: const TextStyle(fontWeight: FontWeight.w700)));
      } else if (m.group(2) != null) {
        spans.add(TextSpan(
            text: m.group(2),
            style: base.copyWith(
                fontFamily: 'monospace',
                fontSize: (base.fontSize ?? 14) - 1,
                color: cs.onSurfaceVariant)));
      } else if (m.group(3) != null) {
        final email = m.group(3)!;
        spans.add(_link(email, 'mailto:$email', link));
      } else if (m.group(4) != null) {
        final url = m.group(4)!;
        spans.add(
            _link(url.replaceFirst(RegExp(r'^https?://'), ''), url, link));
      }
      i = m.end;
    }
    if (i < text.length) spans.add(TextSpan(text: text.substring(i)));

    return Text.rich(TextSpan(style: base, children: spans));
  }

  InlineSpan _link(String shown, String target, Color color) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: GestureDetector(
        onTap: () => _launch(target),
        child: Text(
          shown,
          style: base.copyWith(
              color: color,
              decoration: TextDecoration.underline,
              decorationColor: color),
        ),
      ),
    );
  }
}
