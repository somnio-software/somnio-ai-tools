// Guards the six `skills/<stack>-health-audit/assets/report-template.md`
// files against re-diverging from `docs/report-template-canonical.md`
// (the contract shipped in commit 1470462). Every invariant here is a
// property those six near-identical, hand-maintained files must share;
// a stack-specific field list, wording or evidence bullet is left alone.
//
// These templates are NOT read by the CLI at runtime (see the canonical
// doc's header), so nothing else in `dart analyze`/`dart test` would ever
// catch a hand-edit that quietly breaks the contract. This file is that
// safety net.
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Skills using weight family A: no Performance section, has a slot-B
/// section (Repositories & Data Layer / Data Layer).
const _groupA = ['flutter', 'python', 'nestjs'];

/// Skills using weight family B: no slot-B section, has a Performance
/// section instead.
const _groupB = ['react', 'angular', 'angularjs'];

const _allStacks = [..._groupA, ..._groupB];

/// Sections 9..15 (Documentation & Operations through Appendix: Evidence
/// Index) must be byte-identical across all six templates.
const _canonicalTail = [
  'Documentation & Operations',
  'CI/CD (Configs Found in Repo)',
  'AI Harness & Adoption',
  'Additional Metrics',
  'Risks & Opportunities',
  'Recommendations',
  'Appendix: Evidence Index',
];

/// The scorecard's scoring-legend blockquote, byte-identical across all six
/// — including the en dash (U+2013) and middle dot (U+00B7).
const _scoringLegend =
    '> **Scoring:** Strong (85–100) · Fair (70–84) · '
    'Weak (0–69)';

/// Weight family A (flutter, python, nestjs) — the exact multiset of
/// per-section weights, order-independent.
const _groupAWeights = <double>[0.18, 0.18, 0.18, 0.10, 0.10, 0.10, 0.03, 0.03, 0.10];

/// Weight family B (react, angular, angularjs).
const _groupBWeights = <double>[0.18, 0.18, 0.135, 0.135, 0.135, 0.075, 0.03, 0.03, 0.10];

/// Walks up from the test's working directory until it finds the repo root
/// (the directory that contains the top-level `skills/` folder). Mirrors the
/// idiom used by `test/src/content/skill_registry_test.dart`.
String _repoRoot() {
  var dir = Directory.current;
  while (true) {
    if (Directory(p.join(dir.path, 'skills')).existsSync()) return dir.path;
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('Could not locate repo root from ${Directory.current}');
    }
    dir = parent;
  }
}

String _templatePath(String stack) => p.join(
      _repoRoot(),
      'skills',
      '$stack-health-audit',
      'assets',
      'report-template.md',
    );

String _skillLabel(String stack) => '$stack-health-audit report-template.md';

/// A numbered `## N. Title` heading and the (0-based) line it starts on.
class _Heading {
  _Heading(this.number, this.title, this.lineIndex);
  final int number;
  final String title;
  final int lineIndex;
}

final _numberedHeadingPattern = RegExp(r'^## (\d+)\.\s+(.+?)\s*$');

List<_Heading> _numberedHeadings(List<String> lines) {
  final result = <_Heading>[];
  for (var i = 0; i < lines.length; i++) {
    final match = _numberedHeadingPattern.firstMatch(lines[i]);
    if (match != null) {
      result.add(_Heading(int.parse(match.group(1)!), match.group(2)!, i));
    }
  }
  return result;
}

/// Returns the [start, end) line range of the section whose heading line is
/// exactly [headingLine] (e.g. `## 7. Testing`) — up to (but excluding) the
/// next `## ` heading line, or the end of the file if there is none.
({int start, int end}) _sectionRange(List<String> lines, String headingLine) {
  final start = lines.indexOf(headingLine);
  if (start == -1) {
    throw StateError('heading not found: "$headingLine"');
  }
  var end = lines.length;
  for (var i = start + 1; i < lines.length; i++) {
    if (lines[i].startsWith('## ')) {
      end = i;
      break;
    }
  }
  return (start: start, end: end);
}

/// Parses the `| Section | Weight |` rows out of the Appendix: Scoring
/// Methodology block, keyed by row label (with any `**bold**` stripped),
/// excluding the header/separator rows and the `Total` row.
Map<String, double> _parseWeightRows(List<String> sectionLines) {
  final weights = <String, double>{};
  for (final line in sectionLines) {
    if (!line.trimLeft().startsWith('|')) continue;
    final cells = line.split('|').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
    if (cells.length != 2) continue;
    final label = cells[0].replaceAll('*', '').trim();
    final value = double.tryParse(cells[1].replaceAll('*', '').trim());
    if (value == null) continue; // header row ("Section"/"Weight") or the '---' separator
    if (label == 'Total') continue;
    weights[label] = value;
  }
  return weights;
}

void main() {
  final content = {for (final s in _allStacks) s: File(_templatePath(s)).readAsStringSync()};
  final lines = {for (final s in _allStacks) s: content[s]!.split('\n')};
  final headings = {for (final s in _allStacks) s: _numberedHeadings(lines[s]!)};

  group('report-template.md drift check (canonical contract, docs/report-template-canonical.md)',
      () {
    group('invariant 1: exactly 15 numbered sections, 1..15, no gaps or duplicates', () {
      for (final stack in _allStacks) {
        test(stack, () {
          final numbers = headings[stack]!.map((h) => h.number).toList();
          expect(
            numbers,
            List.generate(15, (i) => i + 1),
            reason:
                '${_skillLabel(stack)}: expected numbered headings 1..15 in order '
                'with no gaps or duplicates, found $numbers',
          );
        });
      }
    });

    group('invariant 2: canonical section-name sequence (with only the documented '
        'stack-variable slots)', () {
      for (final stack in _allStacks) {
        test(stack, () {
          final titles = headings[stack]!.map((h) => h.title).toList();
          expect(titles.length, 15, reason: '${_skillLabel(stack)}: expected 15 sections');

          expect(titles[0], 'Executive Summary',
              reason: '${_skillLabel(stack)}: section 1 diverged');
          expect(titles[1], 'At-a-Glance Scorecard',
              reason: '${_skillLabel(stack)}: section 2 diverged');
          expect(titles[2], 'Tech Stack', reason: '${_skillLabel(stack)}: section 3 diverged');
          expect(titles[3], 'Architecture', reason: '${_skillLabel(stack)}: section 4 diverged');

          final slotA = titles[4];
          const validSlotA = ['State Management', 'API Design'];
          expect(
            validSlotA.contains(slotA),
            isTrue,
            reason: '${_skillLabel(stack)}: section 5 must be "State Management" or '
                '"API Design", found "$slotA"',
          );

          final slot6 = titles[5];
          const validSlot6 = ['Repositories & Data Layer', 'Data Layer', 'Testing'];
          expect(
            validSlot6.contains(slot6),
            isTrue,
            reason: '${_skillLabel(stack)}: section 6 must be one of $validSlot6, '
                'found "$slot6"',
          );

          if (slot6 == 'Testing') {
            // Group B shape: no slot-B section; Testing lands at 6, and a
            // Performance section fills the numbering gap at 8.
            expect(
              _groupB.contains(stack),
              isTrue,
              reason: '${_skillLabel(stack)}: has "Testing" at section 6 (the '
                  'no-slot-B layout) but "$stack" is not in the '
                  'Performance-bearing group $_groupB',
            );
            expect(titles[6], 'Code Quality (Linter & Warnings)',
                reason: '${_skillLabel(stack)}: section 7 diverged');
            expect(titles[7], 'Performance',
                reason: '${_skillLabel(stack)}: section 8 diverged (expected '
                    'Performance for group-B stack "$stack")');
          } else {
            // Group A shape: has a slot-B section; Testing/Code Quality follow
            // it, and there is no Performance section.
            expect(
              _groupA.contains(stack),
              isTrue,
              reason: '${_skillLabel(stack)}: has slot-B section "$slot6" but '
                  '"$stack" is not in group $_groupA',
            );
            expect(titles[6], 'Testing', reason: '${_skillLabel(stack)}: section 7 diverged');
            expect(titles[7], 'Code Quality (Linter & Warnings)',
                reason: '${_skillLabel(stack)}: section 8 diverged');
          }
        });
      }

      test('Performance appears only in react/angular/angularjs', () {
        for (final stack in _allStacks) {
          final titles = headings[stack]!.map((h) => h.title).toSet();
          final hasPerformance = titles.contains('Performance');
          final expected = _groupB.contains(stack);
          expect(
            hasPerformance,
            expected,
            reason: '${_skillLabel(stack)} ${hasPerformance ? "has" : "is missing"} a '
                'Performance section; expected presence to be $expected '
                '(Performance is only valid for $_groupB)',
          );
        }
      });

      test('sections 9..15 are byte-identical across all six skills', () {
        for (final stack in _allStacks) {
          final titles = headings[stack]!.map((h) => h.title).toList();
          final tail = titles.sublist(8, 15);
          expect(
            tail,
            _canonicalTail,
            reason:
                '${_skillLabel(stack)}: sections 9..15 diverged from the canonical '
                'tail.\n  expected: $_canonicalTail\n  found:    $tail',
          );
        }
      });
    });

    group('invariant 3: unnumbered Appendix: Scoring Methodology + Report Metadata, '
        'after section 15', () {
      for (final stack in _allStacks) {
        test(stack, () {
          final c = content[stack]!;
          final section15 = headings[stack]!.last;
          expect(
            section15.number == 15 && section15.title == 'Appendix: Evidence Index',
            isTrue,
            reason: '${_skillLabel(stack)}: last numbered section must be '
                '"## 15. Appendix: Evidence Index", found '
                '"## ${section15.number}. ${section15.title}"',
          );

          final scoringIdx = c.indexOf('## Appendix: Scoring Methodology');
          final metadataIdx = c.indexOf('## Report Metadata');
          expect(
            scoringIdx,
            isNot(-1),
            reason: '${_skillLabel(stack)}: missing unnumbered '
                '"## Appendix: Scoring Methodology" heading',
          );
          expect(
            metadataIdx,
            isNot(-1),
            reason: '${_skillLabel(stack)}: missing unnumbered "## Report Metadata" heading',
          );

          final section15Idx = c.indexOf('## 15. ${section15.title}');
          expect(
            section15Idx < scoringIdx && scoringIdx < metadataIdx,
            isTrue,
            reason: '${_skillLabel(stack)}: expected order section 15 → '
                '"Appendix: Scoring Methodology" → "Report Metadata", found '
                'offsets $section15Idx, $scoringIdx, $metadataIdx',
          );

          // Confirm both trailing blocks are genuinely unnumbered (not
          // matched as one of the 1..15 numbered headings).
          final numberedTitles = headings[stack]!.map((h) => h.title).toSet();
          expect(
            numberedTitles.contains('Appendix: Scoring Methodology'),
            isFalse,
            reason: '${_skillLabel(stack)}: "Appendix: Scoring Methodology" must stay '
                'unnumbered (no "## N." prefix)',
          );
          expect(
            numberedTitles.contains('Report Metadata'),
            isFalse,
            reason: '${_skillLabel(stack)}: "Report Metadata" must stay unnumbered '
                '(no "## N." prefix)',
          );
        });
      }
    });

    group('invariant 4: exactly one "> **Test Coverage:**" line, before section 3', () {
      for (final stack in _allStacks) {
        test(stack, () {
          final c = content[stack]!;
          const marker = '> **Test Coverage:**';
          final count = marker.allMatches(c).length;
          expect(
            count,
            1,
            reason: '${_skillLabel(stack)}: expected exactly one "$marker" line, '
                'found $count',
          );

          final markerIdx = c.indexOf(marker);
          final section3 = headings[stack]!.firstWhere((h) => h.number == 3);
          final section3Idx = c.indexOf('## 3. ${section3.title}');
          expect(
            markerIdx < section3Idx,
            isTrue,
            reason: '${_skillLabel(stack)}: "$marker" must appear before section 3 '
                '("${section3.title}"), but it appears after',
          );
        });
      }
    });

    group('invariant 5: Testing section carries exactly one Code Coverage + one '
        'Coverage Breakdown field, between Score and Key Findings', () {
      for (final stack in _allStacks) {
        test(stack, () {
          final c = content[stack]!;

          final codeCoverageCount = '**Code Coverage:**'.allMatches(c).length;
          expect(
            codeCoverageCount,
            1,
            reason: '${_skillLabel(stack)}: expected exactly one "**Code Coverage:**" '
                'field in the whole report, found $codeCoverageCount',
          );
          final breakdownCount = '**Coverage Breakdown:**'.allMatches(c).length;
          expect(
            breakdownCount,
            1,
            reason: '${_skillLabel(stack)}: expected exactly one '
                '"**Coverage Breakdown:**" field in the whole report, found '
                '$breakdownCount',
          );

          final testing = headings[stack]!.firstWhere(
            (h) => h.title == 'Testing',
            orElse: () =>
                throw StateError('${_skillLabel(stack)}: no "Testing" section found'),
          );
          final range = _sectionRange(lines[stack]!, '## ${testing.number}. Testing');
          final body = lines[stack]!.sublist(range.start, range.end).join('\n');

          final scoreIdx = body.indexOf('**Score:**');
          final codeCoverageIdx = body.indexOf('**Code Coverage:**');
          final breakdownIdx = body.indexOf('**Coverage Breakdown:**');
          final keyFindingsIdx = body.indexOf('### Key Findings');

          expect(
            scoreIdx != -1 && codeCoverageIdx != -1 && breakdownIdx != -1 && keyFindingsIdx != -1,
            isTrue,
            reason: '${_skillLabel(stack)}: Testing section is missing one of '
                '**Score:**/**Code Coverage:**/**Coverage Breakdown:**/### Key Findings',
          );
          expect(
            scoreIdx < codeCoverageIdx && codeCoverageIdx < breakdownIdx && breakdownIdx < keyFindingsIdx,
            isTrue,
            reason:
                '${_skillLabel(stack)}: Testing section field order diverged. Expected '
                '**Score:** < **Code Coverage:** < **Coverage Breakdown:** < '
                '### Key Findings, found offsets $scoreIdx, $codeCoverageIdx, '
                '$breakdownIdx, $keyFindingsIdx (relative to the Testing section)',
          );
        });
      }
    });

    group('invariant 6: exactly one "### Harness Coverage", no bare "### Coverage"', () {
      for (final stack in _allStacks) {
        test(stack, () {
          final fileLines = lines[stack]!;
          final harnessCoverageCount = fileLines.where((l) => l == '### Harness Coverage').length;
          expect(
            harnessCoverageCount,
            1,
            reason: '${_skillLabel(stack)}: expected exactly one "### Harness Coverage" '
                'heading, found $harnessCoverageCount',
          );
          final bareCoverageCount = fileLines.where((l) => l == '### Coverage').length;
          expect(
            bareCoverageCount,
            0,
            reason: '${_skillLabel(stack)}: found a bare "### Coverage" heading — it '
                'must be "### Harness Coverage" (a bare "Coverage" heading collides '
                'with the "Test Coverage" scorecard label)',
          );
        });
      }
    });

    group('invariant 7: scoring-legend blockquote is byte-identical, en dash + middle dot',
        () {
      for (final stack in _allStacks) {
        test(stack, () {
          final fileLines = lines[stack]!;
          final matches = fileLines.where((l) => l == _scoringLegend).length;
          expect(
            matches,
            1,
            reason: '${_skillLabel(stack)}: expected exactly one occurrence of the '
                'canonical scoring-legend line (with U+2013 en dash and U+00B7 '
                'middle dot):\n  $_scoringLegend\nbut found $matches. Check for '
                'plain ASCII hyphens/dots or reworded text.',
          );
        });
      }
    });

    group('invariant 8: no "Quality Index" anywhere', () {
      for (final stack in _allStacks) {
        test(stack, () {
          final c = content[stack]!;
          expect(
            c.contains('Quality Index'),
            isFalse,
            reason: '${_skillLabel(stack)}: found "Quality Index" — that section was '
                'removed as a byte-for-byte duplicate of the At-a-Glance Scorecard '
                '(see docs/report-template-canonical.md)',
          );
        });
      }
    });

    group('invariant 9: scorecard table has no Weight column', () {
      for (final stack in _allStacks) {
        test(stack, () {
          final scorecard = headings[stack]!.firstWhere((h) => h.number == 2);
          final range = _sectionRange(lines[stack]!, '## 2. ${scorecard.title}');
          final body = lines[stack]!.sublist(range.start, range.end).join('\n');
          expect(
            body.contains('Weight'),
            isFalse,
            reason: '${_skillLabel(stack)}: the At-a-Glance Scorecard table must not '
                'carry a Weight column — weights live only in the Appendix: '
                'Scoring Methodology',
          );
        });
      }
    });

    group('invariant 10: Scoring Methodology weight rows parse, sum to 1.00, and '
        'match the correct weight family', () {
      for (final stack in _allStacks) {
        test(stack, () {
          final fileLines = lines[stack]!;
          final range = _sectionRange(fileLines, '## Appendix: Scoring Methodology');
          final weights = _parseWeightRows(fileLines.sublist(range.start, range.end));

          expect(
            weights.isNotEmpty,
            isTrue,
            reason: '${_skillLabel(stack)}: could not parse any '
                '"| Section | Weight |" rows out of Appendix: Scoring Methodology',
          );

          final sum = weights.values.fold<double>(0, (a, b) => a + b);
          expect(
            sum,
            closeTo(1.00, 0.001),
            reason: '${_skillLabel(stack)}: Scoring Methodology weights sum to '
                '$sum, expected 1.00. Rows: $weights',
          );

          final actualSorted = weights.values.toList()..sort();
          final expected = _groupA.contains(stack) ? _groupAWeights : _groupBWeights;
          final expectedGroupName = _groupA.contains(stack) ? 'A' : 'B';
          final expectedSorted = List<double>.from(expected)..sort();

          expect(
            actualSorted.length,
            expectedSorted.length,
            reason: '${_skillLabel(stack)}: expected ${expectedSorted.length} weight '
                'rows for weight family $expectedGroupName, found '
                '${actualSorted.length}. Rows: $weights',
          );
          for (var i = 0; i < expectedSorted.length; i++) {
            expect(
              actualSorted[i],
              closeTo(expectedSorted[i], 0.0001),
              reason: '${_skillLabel(stack)}: weight set diverged from weight family '
                  '$expectedGroupName ($stack is in '
                  '${_groupA.contains(stack) ? _groupA : _groupB}).\n'
                  '  expected weights (sorted): $expectedSorted\n'
                  '  found weights (sorted):    $actualSorted\n'
                  '  rows: $weights',
            );
          }
        });
      }
    });

    group('invariant 11: header carries **Project:** metadata block and '
        '> **Exclusions:** blockquote', () {
      for (final stack in _allStacks) {
        test(stack, () {
          final c = content[stack]!;
          final firstHeadingIdx = c.indexOf('## 1. ');
          expect(
            firstHeadingIdx,
            isNot(-1),
            reason: '${_skillLabel(stack)}: could not find "## 1. " to bound the header',
          );
          final header = c.substring(0, firstHeadingIdx);
          expect(
            header.contains('**Project:**'),
            isTrue,
            reason: '${_skillLabel(stack)}: header is missing the '
                '"**Project:**" metadata block',
          );
          expect(
            header.contains('> **Exclusions:**'),
            isTrue,
            reason: '${_skillLabel(stack)}: header is missing the '
                '"> **Exclusions:**" blockquote',
          );
        });
      }
    });
  });
}
