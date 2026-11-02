"""Tests for the graph metrics script: each builds a tree in a temporary directory and runs the CLI.

The script ships inside references/graph-metrics-script.md, so the tests cut it out by the same marker
lines the audit's first step uses and exercise exactly what ships.

Usage, from skills/architecture-audit:
    python3 -m unittest discover -s tests -p "test_*.py" -v
"""
import atexit
import datetime as dt
import importlib.util
import json
import os
import pathlib
import random
import shutil
import subprocess
import sys
import tempfile
import unittest

REFERENCE = pathlib.Path(__file__).resolve().parent.parent / 'references' / 'graph-metrics-script.md'


def extract_script(text):
    body = text.split('<!-- graph_metrics.py:begin -->', 1)[1].split('<!-- graph_metrics.py:end -->', 1)[0]
    return body.split('```python\n', 1)[1].rsplit('\n```', 1)[0] + '\n'


_EXTRACTED = pathlib.Path(tempfile.mkdtemp(prefix='graph-metrics-script'))
atexit.register(shutil.rmtree, _EXTRACTED, True)
SCRIPT = _EXTRACTED / 'graph_metrics.py'
with open(SCRIPT, 'w', encoding='utf-8', newline='\n') as _handle:
    _handle.write(extract_script(REFERENCE.read_text(encoding='utf-8')))
GIT_ENV = dict(os.environ, GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM='1',
               GIT_AUTHOR_NAME='Ann', GIT_AUTHOR_EMAIL='ann@example.com',
               GIT_COMMITTER_NAME='Ann', GIT_COMMITTER_EMAIL='ann@example.com')


def load_script(test):
    """The script imported as a module, for unit tests of single functions."""
    spec = importlib.util.spec_from_file_location('graph_metrics', SCRIPT)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module  # Python 3.9 dataclasses look their module up here
    test.addCleanup(sys.modules.pop, spec.name, None)
    spec.loader.exec_module(module)
    return module


class Case(unittest.TestCase):
    """A temporary repository with an artifacts directory at <root>/art."""

    def setUp(self):
        self.root = pathlib.Path(tempfile.mkdtemp(prefix='graph'))
        self.addCleanup(shutil.rmtree, self.root)
        self.art = self.root / 'art'
        self.art.mkdir()

    def write(self, tree):
        for path, text in tree.items():
            target = self.root / path
            target.parent.mkdir(parents=True, exist_ok=True)
            if isinstance(text, bytes):
                target.write_bytes(text)
            else:
                target.write_text(text, encoding='utf-8')

    def files_tsv(self, suffixes, gen=(), lines=None, skip=()):
        """files.tsv for every file with one of the suffixes; `lines` overrides counts."""
        rows = []
        for path in sorted(p.relative_to(self.root).as_posix() for p in self.root.rglob('*') if p.is_file()):
            if path.endswith(suffixes) and not path.startswith('art/') and path not in skip:
                count = (lines or {}).get(path, (self.root / path).read_bytes().count(b'\n'))
                rows.append(f'{path}\t{count}\t{"gen" if path in gen else "src"}\n')
        (self.art / 'files.tsv').write_text(''.join(rows), encoding='utf-8')

    def module_map(self, rows):
        (self.art / 'module_map.tsv').write_text(''.join('\t'.join(row) + '\n' for row in rows), encoding='utf-8')

    def cli(self, *args, ok=True, env=None):
        result = subprocess.run([sys.executable, '-B', str(SCRIPT), *args], capture_output=True, text=True,
                                env=env or GIT_ENV)
        if ok:
            self.assertEqual(result.returncode, 0, result.stderr)
        return result

    def metrics(self, lang, *extra, ok=True, git=False, env=None):
        flags = () if git else ('--no-git',)
        self.last = self.cli('metrics', '--root', str(self.root), '--dir', str(self.art), '--lang', lang,
                             *flags, *extra, ok=ok, env=env)
        return self.metrics_json()

    def metrics_json(self):
        path = self.art / 'metrics.json'
        return json.loads(path.read_text(encoding='utf-8')) if path.exists() else None

    def edges(self):
        rows = (self.art / 'edges.tsv').read_text(encoding='utf-8').splitlines()
        return {(a, b): int(line) for a, b, line in (row.split('\t') for row in rows)}

    def module_edges(self):
        rows = (self.art / 'module_edges.tsv').read_text(encoding='utf-8').splitlines()
        self.assertEqual(rows[0].split('\t'), ['source_file', 'line', 'source_module', 'source_role',
                                               'target_file', 'target_module', 'target_role', 'status'])
        return [tuple(row.split('\t')) for row in rows[1:]]

    def git(self, *args, cwd=None, env=None):
        return subprocess.run(['git', *args], cwd=cwd or self.root, env=env or GIT_ENV, check=True,
                              capture_output=True, text=True).stdout

    def commit(self, message, tree=None, cwd=None, env=None):
        if tree:
            self.write(tree)
        self.git('add', '-A', cwd=cwd)
        self.git('commit', '-q', '--allow-empty', '-m', message, cwd=cwd, env=env)


class DartExtraction(Case):
    def test_multiline_conditional_and_string_aware_directives(self):
        ghosts = {f'lib/ghost{i}.dart': '//\n' for i in range(1, 8)}
        self.write({**ghosts, 'pubspec.yaml': 'name: app\n',
                    'lib/b.dart': '//\n', 'lib/stub.dart': '//\n', 'lib/io_impl.dart': '//\n',
                    'lib/web_impl.dart': '//\n', 'lib/e.dart': '//\n',
                    'lib/a.dart': (
                        "// import 'ghost1.dart';\n"
                        "/* import 'ghost2.dart';\n"
                        "   /* nested */ import 'ghost3.dart'; */\n"
                        "import 'package:app/b.dart'\n"
                        "    show B,\n"
                        "        C;\n"
                        "import 'stub.dart'\n"
                        "    if (dart.library.io) 'io_impl.dart'\n"
                        "    if (dart.library.js_interop) 'web_impl.dart';\n"
                        "export 'e.dart' hide X;\n"
                        "const s = \"import 'ghost4.dart';\";\n"
                        "const url = 'https://example.com'; // import 'ghost5.dart';\n"
                        "const t = '''\nimport 'ghost6.dart';\n''';\n"
                        "const i = \"${f('x')} import 'ghost7.dart'\";\n")})
        self.files_tsv(('.dart',))
        self.module_map([('app', 'shared-common', 'no', 'lib', '-')])
        self.metrics('dart')
        from_a = {b: line for (a, b), line in self.edges().items() if a == 'lib/a.dart'}
        self.assertEqual(from_a, {'lib/b.dart': 4, 'lib/stub.dart': 7, 'lib/io_impl.dart': 7,
                                  'lib/web_impl.dart': 7, 'lib/e.dart': 10})

    def test_packages_platform_externals_and_unresolved(self):
        self.write({'pubspec.yaml': 'name: app\n', 'packages/ui/pubspec.yaml': "name: 'ui'\n",
                    'packages/ui/lib/ui.dart': '//\n',
                    'packages/ui/test/helper.dart': '//\n',
                    'lib/x.dart': ("import 'dart:io';\nimport 'dart:async';\nimport 'dart:html';\n"
                                   "import 'package:ui/ui.dart';\nimport 'package:flutter/material.dart';\n"
                                   "import 'package:collection/collection.dart';\nimport 'missing.dart';\n"
                                   "import '../packages/ui/test/helper.dart';\n"
                                   "import 'package:flutter/services.dart';\n"),
                    'lib/y.dart': "import 'dart:io';\nimport 'x.dart';\nimport 'package:flutter/widgets.dart';\n"})
        self.files_tsv(('.dart',), skip={'packages/ui/test/helper.dart'})
        self.module_map([('app', 'root', 'no', 'lib', '-'), ('ui', 'shared-common', 'yes', 'packages/ui', 'nonsrc')])
        m = self.metrics('dart')
        self.assertIn(('lib/x.dart', 'packages/ui/lib/ui.dart'), self.edges())
        self.assertEqual(m['platformImportsByModule'], {'app': {'dart:html': 1, 'dart:io': 2}})
        self.assertEqual(m['externalImportsByModule'],
                         {'app': {'collection': {'files': 1, 'example': 'lib/x.dart:6'},
                                  'flutter': {'files': 2, 'example': 'lib/x.dart:5'}}})
        self.assertEqual(m['totals']['unresolvedInternal'], 1)  # the test helper exists, so only missing.dart
        self.assertEqual(m['totals']['unresolvedExamples'], ['lib/x.dart:7 missing.dart'])


class TsExtraction(Case):
    def test_wrapped_and_every_import_form(self):
        names = ('a', 'side', 're', 'named', 'req', 'dyn', 'after', 'ghost1', 'ghost2', 'ghost3', 'ghost4')
        self.write({**{f'src/{n}.ts': 'export {};\n' for n in names},
                    'src/main.ts': ("import {\n  a,\n  b,\n} from './a';\n"
                                    "import './side';\n"
                                    "export * from './re';\n"
                                    'export { x } from "./named";\n'
                                    "const r = require('./req');\n"
                                    "const d = await import('./dyn');\n"
                                    "// import './ghost1';\n"
                                    "/* import './ghost2'; */\n"
                                    "const s = \"import './ghost3'\";\n"
                                    "const q = /'/.test(s); import './after';\n"
                                    "const t = `${'x'} import './ghost4'`;\n")})
        self.files_tsv(('.ts',))
        self.module_map([('app', 'shared-common', 'no', 'src', '-')])
        self.metrics('ts')
        from_main = {b: line for (a, b), line in self.edges().items() if a == 'src/main.ts'}
        self.assertEqual(from_main, {'src/a.ts': 4, 'src/side.ts': 5, 'src/re.ts': 6, 'src/named.ts': 7,
                                     'src/req.ts': 8, 'src/dyn.ts': 9, 'src/after.ts': 13})

    def test_tsconfig_extends_nested_config_and_longest_alias(self):
        self.write({
            'tsconfig.base.json': ('{\n  // shared\n  "compilerOptions": {\n    "baseUrl": ".",\n'
                                   '    "paths": {"@/*": ["src/*"], "@/components/*": ["src/shared/ui/*"],'
                                   ' "@exact": ["src/exact.ts"],},\n  },\n}\n'),
            'tsconfig.json': '{ "extends": "./tsconfig.base.json" }\n',
            'src/components/thing.ts': 'export {};\n',
            'src/shared/ui/thing.ts': 'export {};\n',
            'src/exact.ts': 'export {};\n',
            'src/app.ts': "import '@/components/thing';\nimport '@exact';\nimport '@/exact';\n",
            # nested config: its own baseUrl and paths replace the inherited ones
            'apps/web/tsconfig.json': ('{ "extends": "../../tsconfig.base", "compilerOptions":'
                                       ' { "baseUrl": ".", "paths": { "~/*": ["src/*"] } } }\n'),
            'apps/web/src/page.ts': "import '~/util';\n",
            'apps/web/src/util.ts': 'export {};\n',
            # inherited baseUrl, own paths: tsc resolves them against the inherited baseUrl
            'libs/core/tsconfig.json': ('{ "extends": "../../tsconfig.base.json", "compilerOptions":'
                                        ' { "paths": { "core/*": ["libs/core/lib/*"] } } }\n'),
            'libs/core/lib/one.ts': "import 'core/two';\n",
            'libs/core/lib/two.ts': 'export {};\n',
        })
        self.files_tsv(('.ts',))
        self.module_map([('all', 'shared-common', 'no', '.', '-')])
        self.metrics('ts')
        edges = self.edges()
        self.assertIn(('src/app.ts', 'src/shared/ui/thing.ts'), edges)
        self.assertNotIn(('src/app.ts', 'src/components/thing.ts'), edges)
        self.assertIn(('src/app.ts', 'src/exact.ts'), edges)
        self.assertIn(('apps/web/src/page.ts', 'apps/web/src/util.ts'), edges)
        self.assertIn(('libs/core/lib/one.ts', 'libs/core/lib/two.ts'), edges)

    def test_esm_js_specifier_resolves_to_source(self):
        self.write({'src/a.ts': "import { u } from './util.js';\nimport C from './comp.jsx';\n",
                    'src/util.ts': 'export const u = 1;\n', 'src/comp.tsx': 'export default 1;\n'})
        self.files_tsv(('.ts', '.tsx'))
        self.module_map([('all', 'shared-common', 'no', 'src', '-')])
        self.metrics('ts')
        self.assertEqual(set(self.edges()), {('src/a.ts', 'src/util.ts'), ('src/a.ts', 'src/comp.tsx')})

    def test_bare_package_entry_is_public_and_subpaths_are_deep(self):
        self.write({
            'packages/ui/package.json': json.dumps({'name': '@acme/ui', 'exports': {
                '.': {'types': './src/index.ts', 'import': './dist/index.js'}}}),
            'packages/ui/src/index.ts': "export * from './button';\n",
            'packages/ui/src/button.ts': 'export const B = 1;\n',
            'packages/kit/package.json': json.dumps({'name': 'kit', 'main': 'dist/index.js'}),
            'packages/kit/src/index.ts': 'export {};\n',
            'app/page.ts': ("import { B } from '@acme/ui';\nimport { B as C } from '@acme/ui/src/button';\n"
                            "import 'kit';\nimport 'react';\nimport fs from 'node:fs';\nimport path from 'path';\n"),
        })
        self.files_tsv(('.ts',))
        self.module_map([('app', 'feature', 'no', 'app', '-'), ('ui', 'shared-common', 'yes', 'packages/ui', 'nonsrc'),
                         ('kit', 'shared-common', 'yes', 'packages/kit', 'nonsrc')])
        m = self.metrics('ts')
        self.assertEqual(m['structuralCoupling']['checkedEdges'], 3)
        self.assertEqual(m['deepEdgeExamples'], ['app/page.ts:2 -> packages/ui/src/button.ts'])
        self.assertEqual(m['externalImportsByModule'], {'app': {'react': {'files': 1, 'example': 'app/page.ts:4'}}})

    def test_declared_exports_subpaths_are_public(self):
        self.write({
            'package.json': json.dumps({'name': 'web', 'private': True, 'workspaces': ['packages/*']}),
            'packages/ui/package.json': json.dumps({'name': '@acme/ui', 'exports': {
                '.': './src/index.ts', './button': './src/button.ts',
                './icons/*': {'types': './src/icons/*.ts'}, './hidden/*': None,
                './card': {'types': './dist/card.d.ts', 'import': './dist/card.js'}}}),
            'packages/ui/src/index.ts': "export * from './button';\n", 'packages/ui/src/button.ts': 'export const B = 1;\n',
            'packages/ui/src/internal.ts': 'export const I = 1;\n', 'packages/ui/src/icons/star.ts': 'export {};\n',
            'packages/ui/src/hidden/x.ts': 'export {};\n', 'packages/ui/hidden/x.ts': 'export {};\n',
            'packages/ui/src/card.ts': 'export {};\n',
            'src/main.ts': ("import { B } from '@acme/ui/button';\nimport { A } from '@acme/ui';\n"
                            "import '@acme/ui/icons/star';\nimport '@acme/ui/src/internal';\nimport '@acme/ui/hidden/x';\n"
                            "import '@acme/ui/card';\n"),  # declared, but its target is build output
        })
        self.files_tsv(('.ts',))
        for surface in ('nonsrc', 'packages/ui/src/index.ts'):
            with self.subTest(surface=surface):
                self.module_map([('root', 'root', 'no', 'src', '-'), ('ui', 'foundation', 'yes', 'packages/ui', surface)])
                m = self.metrics('ts')
                deep = ['src/main.ts:4 -> packages/ui/src/internal.ts']
                if surface != 'nonsrc':  # a null exports key gives no target, so the plain path decides
                    deep.append('src/main.ts:5 -> packages/ui/hidden/x.ts')
                self.assertEqual(m['deepEdgeExamples'], deep)
                self.assertEqual(m['structuralCoupling']['checkedEdges'], 6)

    def test_exports_decide_publicness_through_tsconfig_aliases(self):
        self.write({
            'tsconfig.json': json.dumps({'compilerOptions': {'baseUrl': '.', 'paths': {
                '@acme/ui': ['packages/ui/src/index.ts'], '@acme/ui/*': ['packages/ui/src/*'],
                '@acme/plain/*': ['packages/plain/src/*'], '@acme/nodot': ['packages/nodot/src/index.ts'],
                '@/*': ['app/*']}}}),
            'packages/ui/package.json': json.dumps({'name': '@acme/ui', 'exports': {
                '.': './src/index.ts', './button': './src/button.ts', './icons/*': './src/icons/*.ts'}}),
            'packages/ui/src/index.ts': 'export {};\n', 'packages/ui/src/button.ts': 'export {};\n',
            'packages/ui/src/icons/star.ts': 'export {};\n', 'packages/ui/src/internal/x.ts': 'export {};\n',
            'packages/plain/package.json': json.dumps({'name': '@acme/plain'}),
            'packages/plain/src/thing.ts': 'export {};\n',
            'packages/nodot/package.json': json.dumps({'name': '@acme/nodot', 'exports': {'./a': './src/a.ts'}}),
            'packages/nodot/src/index.ts': 'export {};\n',
            'app/components/x.ts': 'export {};\n',
            'app/page.ts': ("import '@acme/ui';\nimport '@acme/ui/button';\nimport '@acme/ui/icons/star';\n"
                            "import '@acme/ui/internal/x';\nimport '@acme/plain/thing';\nimport '@/components/x';\n"
                            "import '@acme/nodot';\n"),
        })
        self.files_tsv(('.ts',))
        # `nonsrc` calls a file under src/ deep, so only a declaration in `exports` makes an edge public
        self.module_map([('app', 'feature', 'no', 'app', '-'), ('ui', 'shared-common', 'yes', 'packages/ui', 'nonsrc'),
                         ('plain', 'shared-common', 'yes', 'packages/plain', 'nonsrc'),
                         ('nodot', 'shared-common', 'yes', 'packages/nodot', 'nonsrc')])
        m = self.metrics('ts')
        self.assertEqual(m['deepEdgeExamples'], ['app/page.ts:4 -> packages/ui/src/internal/x.ts',
                                                 'app/page.ts:5 -> packages/plain/src/thing.ts',
                                                 'app/page.ts:7 -> packages/nodot/src/index.ts'])
        self.assertEqual(m['structuralCoupling']['checkedEdges'], 6)

    def test_alias_subpath_exports_does_not_declare_is_left_to_the_module_map(self):
        self.write({
            'tsconfig.json': json.dumps({'compilerOptions': {'baseUrl': '.', 'paths': {'@acme/ui/*': ['packages/ui/*']}}}),
            'packages/ui/package.json': json.dumps({'name': '@acme/ui', 'exports': {'.': './index.ts'}}),
            'packages/ui/index.ts': 'export {};\n', 'packages/ui/private/y.ts': 'export {};\n',
            'app/page.ts': "import '@acme/ui/private/y';\n",
        })
        self.files_tsv(('.ts',))
        self.module_map([('app', 'feature', 'no', 'app', '-'), ('ui', 'shared-common', 'yes', 'packages/ui', 'nonsrc')])
        m = self.metrics('ts')
        # `nonsrc` calls a file outside src/ public; it is the module map that decides when exports is silent.
        self.assertEqual(m['deepEdgeExamples'], [])
        self.assertEqual(m['structuralCoupling']['checkedEdges'], 1)

    def test_template_literals_without_interpolation_are_plain_specifiers(self):
        self.write({'src/a.ts': 'export {};\n', 'src/b.ts': 'export {};\n', 'src/c/x.ts': 'export {};\n',
                    'src/main.ts': ("const a = await import(`./a`);\nconst b = require(`./b`);\n"
                                    "const x = 'x'; const c = await import(`./c/${x}`);\n"
                                    "const d = await import(`./nope`);\n"
                                    "const f = `import('./c/x')`;\n")})
        self.files_tsv(('.ts',))
        self.module_map([('all', 'shared-common', 'no', 'src', '-')])
        m = self.metrics('ts')
        self.assertEqual({b: line for (a, b), line in self.edges().items() if a == 'src/main.ts'},
                         {'src/a.ts': 1, 'src/b.ts': 2})
        self.assertEqual(m['totals']['unresolvedExamples'], ['src/main.ts:4 ./nope'])

    def test_package_imports_resolve_through_the_nearest_package_json(self):
        self.write({
            'package.json': json.dumps({'name': 'web', 'imports': {
                '#lib/*': './src/lib/*.ts', '#config': {'types': './src/config.ts', 'default': './dist/config.js'},
                '#ui/*': './packages/ui/src/*.ts', '#ext': 'zod', '#none': None}}),
            'src/lib/util.ts': 'export {};\n', 'src/config.ts': 'export {};\n', 'packages/ui/src/button.ts': 'export {};\n',
            'src/app.ts': ("import '#lib/util';\nimport '#config';\nimport '#ui/button';\nimport '#missing';\n"
                           "import '#lib/gone';\nimport '#ext';\nimport '#none';\nimport '/abs/x';\n"),
            'packages/inner/package.json': json.dumps({'name': 'inner'}),  # its own scope, without imports
            'packages/inner/src/x.ts': "import '#lib/util';\n",
            'packages/own/package.json': json.dumps({'name': 'own', 'imports': {'#o': './o.ts'}}),
            'packages/own/o.ts': 'export {};\n',
            'packages/own/index.ts': "import '#o';\nimport '#lib/util';\n",  # the nearest imports field is its own
        })
        self.files_tsv(('.ts',))
        self.module_map([('app', 'feature', 'no', 'src', '-'), ('ui', 'shared-common', 'yes', 'packages/ui', 'nonsrc'),
                         ('own', 'shared-common', 'no', 'packages/own', '-'), ('inner', 'shared-common', 'no', 'packages/inner', '-')])
        m = self.metrics('ts')
        self.assertEqual({(a, b) for (a, b) in self.edges() if a != 'packages/own/o.ts'},
                         {('src/app.ts', 'src/lib/util.ts'), ('src/app.ts', 'src/config.ts'),
                          ('src/app.ts', 'packages/ui/src/button.ts'), ('packages/own/index.ts', 'packages/own/o.ts')})
        # the nearest package.json is the scope: a parent package's mapping is never inherited
        self.assertEqual(m['totals']['unresolvedExamples'], [
            'packages/inner/src/x.ts:1 #lib/util', 'packages/own/index.ts:2 #lib/util', 'src/app.ts:4 #missing',
            'src/app.ts:5 #lib/gone', 'src/app.ts:7 #none'])
        self.assertEqual(m['externalImportsByModule']['app'], {'zod': {'files': 1, 'example': 'src/app.ts:6'}})
        self.assertEqual(m['deepEdgeExamples'], ['src/app.ts:3 -> packages/ui/src/button.ts'])  # never public

    def test_tsconfig_paths_map_hash_specifiers_before_package_imports(self):
        self.write({'tsconfig.json': json.dumps({'compilerOptions': {'baseUrl': '.', 'paths': {'#app/*': ['src/*']}}}),
                    'package.json': json.dumps({'name': 'web', 'imports': {'#app/*': './other/*.ts', '#pkg': './src/pkg.ts'}}),
                    'src/a.ts': "import '#app/b';\nimport '#pkg';\nimport '#app/gone';\n", 'src/b.ts': 'export {};\n',
                    'src/pkg.ts': 'export {};\n', 'other/b.ts': 'export {};\n'})
        self.files_tsv(('.ts',))
        self.module_map([('all', 'shared-common', 'no', '.', '-')])
        m = self.metrics('ts')
        self.assertEqual({b for (a, b) in self.edges() if a == 'src/a.ts'}, {'src/b.ts', 'src/pkg.ts'})  # not other/b.ts
        self.assertEqual(m['totals']['unresolvedExamples'], ['src/a.ts:3 #app/gone'])  # the alias matched: no fall back to imports

    def test_node_builtins_are_platform_imports(self):
        self.write({'src/a.ts': ("import fs from 'fs';\nimport 'node:test';\nimport p from 'node:path';\n"
                                 "import { readFile } from 'fs/promises';\nconst cp = require('child_process');\n"
                                 "import path from 'path';\nimport 'events';\nimport r from 'react';\n"),
                    'src/b.ts': "import fs from 'fs';\nimport os from 'node:os';\nimport 'dns/promises';\nimport 'fs-extra';\n"})
        self.files_tsv(('.ts',))
        self.module_map([('all', 'shared-common', 'no', 'src', '-')])
        m = self.metrics('ts')
        self.assertEqual(m['platformImportsByModule'], {'all': {
            'node:fs': 2, 'node:test': 1, 'node:path': 1, 'node:fs/promises': 1, 'node:child_process': 1, 'node:os': 1,
            'node:dns/promises': 1}})  # a subpath is recorded under its own name, like fs/promises
        self.assertEqual(m['externalImportsByModule'], {'all': {
            'react': {'files': 1, 'example': 'src/a.ts:8'}, 'fs-extra': {'files': 1, 'example': 'src/b.ts:4'}}})

    def test_unresolved_alias_is_counted_not_linked(self):
        self.write({'tsconfig.json': '{"compilerOptions": {"paths": {"@/*": ["./src/*"]}}}',
                    'src/a.ts': ("import '@/missing/thing';\nimport './nope';\nimport './styles.css';\n"
                                 "import '@/real';\n"),
                    'src/real.ts': 'export {};\n', 'src/styles.css': 'body {}\n'})
        self.files_tsv(('.ts',))
        self.module_map([('all', 'shared-common', 'no', 'src', '-')])
        m = self.metrics('ts')
        self.assertEqual(set(self.edges()), {('src/a.ts', 'src/real.ts')})
        self.assertEqual(m['totals']['unresolvedInternal'], 2)
        self.assertEqual(m['totals']['unresolvedExamples'], ['src/a.ts:1 @/missing/thing', 'src/a.ts:2 ./nope'])


class PythonExtraction(Case):
    def test_imports_roots_and_type_checking(self):
        self.write({
            'app/__init__.py': '',
            'app/shared/__init__.py': 'VALUE = 1\n',
            'app/shared/utils.py': '', 'app/shared/db.py': '', 'app/shared/types.py': '', 'app/shared/both.py': '',
            'app/main.py': ('import os, requests\n'
                            'import app.shared.db, app.shared.utils\n'
                            'from app.shared import utils, VALUE\n'
                            'from .shared import db\n'
                            'from typing import TYPE_CHECKING\n'
                            'import app.shared.both\n'
                            'if TYPE_CHECKING:\n'
                            '    from app.shared import types\n'
                            '    import app.shared.both\n'
                            'from app.missing import thing\n'
                            'from svc.domain import model\n'),
            'app/broken.py': 'def (:\n',
            'services/api/pyproject.toml': '[project]\nname = "svc"\n',
            'services/api/src/svc/__init__.py': '',
            'services/api/src/svc/domain/__init__.py': '',
            'services/api/src/svc/domain/model.py': '',
        })
        self.files_tsv(('.py',))
        self.module_map([('all', 'shared-common', 'no', '.', '-')])
        m = self.metrics('py')
        from_main = sorted(b for a, b in self.edges() if a == 'app/main.py')
        self.assertEqual(from_main, ['app/shared/__init__.py', 'app/shared/both.py', 'app/shared/db.py',
                                     'app/shared/types.py', 'app/shared/utils.py',
                                     'services/api/src/svc/domain/model.py'])
        self.assertEqual(m['totals']['typeOnlyEdges'], 1)  # types.py; both.py is also imported at runtime
        self.assertEqual(m['totals']['unresolvedExamples'], ['app/main.py:10 app.missing'])
        self.assertEqual(len(m['totals']['parseErrors']), 1)
        self.assertTrue(m['totals']['parseErrors'][0].startswith('app/broken.py: SyntaxError'))
        self.assertEqual(m['externalImportsByModule'], {'all': {'requests': {'files': 1, 'example': 'app/main.py:1'}}})


    def test_platform_modules_are_recorded_by_top_level_name(self):
        self.write({'main.py': ("import sqlite3, os, json\nfrom pathlib import Path\nimport shutil, tempfile\nimport urllib.request\nfrom http import HTTPStatus\n"
                                "import subprocess\nimport ctypes.util\nimport requests\nimport socket\nfrom glob import glob\n"),
                    'socket.py': 'x = 1\n', 'other.py': 'import sqlite3\n'})
        self.files_tsv(('.py',))
        self.module_map([('all', 'shared-common', 'no', '.', '-')])
        m = self.metrics('py')
        self.assertEqual(m['platformImportsByModule'], {'all': {
            'sqlite3': 2, 'os': 1, 'pathlib': 1, 'shutil': 1, 'tempfile': 1, 'glob': 1, 'urllib': 1, 'http': 1,
            'subprocess': 1, 'ctypes': 1}})  # the repo's own socket.py is no platform import
        self.assertEqual(set(self.edges()), {('main.py', 'socket.py')})
        self.assertEqual(m['externalImportsByModule'], {'all': {'requests': {'files': 1, 'example': 'main.py:8'}}})

    def test_every_parse_error_file_is_counted(self):
        self.write({**{f'p/bad{i:02d}.py': 'def (:\n' for i in range(25)}, 'p/ok.py': 'x = 1\n'})
        self.files_tsv(('.py',))
        self.module_map([('all', 'shared-common', 'no', 'p', '-')])
        totals = self.metrics('py')['totals']
        self.assertEqual((len(totals['parseErrors']), totals['parseErrorFiles']), (20, 25))


class ModuleMapValidation(Case):
    TREE = {'pubspec.yaml': 'name: app\n', 'lib/a/a.dart': "import '../b/b.dart';\n", 'lib/b/b.dart': '//\n',
            'lib/c.dart': '//\n'}
    GOOD = [('a', 'feature', 'no', 'lib/a', '-'), ('b', 'feature', 'no', 'lib/b', 'lib/b/b.dart'),
            ('rest', 'shared-common', 'no', 'lib', '-')]

    def rejected(self, rows, message, files=None):
        self.write(self.TREE)
        if files is None:
            self.files_tsv(('.dart',))
        else:
            (self.art / 'files.tsv').write_text(files, encoding='utf-8')
        self.module_map(rows)
        self.metrics('dart', ok=False)
        self.assertNotEqual(self.last.returncode, 0)
        self.assertIn(message, self.last.stderr)
        self.assertFalse((self.art / 'metrics.json').exists())

    def test_unknown_role(self):
        self.rejected(self.GOOD[:2] + [('rest', 'shared', 'no', 'lib', '-')], "unknown role 'shared'")

    def test_physical_must_be_yes_or_no(self):
        self.rejected(self.GOOD[:2] + [('rest', 'shared-common', 'Yes', 'lib', '-')], "got 'Yes'")

    def test_duplicate_path(self):
        self.rejected(self.GOOD + [('again', 'shared-common', 'no', 'lib/', '-')], "repeats the row of module rest")

    def test_dot_and_empty_paths_are_the_same_row(self):
        self.rejected(self.GOOD + [('x', 'shared-common', 'no', '.', '-'), ('y', 'shared-common', 'no', '', '-')],
                      'repeats the row of module x')

    def test_same_name_needs_same_role(self):
        self.rejected(self.GOOD + [('a', 'shared-common', 'no', 'lib/c.dart', '-')], 'different role or physical')

    def test_same_name_needs_same_physical(self):
        self.rejected(self.GOOD + [('a', 'feature', 'yes', 'lib/c.dart', '-')], 'different role or physical')

    def test_same_name_needs_compatible_surface(self):
        self.rejected(self.GOOD + [('b', 'feature', 'no', 'lib/c.dart', '-')], "mixes public surfaces 'list' and '-'")
        self.rejected(self.GOOD + [('rest', 'shared-common', 'no', 'lib/c.dart', 'nonsrc')], "mixes public surfaces")

    def test_public_file_must_be_listed_in_files_tsv(self):
        self.rejected(self.GOOD[:1] + [('b', 'feature', 'no', 'lib/b', 'b.dart')] + self.GOOD[2:],
                      'public file b.dart is not in files.tsv')

    def test_public_file_must_be_repo_relative(self):
        self.rejected(self.GOOD[:1] + [('b', 'feature', 'no', 'lib/b', '/abs/lib/b/b.dart')] + self.GOOD[2:],
                      'is not repo-relative')

    def test_public_file_must_belong_to_its_module(self):
        self.rejected(self.GOOD[:1] + [('b', 'feature', 'no', 'lib/b', 'lib/c.dart')] + self.GOOD[2:],
                      'belongs to another module')

    def test_empty_public_cell(self):
        self.rejected(self.GOOD[:2] + [('rest', 'shared-common', 'no', 'lib', '')], "public is empty")

    def test_one_root_module_name(self):
        self.rejected(self.GOOD[:2] + [('root-c', 'root', 'no', 'lib/c.dart', '-'), ('root-lib', 'root', 'no', 'lib', '-')],
                      "modules root-c, root-lib all have role root; the composition root is one module, so give every "
                      "root row the name 'root'")

    def test_nonsrc_on_a_logical_module_needs_a_src_directory(self):
        self.rejected([('a', 'feature', 'no', 'lib/a', 'nonsrc')] + self.GOOD[1:],
                      "module a: public 'nonsrc' on a logical module (physical=no) needs files under a src/ directory")

    def test_nonsrc_on_a_physical_package_without_src_is_kept(self):
        self.write(self.TREE)
        self.files_tsv(('.dart',))
        self.module_map([('a', 'feature', 'yes', 'lib/a', 'nonsrc')] + self.GOOD[1:])
        self.assertEqual(self.metrics('dart')['modules']['a']['physical'], True)

    def test_logical_module_lists_its_surface_instead_of_nonsrc(self):
        self.write({'pubspec.yaml': 'name: app\n',
                    'lib/main.dart': "import 'features/a/view/a_page.dart';\nimport 'features/b/view/b_page.dart';\n",
                    'lib/features/a/view/a_page.dart': ("import '../../../core/data/secret_repo_impl.dart';\n"
                                                        "import '../../../core/x/internal.dart';\n"),
                    'lib/features/b/view/b_page.dart': "import '../../../core/data/secret_repo_impl.dart';\n",
                    'lib/core/data/secret_repo_impl.dart': '//\n', 'lib/core/x/internal.dart': '//\n',
                    'lib/core/core.dart': '//\n'})
        self.files_tsv(('.dart',))
        rows = [('root', 'root', 'no', 'lib/main.dart', '-'), ('a', 'feature', 'no', 'lib/features/a', '-'),
                ('b', 'feature', 'no', 'lib/features/b', '-')]
        self.module_map(rows + [('core', 'shared-common', 'no', 'lib/core', 'nonsrc')])
        self.metrics('dart', ok=False)
        self.assertIn("module core: public 'nonsrc' on a logical module", self.last.stderr)
        self.module_map(rows + [('core', 'shared-common', 'no', 'lib/core', 'lib/core/core.dart')])
        sc = self.metrics('dart')['structuralCoupling']
        self.assertEqual((sc['checkedEdges'], sc['deepEdges'], sc['deepEdgeShare']), (3, 3, 100.0))

    def test_two_column_files_tsv_is_rejected(self):
        self.rejected(self.GOOD, 'expected 3 tab-separated columns, got 2', files='lib/c.dart\t1\n')

    def test_multi_row_module_unions_public_lists(self):
        self.write({'pubspec.yaml': 'name: app\n', 'lib/use.dart': "import 'x/x.dart';\nimport 'y/y.dart';\n",
                    'lib/x/x.dart': '//\n', 'lib/y/y.dart': '//\n'})
        self.files_tsv(('.dart',))
        self.module_map([('root', 'root', 'no', 'lib/use.dart', '-'),
                         ('xy', 'shared-common', 'no', 'lib/x', 'lib/x/x.dart'),
                         ('xy', 'shared-common', 'no', 'lib/y', 'lib/y/y.dart')])
        m = self.metrics('dart')
        self.assertEqual((m['structuralCoupling']['checkedEdges'], m['structuralCoupling']['deepEdges']), (2, 0))
        self.assertEqual(m['totals']['modules'], 2)


class Mapping(Case):
    def test_root_split_across_rows_is_one_module(self):
        self.write({'pubspec.yaml': 'name: app\n',
                    'lib/main.dart': "import 'app/app.dart';\n" + '//\n' * 9,
                    'lib/app/app.dart': "import 'router.dart';\n" + '//\n' * 9,
                    'lib/app/router.dart': "import 'app.dart';\nimport '../features/a/a.dart';\n" + '//\n' * 8,
                    'lib/app/widgets/button.dart': '//\n' * 10,
                    'lib/features/a/a.dart': "import 'package:app/app/widgets/button.dart';\n" + '//\n' * 69})
        self.files_tsv(('.dart',))
        self.module_map([('root', 'root', 'no', p, '-') for p in ('lib/main.dart', 'lib/app/app.dart', 'lib/app/router.dart')]
                        + [('widgets', 'shared-common', 'no', 'lib/app/widgets', '-'),
                           ('a', 'feature', 'no', 'lib/features/a', '-')])
        m = self.metrics('dart')
        self.assertEqual(m['totals']['modules'], 3)
        self.assertEqual(m['sizes']['linesByModule'], {'a': 70, 'root': 30, 'widgets': 10})
        self.assertAlmostEqual(m['sizes']['rootShare'], 300 / 11)  # 27.27...: not rounded
        self.assertEqual(m['structuralCoupling']['cyclesAllEdges'], [])
        self.assertEqual(m['totals']['crossModuleEdges'], 2)  # root->a, a->widgets; root files share one module

    def test_catch_all_matches_last_and_prefixes_respect_segments(self):
        self.write({'a/x.ts': "import { y } from '../b/y';\nimport '../ab/z';\n", 'b/y.ts': 'export {};\n',
                    'ab/z.ts': 'export {};\n'})
        self.files_tsv(('.ts',))
        self.module_map([('rest', 'shared-common', 'no', '.', '-'), ('a', 'feature', 'no', 'a', '-'),
                         ('b', 'feature', 'no', 'b', '-')])
        m = self.metrics('ts')
        self.assertEqual(m['sizes']['linesByModule'], {'a': 2, 'b': 1, 'rest': 1})
        self.assertEqual(m['featureEdgeList'], ['a->b'])

    def test_nonsrc_on_a_dot_row_reads_the_whole_path(self):
        self.write({'features/a/index.ts': "import '../../src/internal';\nimport '../../lib/src/y';\nimport '../../lib/z';\n",
                    'src/internal.ts': 'export {};\n', 'lib/src/y.ts': 'export {};\n', 'lib/z.ts': 'export {};\n'})
        self.files_tsv(('.ts',))
        self.module_map([('rest', 'shared-common', 'no', '.', 'nonsrc'), ('a', 'feature', 'no', 'features/a', '-')])
        m = self.metrics('ts')
        self.assertEqual(m['deepEdgeExamples'], ['features/a/index.ts:1 -> src/internal.ts',
                                                 'features/a/index.ts:2 -> lib/src/y.ts'])


class GraphMetrics(Case):
    def test_thresholded_values_are_not_rounded(self):
        pct = load_script(self).pct
        self.assertAlmostEqual(pct(1, 2500), 0.04)
        self.assertAlmostEqual(pct(2, 199), 200 / 199)  # 1.005...: a rounded 1.0 would sit on the threshold
        self.assertIsNone(pct(0, 0))
        (self.art / 'edges.in.tsv').write_text('# from\tto\tline\n')
        self.module_map([('all', 'shared-common', 'no', '.', '-')])
        for total, over, expected in ((2500, 1, 0.04), (199, 2, 200 / 199)):
            with self.subTest(total=total):
                rows = [f'f{i}.sql\t{1001 if i < over else 10}\tsrc\n' for i in range(total)]
                (self.art / 'files.tsv').write_text(''.join(rows))
                m = self.metrics('none')
                self.assertAlmostEqual(m['sizes']['filesOver1000Share'], expected)

    def test_outputs_are_never_written_through_a_symlink(self):
        self.write({'a.ts': "import './b';\n", 'b.ts': 'export {};\n', 'keep.txt': 'precious\n'})
        self.files_tsv(('.ts',))
        self.module_map([('all', 'shared-common', 'no', '.', '-')])
        keep = self.root / 'keep.txt'
        for name in ('edges.tsv', 'module_edges.tsv', 'metrics.json'):
            with self.subTest(output=name):
                link = self.art / name
                link.symlink_to(keep)
                result = self.cli('metrics', '--root', str(self.root), '--dir', str(self.art), '--lang', 'ts', '--no-git',
                                  ok=False)
                self.assertEqual(result.returncode, 1)
                self.assertIn(f'{link} is a symlink', result.stderr)
                self.assertEqual(keep.read_text(), 'precious\n')
                self.assertFalse((self.art / 'metrics.json').exists() and name != 'metrics.json')
                link.unlink()
        (self.art / 'edges.tsv').symlink_to(self.root / 'dangling')  # a dangling link is refused too
        self.assertEqual(self.cli('metrics', '--root', str(self.root), '--dir', str(self.art), '--lang', 'ts', '--no-git',
                                  ok=False).returncode, 1)
        self.assertFalse((self.root / 'dangling').exists())

    def test_refuses_to_write_when_the_artifacts_directory_is_reached_through_a_symlink(self):
        self.write({'lib/a.dart': 'class A {}\n'})
        (self.root / 'real').mkdir()
        (self.root / 'link').symlink_to(self.root / 'real')
        result = self.cli('inventory', '--root', str(self.root), '--dir', str(self.root / 'link' / 'out'), '--lang', 'dart',
                          '--source', 'lib', '--no-git', ok=False)
        self.assertEqual(result.returncode, 1)
        self.assertIn(f'{self.root / "link"} is a symlink', result.stderr)
        self.assertEqual(list((self.root / 'real').iterdir()), [])
        # a symlinked directory outside --root (a temp directory such as /tmp) is not this script's business
        outside = pathlib.Path(tempfile.mkdtemp(prefix='graph-out'))
        self.addCleanup(shutil.rmtree, outside)
        self.cli('inventory', '--root', str(self.root), '--dir', str(outside / 'out'), '--lang', 'dart',
                 '--source', 'lib', '--no-git')

    def test_refuses_an_outside_artifacts_directory_that_is_a_link_into_the_source_tree(self):
        self.write({'lib/a.dart': 'class A {}\n'})
        outside = pathlib.Path(tempfile.mkdtemp(prefix='graph-out'))
        self.addCleanup(shutil.rmtree, outside)
        (outside / 'out').symlink_to(self.root / 'lib')
        result = self.cli('inventory', '--root', str(self.root), '--dir', str(outside / 'out'), '--lang', 'dart',
                          '--source', 'lib', '--no-git', ok=False)
        self.assertEqual(result.returncode, 1)
        self.assertIn('inside --root, through a symlink', result.stderr)
        self.assertEqual(sorted(path.name for path in (self.root / 'lib').iterdir()), ['a.dart'])

    def test_a_root_reached_through_an_alias_keeps_its_artifacts_directory(self):
        self.write({'lib/a.dart': 'class A {}\n'})
        alias_parent = pathlib.Path(tempfile.mkdtemp(prefix='graph-alias'))
        self.addCleanup(shutil.rmtree, alias_parent)
        alias = alias_parent / 'repo'  # like /tmp -> /private/tmp: root and --dir both go through the link
        alias.symlink_to(self.root)
        self.cli('inventory', '--root', str(alias), '--dir', str(alias / 'out'), '--lang', 'dart',
                 '--source', 'lib', '--no-git')
        self.assertTrue((self.root / 'out' / 'files.tsv').exists())
        result = self.cli('inventory', '--root', str(alias), '--dir', str(self.art), '--lang', 'dart',
                          '--source', 'lib', '--no-git', ok=False)  # the same directory under its real path is refused
        self.assertEqual(result.returncode, 1)
        self.assertIn('inside --root, through a symlink', result.stderr)
        self.assertFalse((self.art / 'files.tsv').exists())

    def test_refuses_an_artifacts_directory_given_with_dotdot(self):
        self.write({'lib/a.dart': 'class A {}\n', 'nested/keep.txt': 'x\n'})
        outside = pathlib.Path(tempfile.mkdtemp(prefix='graph-out'))
        self.addCleanup(shutil.rmtree, outside)
        (outside / 'jump').symlink_to(self.root / 'nested')  # jump/../lib is checked as outside/lib, written as root/lib
        result = self.cli('inventory', '--root', str(self.root), '--dir', str(outside / 'jump' / '..' / 'lib'),
                          '--lang', 'dart', '--source', 'lib', '--no-git', ok=False)
        self.assertEqual(result.returncode, 1)
        self.assertIn('contains ".."', result.stderr)
        self.assertEqual(sorted(path.name for path in (self.root / 'lib').iterdir()), ['a.dart'])
        self.assertFalse((outside / 'lib').exists())

    def test_open_output_uses_no_follow_when_the_link_check_is_raced(self):
        mod = load_script(self)
        target = self.root / 'keep.txt'
        target.write_text('precious\n')
        link = self.root / 'out.json'
        link.symlink_to(target)
        self.addCleanup(setattr, os.path, 'islink', os.path.islink)
        os.path.islink = lambda path: False  # the link appears after the check
        with self.assertRaises(SystemExit) as raised:
            mod.open_output(str(link))
        self.assertIn('cannot write', str(raised.exception))
        self.assertEqual(target.read_text(), 'precious\n')

    def test_degenerate_map_gives_nulls_not_zeros(self):
        self.write({'pubspec.yaml': 'name: app\n', 'lib/main.dart': "import 'core/a.dart';\n",
                    'lib/core/a.dart': "import 'b.dart';\n", 'lib/core/b.dart': '//\n'})
        self.files_tsv(('.dart',))
        self.module_map([('root', 'root', 'no', 'lib/main.dart', '-'), ('core', 'shared-common', 'no', 'lib/core', '-')])
        m = self.metrics('dart')
        sc, sizes = m['structuralCoupling'], m['sizes']
        for value in (sc['featureEdgesPerFeature'], sc['deepEdgeShare'], sizes['largestFeature'],
                      sizes['physicalFeatureShare'], m['changeLocality']['meanFeaturesPerChange']):
            self.assertIsNone(value)
        self.assertEqual(sc['uncheckedEdgeShare'], 100.0)
        shared = dict(sizes['largestSharedModule'])
        self.assertAlmostEqual(shared.pop('share'), 200 / 3)
        self.assertEqual(shared, {'name': 'core', 'role': 'shared-common', 'lines': 2})

    def test_zero_edges_exits_non_zero(self):
        self.write({'src/a.ts': "import './missing';\n", 'src/b.ts': 'export {};\n'})
        self.files_tsv(('.ts',))
        self.module_map([('all', 'shared-common', 'no', 'src', '-')])
        m = self.metrics('ts', ok=False)
        self.assertNotEqual(self.last.returncode, 0)
        self.assertIn('check --lang', self.last.stderr)
        self.assertIn('check --lang', m['error'])
        self.assertIn('1 unresolved internal imports', m['error'])
        self.assertNotIn('warning', m)

    def test_empty_graph_of_external_imports_only_is_a_warning(self):
        self.write({'src/a.ts': "import React from 'react';\n", 'src/b.ts': "import fs from 'node:fs';\n"})
        self.files_tsv(('.ts',))
        self.module_map([('all', 'shared-common', 'no', 'src', '-')])
        m = self.metrics('ts')  # exit 0
        self.assertNotIn('error', m)
        self.assertIn('no unresolved internal import', m['warning'])
        self.assertIn('warning: no import edges', self.last.stderr)
        self.assertEqual(m['totals']['unresolvedInternal'], 0)

    def test_allowed_cycles_exclude_violation_edges(self):
        self.write({'pubspec.yaml': 'name: app\n', 'lib/main.dart': "import 'f/f.dart';\n",
                    'lib/f/f.dart': "import '../main.dart';\n"})
        self.files_tsv(('.dart',))
        self.module_map([('r', 'root', 'no', 'lib/main.dart', '-'), ('f', 'feature', 'no', 'lib/f', '-')])
        m = self.metrics('dart')
        self.assertEqual(m['structuralCoupling']['cycles'], [])
        self.assertEqual(m['structuralCoupling']['largestCycle'], 0)
        self.assertEqual(m['structuralCoupling']['cyclesAllEdges'], [['f', 'r']])
        self.assertEqual(m['violations']['feature->root']['rule'], 'R5')

    def test_deep_and_unchecked_count_allowed_edges_only(self):
        self.write({'a/index.ts': ("import '../b/src/inner';\nimport '../s/src/inner';\nimport '../s/open';\n"
                                   "import '../t/any';\n"),
                    'b/src/inner.ts': 'export {};\n', 's/src/inner.ts': 'export {};\n', 's/open.ts': 'export {};\n',
                    't/any.ts': 'export {};\n'})
        self.files_tsv(('.ts',))
        self.module_map([('a', 'feature', 'no', 'a', '-'), ('b', 'feature', 'no', 'b', 'nonsrc'),
                         ('s', 'shared-common', 'no', 's', 'nonsrc'), ('t', 'shared-common', 'no', 't', '-')])
        sc = self.metrics('ts')['structuralCoupling']
        self.assertEqual(sc['deepEdgesAllEdges'], 2)  # a->b (a violation) and a->s
        self.assertEqual((sc['checkedEdges'], sc['deepEdges'], sc['deepEdgeShare']), (2, 1, 50.0))
        self.assertAlmostEqual(sc['uncheckedEdgeShare'], 100 / 3)  # a->t of the three allowed edges

    def test_violation_kinds_and_rules(self):
        roles = {'fa': 'feature', 'fb': 'feature', 'r': 'root', 'c': 'contract', 'sd': 'shared-domain',
                 'sc': 'shared-common', 'g': 'global', 'fo': 'foundation'}
        imports = {'fa': ['fb', 'c', 'r'], 'c': ['fa'], 'sc': ['sd'], 'g': ['sd', 'fa'], 'fo': ['g'], 'sd': ['r']}
        tree = {'pubspec.yaml': 'name: app\n'}
        for name in roles:
            tree[f'lib/{name}/{name}.dart'] = ''.join(f"import '../{t}/{t}.dart';\n" for t in imports.get(name, ())) or '//\n'
        self.write(tree)
        self.files_tsv(('.dart',))
        self.module_map([(name, role, 'no', f'lib/{name}', '-') for name, role in roles.items()])
        m = self.metrics('dart')
        self.assertEqual({kind: (v['rule'], v['modulePairs']) for kind, v in m['violations'].items()}, {
            'feature->feature': ('R1', ['fa->fb']), 'feature->root': ('R5', ['fa->r']),
            'contract->feature': ('R3', ['c->fa']), 'shared-common->shared-domain': ('R7', ['sc->sd']),
            'global->feature': ('R7', ['g->fa']), 'foundation->global': ('R7', ['fo->g']),
            'shared-domain->root': ('R5', ['sd->r'])})  # feature->contract and global->shared-domain are allowed
        self.assertEqual(m['structuralCoupling']['featureEdges'], 1)
        self.assertEqual(m['structuralCoupling']['cycles'], [])
        self.assertEqual(m['structuralCoupling']['cyclesAllEdges'], [['c', 'fa']])

    def test_sizes_skip_generated_files(self):
        self.write({'pubspec.yaml': 'name: app\n', 'lib/main.dart': "import 'a/a.dart';\n",
                    'lib/a/a.dart': "import 'a.g.dart';\nimport '../b/b.dart';\n", 'lib/a/a.g.dart': "import '../b/b.dart';\n",
                    'lib/b/b.dart': '//\n', 'lib/c/c.dart': '//\n'})
        self.files_tsv(('.dart',), gen={'lib/a/a.g.dart'},
                       lines={'lib/main.dart': 100, 'lib/a/a.dart': 1500, 'lib/a/a.g.dart': 5000,
                              'lib/b/b.dart': 300, 'lib/c/c.dart': 200})
        self.module_map([('r', 'root', 'no', 'lib/main.dart', '-'), ('a', 'feature', 'yes', 'lib/a', '-'),
                         ('b', 'feature', 'no', 'lib/b', '-'), ('c', 'feature', 'no', 'lib/c', '-')])
        m = self.metrics('dart')
        sizes = m['sizes']
        self.assertEqual(m['totals']['genLines'], 5000)
        self.assertEqual(m['totals']['srcLines'], 2100)
        self.assertEqual(sizes['linesByModule'], {'a': 1500, 'b': 300, 'c': 200, 'r': 100})
        self.assertEqual(sizes['largestFeature'], {'name': 'a', 'lines': 1500, 'share': 75.0, 'ratioToMean': 2.25})
        self.assertIsNone(sizes['largestSharedModule'])  # roots and features only
        self.assertNotIn('largestNonRootModule', sizes)
        self.assertEqual((sizes['filesOver1000'], sizes['filesOver2000'], sizes['filesOver1000Share']),
                         (['lib/a/a.dart'], [], 25.0))
        self.assertAlmostEqual(sizes['physicalFeatureShare'], 100 / 3)
        self.assertIn(('lib/a/a.g.dart', 'lib/b/b.dart'), self.edges())  # generated files keep their edges

    def test_module_edges_cover_every_resolved_edge(self):
        self.write({'a/view.ts': ("import './data';\nimport '../s/src/inner';\nimport '../s/open';\n"
                                  "import '../t/any';\nimport '../b/b';\n"),
                    'a/data.ts': 'export {};\n', 'b/b.ts': "import '../root/main';\n",
                    'root/main.ts': "import '../a/view';\nimport '../loose/x';\n",
                    's/src/inner.ts': 'export {};\n', 's/open.ts': 'export {};\n', 't/any.ts': 'export {};\n',
                    'loose/x.ts': 'export {};\n', 'f/f.ts': 'export {};\n//\n//\n', 'c/c.ts': "import '../a/data';\n"})
        self.files_tsv(('.ts',))
        self.module_map([('root', 'root', 'no', 'root', '-'), ('a', 'feature', 'no', 'a', '-'),
                         ('b', 'feature', 'no', 'b', '-'), ('s', 'shared-common', 'no', 's', 'nonsrc'),
                         ('t', 'shared-common', 'no', 't', '-'), ('f', 'foundation', 'no', 'f', '-'),
                         ('c', 'contract', 'no', 'c', '-')])
        m = self.metrics('ts')
        self.assertEqual(self.module_edges(), [
            ('a/view.ts', '1', 'a', 'feature', 'a/data.ts', 'a', 'feature', 'internal'),
            ('a/view.ts', '2', 'a', 'feature', 's/src/inner.ts', 's', 'shared-common', 'deep'),
            ('a/view.ts', '3', 'a', 'feature', 's/open.ts', 's', 'shared-common', 'allowed'),
            ('a/view.ts', '4', 'a', 'feature', 't/any.ts', 't', 'shared-common', 'unchecked'),
            ('a/view.ts', '5', 'a', 'feature', 'b/b.ts', 'b', 'feature', 'R1'),
            ('b/b.ts', '1', 'b', 'feature', 'root/main.ts', 'root', 'root', 'R5'),
            ('c/c.ts', '1', 'c', 'contract', 'a/data.ts', 'a', 'feature', 'R3'),
            ('root/main.ts', '1', 'root', 'root', 'a/view.ts', 'a', 'feature', 'unchecked'),
            ('root/main.ts', '2', 'root', 'root', 'loose/x.ts', '-', '-', 'unmapped'),
        ])
        self.assertEqual(m['modules']['a'], {'role': 'feature', 'physical': False, 'files': 2, 'genFiles': 0,
                                             'lines': 6, 'fanIn': 2, 'fanOut': 3})
        self.assertEqual(m['modules']['f'], {'role': 'foundation', 'physical': False, 'files': 1, 'genFiles': 0,
                                             'lines': 3, 'fanIn': 0, 'fanOut': 0})
        self.assertEqual(sorted(m['modules']), ['a', 'b', 'c', 'f', 'root', 's', 't'])
        # f (3 lines) beats s (2); the feature a (6) and the root are not shared modules
        shared = dict(m['sizes']['largestSharedModule'])
        self.assertAlmostEqual(shared.pop('share'), 300 / 17)
        self.assertEqual(shared, {'name': 'f', 'role': 'foundation', 'lines': 3})

    def test_compact_app_module_table_and_same_module_layering(self):
        self.write({'pubspec.yaml': 'name: app\n', 'lib/main.dart': "import 'presentation/home.dart';\n",
                    'lib/presentation/home.dart': "import '../domain/order.dart';\nimport '../data/order_repo.dart';\n" + '//\n' * 300,
                    'lib/domain/order.dart': '//\n' * 200,
                    'lib/data/order_repo.dart': "import '../domain/order.dart';\nimport 'package:core/core.dart';\n" + '//\n' * 300,
                    'lib/data/order_repo.g.dart': '//\n',
                    'packages/core/pubspec.yaml': 'name: core\n', 'packages/core/lib/core.dart': '//\n' * 50})
        self.files_tsv(('.dart',), gen={'lib/data/order_repo.g.dart'})
        self.module_map([('root', 'root', 'no', 'lib/main.dart', '-'), ('app', 'feature', 'no', 'lib/presentation', '-'),
                         ('app', 'feature', 'no', 'lib/domain', '-'), ('app', 'feature', 'no', 'lib/data', '-'),
                         ('core', 'foundation', 'yes', 'packages/core', 'nonsrc')])
        m = self.metrics('dart')
        self.assertEqual(m['modules'], {
            'app': {'role': 'feature', 'physical': False, 'files': 3, 'genFiles': 1, 'lines': 804, 'fanIn': 1, 'fanOut': 1},
            'core': {'role': 'foundation', 'physical': True, 'files': 1, 'genFiles': 0, 'lines': 50, 'fanIn': 1, 'fanOut': 0},
            'root': {'role': 'root', 'physical': False, 'files': 1, 'genFiles': 0, 'lines': 1, 'fanIn': 0, 'fanOut': 1}})
        shared = dict(m['sizes']['largestSharedModule'])
        self.assertAlmostEqual(shared.pop('share'), 5000 / 855)
        self.assertEqual(shared, {'name': 'core', 'role': 'foundation', 'lines': 50})
        self.assertEqual([(row[0], row[4], row[7]) for row in self.module_edges()], [
            ('lib/data/order_repo.dart', 'lib/domain/order.dart', 'internal'),
            ('lib/data/order_repo.dart', 'packages/core/lib/core.dart', 'allowed'),
            ('lib/main.dart', 'lib/presentation/home.dart', 'unchecked'),
            ('lib/presentation/home.dart', 'lib/domain/order.dart', 'internal'),
            ('lib/presentation/home.dart', 'lib/data/order_repo.dart', 'internal')])

    def test_lang_none_reads_hand_written_edges(self):
        self.write({'x/a.sql': '', 'y/b.sql': ''})
        self.files_tsv(('.sql',))
        (self.art / 'edges.in.tsv').write_text('# from\tto\tline\nx/a.sql\ty/b.sql\t3\nx/a.sql\tz/gone.sql\t4\n')
        self.module_map([('x', 'feature', 'no', 'x', '-'), ('y', 'feature', 'no', 'y', '-')])
        m = self.metrics('none')
        self.assertEqual(self.edges(), {('x/a.sql', 'y/b.sql'): 3})
        self.assertEqual((m['totals']['unresolvedInternal'], m['featureEdgeList']), (1, ['x->y']))

    def test_strongly_connected_matches_brute_force(self):
        module = load_script(self)

        def reach(graph, node):
            seen, stack = {node}, [node]
            while stack:
                for nxt in graph.get(stack.pop(), ()):
                    if nxt not in seen:
                        seen.add(nxt)
                        stack.append(nxt)
            return seen

        rng = random.Random(7)
        for _ in range(500):
            nodes = {f'm{i}' for i in range(rng.randint(1, 10))}
            graph = {a: {b for b in nodes | {'outside'} if b != a and rng.random() < 0.25} for a in nodes}
            reached = {n: reach({k: v & nodes for k, v in graph.items()}, n) for n in nodes}
            expected = {tuple(sorted(m for m in nodes if m in reached[n] and n in reached[m])) for n in nodes}
            got = module.strongly_connected(nodes, graph)
            self.assertEqual(sorted(map(tuple, got)), sorted(c for c in expected if len(c) > 1))
            self.assertEqual([len(c) for c in got], sorted((len(c) for c in got), reverse=True))


class Integrity(Case):
    def run_copy(self, text, crlf=False):
        copy = self.root / 'graph_metrics.py'
        with open(copy, 'w', encoding='utf-8', newline='\r\n' if crlf else '\n') as handle:
            handle.write(text)
        return subprocess.run([sys.executable, '-B', str(copy), 'inventory', '--help'], capture_output=True, text=True)

    def test_untouched_copy_runs(self):
        result = self.run_copy(SCRIPT.read_text(encoding='utf-8'))
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_one_character_edit_exits_3(self):
        text = SCRIPT.read_text(encoding='utf-8')
        self.assertIn('Architecture audit', text)
        result = self.run_copy(text.replace('Architecture audit', 'Architecture audiT', 1))
        self.assertEqual(result.returncode, 3)
        self.assertRegex(result.stderr, r'graph_metrics\.py was altered \(expected [0-9a-f]{64}, got [0-9a-f]{64}\); '
                                        r'extract it again')

    def test_crlf_copy_runs_and_an_edit_still_exits_3(self):
        text = SCRIPT.read_text(encoding='utf-8')
        result = self.run_copy(text, crlf=True)
        self.assertIn(b'\r\n', (self.root / 'graph_metrics.py').read_bytes())
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn('altered', result.stderr)
        result = self.run_copy(text.replace('Architecture audit', 'Architecture audiT', 1), crlf=True)
        self.assertEqual(result.returncode, 3)
        self.assertIn('was altered', result.stderr)


class Profile(Case):
    def profile(self, lines, features, peak=None, extra=()):
        tree = {f'f{i}/x.sql': '' for i in range(features)}
        tree['shared/s.sql'] = ''
        self.write(tree)
        self.files_tsv(('.sql',), lines={'shared/s.sql': lines})
        (self.art / 'edges.in.tsv').write_text('f0/x.sql\tshared/s.sql\t1\n' if features else '')
        self.module_map([(f'f{i}', 'feature', 'no', f'f{i}', '-') for i in range(features)]
                        + [('shared', 'shared-common', 'no', 'shared', '-')])
        if peak is not None:
            (self.art / 'inventory.json').write_text(json.dumps({'git': {'peakMonthlyContributors': peak}}))
        return self.metrics('none', *extra)['profile']

    def test_compact(self):
        p = self.profile(19_999, 8)
        self.assertEqual((p['measured'], p['effective'], p['override']), ('compact', 'compact', None))
        self.assertEqual(p['inputs'], {'srcLines': 19_999, 'features': 8, 'peakMonthlyContributors': None})

    def test_standard_by_lines_or_contributors(self):
        self.assertEqual(self.profile(20_000, 2)['measured'], 'standard')

    def test_standard_by_contributors(self):
        self.assertEqual(self.profile(1000, 2, peak=4)['measured'], 'standard')

    def test_large_by_lines(self):
        self.assertEqual(self.profile(80_000, 2)['measured'], 'large')

    def test_large_by_features(self):
        self.assertEqual(self.profile(100, 20)['measured'], 'large')

    def test_large_by_contributors(self):
        self.assertEqual(self.profile(100, 2, peak=8)['measured'], 'large')

    def test_override_and_drivers(self):
        p = self.profile(100, 2, extra=('--profile', 'large', '--driver', 'regulated', '--driver', 'growth',
                                        '--driver', 'regulated'))
        self.assertEqual((p['measured'], p['override'], p['effective'], p['drivers']),
                         ('compact', 'large', 'large', ['growth', 'regulated']))


class ChangeLocality(Case):
    TREE = {'pubspec.yaml': 'name: app\n',
            'lib/features/a/a.dart': "import '../../core/core.dart';\n", 'lib/features/b/b.dart': '//\n',
            'lib/features/c/c.dart': '//\n', 'lib/core/core.dart': '//\n', 'lib/features/a/a.g.dart': '//\n'}
    MAP = [('a', 'feature', 'no', 'lib/features/a', '-'), ('b', 'feature', 'no', 'lib/features/b', '-'),
           ('c', 'feature', 'no', 'lib/features/c', '-'), ('core', 'shared-common', 'no', 'lib/core', '-')]

    def test_first_parent_history(self):
        self.git('init', '-q', '-b', 'main')
        self.commit('init', self.TREE)
        self.commit('regen', {'lib/features/a/a.g.dart': '// v2\n'})
        self.commit('shared', {'lib/core/core.dart': '// v2\n'})
        self.commit('big', {'lib/features/a/a.dart': "import '../../core/core.dart';\n//3\n", 'lib/features/a/a2.dart': '//\n',
                            'lib/features/b/b.dart': '//3\n', 'lib/features/c/c.dart': '//3\n', 'lib/core/core.dart': '//3\n'})
        self.git('checkout', '-q', '-b', 'topic')
        self.commit('topic a', {'lib/features/a/a.dart': "import '../../core/core.dart';\n//4\n"})
        self.commit('topic b', {'lib/features/b/b.dart': '//4\n'})
        self.git('checkout', '-q', 'main')
        self.git('merge', '-q', '--no-ff', '-m', 'merge topic', 'topic')
        self.commit('unicode', {'lib/features/b/café.dart': '//\n'})
        self.files_tsv(('.dart',), gen={'lib/features/a/a.g.dart'})
        self.module_map(self.MAP)
        locality = self.metrics('dart', '--max-changeset', '4', git=True)['changeLocality']
        self.assertAlmostEqual(locality.pop('changesTouching3PlusFeatures'), 100 / 3)
        self.assertEqual(locality, {
            'changesScanned': 6, 'changes': 3, 'droppedOversized': 1, 'changesWithoutFeatures': 2,
            'meanFeaturesPerChange': 2.0,
            'topCoChangedPairs': [['a<->b', 2], ['a<->c', 1], ['b<->c', 1]], 'reason': None})

    def test_root_below_the_repository_top(self):
        self.git('init', '-q', '-b', 'main')
        self.commit('init', {f'app/{path}': text for path, text in self.TREE.items()})
        project = self.root / 'app'
        (project / 'art').mkdir()
        self.art = project / 'art'
        self.root, top = project, self.root
        try:
            self.files_tsv(('.dart',), gen={'lib/features/a/a.g.dart'})
            self.module_map(self.MAP)
            locality = self.metrics('dart', git=True)['changeLocality']
        finally:
            self.root = top
        self.assertEqual((locality['changes'], locality['meanFeaturesPerChange']), (1, 3.0))

    def test_changes_file_with_quoted_path(self):
        self.write(self.TREE)
        self.write({'lib/features/b/café.dart': '//\n'})
        self.files_tsv(('.dart',), gen={'lib/features/a/a.g.dart'})
        self.module_map(self.MAP)
        (self.art / 'changes.txt').write_text('@@1\n\n"lib/features/b/caf\\303\\251.dart"\nlib/features/a/a.dart\n'
                                              '@@2\n\nlib/features/a/a.g.dart\nREADME.md\n')
        locality = self.metrics('dart', '--changes-file', str(self.art / 'changes.txt'))['changeLocality']
        self.assertEqual((locality['changesScanned'], locality['changes'], locality['changesWithoutFeatures'],
                          locality['topCoChangedPairs']), (2, 1, 1, [['a<->b', 1]]))

    def test_missing_or_unreadable_changes_file_is_a_usage_error(self):
        self.write(self.TREE)
        self.files_tsv(('.dart',))
        self.module_map(self.MAP)
        missing = self.art / 'nope.txt'
        for path in (missing, self.art):  # a missing file, then a directory
            with self.subTest(path=path.name):
                self.metrics('dart', '--changes-file', str(path), ok=False)
                self.assertEqual(self.last.returncode, 1)
                lines = self.last.stderr.strip().splitlines()
                self.assertEqual(len(lines), 1, self.last.stderr)
                self.assertTrue(lines[0].startswith(f'graph_metrics: cannot read --changes-file {path}: '), lines[0])
                self.assertNotIn('Traceback', self.last.stderr)
        self.assertFalse((self.art / 'metrics.json').exists())
        self.assertFalse((self.art / 'edges.tsv').exists())

    def test_unavailable_history_reports_a_reason(self):
        self.write(self.TREE)
        self.files_tsv(('.dart',))
        self.module_map(self.MAP)
        no_git = self.metrics('dart')['changeLocality']
        self.assertEqual(no_git['reason'], '--no-git')
        self.assertTrue(all(no_git[key] is None for key in no_git if key != 'reason'))
        self.assertEqual(self.metrics('dart', git=True)['changeLocality']['reason'], 'not a git repository')

    def test_unreadable_history_keeps_the_metrics(self):
        self.write(self.TREE)
        self.files_tsv(('.dart',))
        self.module_map(self.MAP)
        self.git('init', '-q', '-b', 'main')  # unborn HEAD: no commit yet
        m = self.metrics('dart', git=True)
        self.assertEqual(m['totals']['crossModuleEdges'], 1)
        locality = m['changeLocality']
        self.assertTrue(locality['reason'].startswith('git log failed: '), locality['reason'])
        self.assertTrue(all(locality[key] is None for key in locality if key != 'reason'))
        self.commit('init')
        self.assertTrue(self.metrics('dart', '--branch', 'nope', git=True)['changeLocality']['reason']
                        .startswith('git log failed: '))
        empty = self.root / 'no-git-here'
        empty.mkdir()
        self.metrics('dart', git=True, env=dict(GIT_ENV, PATH=str(empty)))
        self.assertTrue(self.metrics_json()['changeLocality']['reason'].startswith('git cannot run'))

    @unittest.skipIf(os.name == 'nt', 'needs a POSIX shell wrapper')
    def test_git_older_than_2_31_keeps_the_metrics(self):
        self.write(self.TREE)
        self.files_tsv(('.dart',))
        self.module_map(self.MAP)
        self.git('init', '-q', '-b', 'main')
        self.commit('init')
        real = shutil.which('git', path=GIT_ENV['PATH'])
        old = self.root / 'old-git'
        old.mkdir()
        wrapper = old / 'git'
        wrapper.write_text('#!/bin/sh\nfor arg in "$@"; do\n  case "$arg" in --diff-merges*)\n'
                           '    echo "fatal: unrecognized argument: $arg" >&2; exit 129;;\n  esac\ndone\n'
                           f'exec {real} "$@"\n')
        wrapper.chmod(0o755)
        m = self.metrics('dart', git=True, env=dict(GIT_ENV, PATH=f'{old}{os.pathsep}{GIT_ENV["PATH"]}'))
        locality = m['changeLocality']
        self.assertIn('unrecognized argument: --diff-merges', locality['reason'])
        self.assertTrue(all(locality[key] is None for key in locality if key != 'reason'))
        self.assertEqual(m['totals']['crossModuleEdges'], 1)

    def test_no_qualifying_change(self):
        self.git('init', '-q', '-b', 'main')
        self.commit('init', {'pubspec.yaml': 'name: app\n', 'lib/core/core.dart': '//\n', 'lib/features/a/a.dart': '//\n'})
        self.commit('core only', {'lib/core/core.dart': '// 2\n'})
        self.files_tsv(('.dart',))
        self.module_map([('a', 'feature', 'no', 'lib/features/a', '-'), ('core', 'shared-common', 'no', 'lib/core', '-')])
        self.write({'lib/features/a/a.dart': "import '../../core/core.dart';\n"})  # one edge, not committed
        locality = self.metrics('dart', '--max-changeset', '1', git=True)['changeLocality']
        self.assertEqual(locality['reason'], 'no qualifying change in the window (2 scanned, 1 oversized, 1 without features)')
        self.assertTrue(all(locality[key] is None for key in locality if key != 'reason'), locality)
        self.assertEqual(len(locality), 8)

    def test_shallow_clone(self):
        origin = self.root / 'origin'
        origin.mkdir()
        self.git('init', '-q', '-b', 'main', cwd=origin)
        self.commit('one', {f'origin/{p}': t for p, t in self.TREE.items()}, cwd=origin)
        self.commit('two', {'origin/lib/core/core.dart': '// 2\n'}, cwd=origin)
        clone = self.root / 'clone'
        self.git('clone', '-q', '--depth', '1', origin.as_uri(), str(clone))
        art = clone / 'art'
        art.mkdir()
        self.cli('inventory', '--root', str(clone), '--dir', str(art), '--lang', 'dart', '--source', 'lib')
        self.assertEqual(json.loads((art / 'inventory.json').read_text())['git'], {
            'isShallow': True, 'firstCommitDate': None, 'ageDays': None, 'peakMonthlyContributors': None,
            'contributors90d': None, 'botsExcluded': None, 'botPatterns': [], 'contributorPaths': ['lib'], 'reason': 'shallow clone'})
        (art / 'module_map.tsv').write_text(''.join('\t'.join(row) + '\n' for row in self.MAP))
        self.cli('metrics', '--root', str(clone), '--dir', str(art), '--lang', 'dart')
        self.assertEqual(json.loads((art / 'metrics.json').read_text())['changeLocality']['reason'], 'shallow clone')


class Inventory(Case):
    def inventory(self, lang, *extra, sources=('.',)):
        args = ['inventory', '--root', str(self.root), '--dir', str(self.art), '--lang', lang, *extra]
        for source in sources:
            args += ['--source', source]
        self.cli(*args)
        rows = (self.art / 'files.tsv').read_text(encoding='utf-8').splitlines()
        return {path: (int(lines), kind) for path, lines, kind in (row.split('\t') for row in rows)}, \
            json.loads((self.art / 'inventory.json').read_text(encoding='utf-8'))

    def test_dart_exclusions_generated_files_and_lines(self):
        self.write({
            'pubspec.yaml': 'name: app\n',
            'l10n.yaml': 'arb-dir: lib/l10n/arb\noutput-localization-file: app_localizations.dart\n',
            'lib/a.dart': 'a\nb\nc',  # no final newline: still 3 lines
            'lib/my file.dart': '//\n',
            'lib/a_test.dart': '//\n', 'lib/test/helper.dart': '//\n', 'test/x_test.dart': '//\n',
            'lib/features/reports/r.dart': '//\n', 'lib/features/build/b.dart': '//\n',
            'build/out.dart': '//\n', 'packages/p/pubspec.yaml': 'name: p\n', 'packages/p/build/y.dart': '//\n',
            'packages/p/lib/p.dart': '//\n', 'lib/.dart_tool/t.dart': '//\n', 'lib/skip/s.dart': '//\n',
            'lib/x.g.dart': '//\n', 'lib/x.freezed.dart': '//\n', 'lib/firebase_options_dev.dart': '//\n',
            'lib/generated/z.dart': '//\n', 'lib/header.dart': '// GENERATED CODE - DO NOT MODIFY BY HAND\n',
            'lib/late_header.dart': '//\n' * 10 + '// Generated file\n',
            'lib/l10n/arb/app_localizations.dart': '//\n//\n', 'lib/l10n/arb/app_localizations_en.dart': '//\n',
            'lib/l10n/l10n.dart': '//\n', 'lib/readme.md': 'x\n',
        })
        files, summary = self.inventory('dart', '--no-git', '--exclude', 'lib/skip/**')
        gen = {'lib/x.g.dart', 'lib/x.freezed.dart', 'lib/firebase_options_dev.dart', 'lib/generated/z.dart',
               'lib/header.dart', 'lib/l10n/arb/app_localizations.dart', 'lib/l10n/arb/app_localizations_en.dart'}
        src = {'lib/a.dart', 'lib/my file.dart', 'lib/features/reports/r.dart', 'lib/features/build/b.dart',
               'packages/p/lib/p.dart', 'lib/late_header.dart', 'lib/l10n/l10n.dart'}
        self.assertEqual({p for p, (_, k) in files.items() if k == 'gen'}, gen)
        self.assertEqual({p for p, (_, k) in files.items() if k == 'src'}, src)
        self.assertEqual(files['lib/a.dart'], (3, 'src'))
        self.assertEqual(list(files), sorted(files))
        self.assertEqual({k: summary[k] for k in ('files', 'srcFiles', 'genFiles', 'srcLines', 'genLines')},
                         {'files': 14, 'srcFiles': 7, 'genFiles': 7, 'srcLines': 19, 'genLines': 8})
        self.assertEqual((summary['sources'], summary['excludes']), (['.'], ['lib/skip/**']))
        self.assertEqual(summary['git']['reason'], '--no-git')
        self.assertIsNone(summary['git']['isShallow'])

    def test_ts_and_python_exclusions(self):
        self.write({'web/a.ts': '', 'web/a.test.ts': '', 'web/b.spec.tsx': '', 'web/types.d.ts': '',
                    'web/__tests__/c.ts': '', 'web/node_modules/m/index.js': '', 'web/api.generated.ts': '',
                    'web/__generated__/g.ts': '', 'web/package.json': '{}', 'web/dist/d.js': '',
                    'web/src/out/kept.ts': '', 'web/view.vue': ''})
        files, _ = self.inventory('ts', '--no-git', sources=('web',))
        self.assertEqual(files, {'web/a.ts': (0, 'src'), 'web/api.generated.ts': (0, 'gen'),
                                 'web/__generated__/g.ts': (0, 'gen'), 'web/src/out/kept.ts': (0, 'src')})
        self.write({'py/m.py': 'x = 1\n', 'py/test_m.py': '', 'py/m_test.py': '', 'py/conftest.py': '',
                    'py/m_pb2.py': '', 'py/.venv/lib/x.py': '', 'py/tests/t.py': ''})
        files, _ = self.inventory('py', '--no-git', sources=('py',))
        self.assertEqual(files, {'py/m.py': (1, 'src'), 'py/m_pb2.py': (0, 'gen')})

    def test_generated_header_comments(self):
        generated = {
            'g/protoc.ts': '// Code generated by protoc-gen-go. DO NOT EDIT.\n',
            'g/build_runner.dart': '// GENERATED CODE - DO NOT MODIFY BY HAND\n',
            'g/pb.py': '# -*- coding: utf-8 -*-\n# Generated by the protocol buffer compiler.  DO NOT EDIT!\n',
            'g/openapi.ts': '/**\n * This file was automatically generated by OpenAPI Generator\n */\n',
            'g/marker.ts': '// @generated\n',
            'g/eslint.ts': '/* eslint-disable */\n// This file is auto-generated.\n',
            'g/registrant.dart': '//\n// Generated file. Do not edit.\n//\n',
        }
        handwritten = {
            'h/docstring.py': '"""The id is auto-generated by the database.\n"""\n',
            'h/consts.py': '# DO NOT EDIT without updating the schema docs\n',
            'h/cache.ts': '// The generated file list is cached here\n',
            'h/prose.dart': '/// Orders get an auto-generated id.\n',
            'h/late.ts': 'export {};\n' + '//\n' * 10 + '// @generated\n',
            'h/migration.py': '# Generated by Django 4.2 on 2024-01-01 10:00\n\nfrom django.db import migrations\n',
            'h/strings.dart': "const hint = 'Files generated by build_runner: do not edit them.';\n",
        }
        self.write({**generated, **handwritten})
        files, _ = self.inventory('none', '--no-git', '--ext', 'dart', '--ext', 'py', '--ext', 'ts', sources=('g', 'h'))
        self.assertEqual({path for path, (_, kind) in files.items() if kind == 'gen'}, set(generated))
        self.assertEqual({path for path, (_, kind) in files.items() if kind == 'src'}, set(handwritten))

    def test_generated_header_is_the_whole_leading_comment_block(self):
        openapi = (
            '/* tslint:disable */\n/* eslint-disable */\n/**\n * Pets API\n * The version of the OpenAPI document: 1.0\n *\n'
            ' * NOTE: This class is auto generated by OpenAPI Generator (https://openapi-generator.tech).\n'
            ' * https://openapi-generator.tech\n * Do not edit the class manually.\n */\n\nexport class Pet {}\n')
        swagger = (
            '/* eslint-disable */\n/* tslint:disable */\n/*\n * ---------------------------------------------------------------\n'
            ' * ## THIS FILE WAS GENERATED VIA SWAGGER-TYPESCRIPT-API        ##\n'
            ' * ## SOURCE: https://github.com/acacode/swagger-typescript-api ##\n'
            ' * ---------------------------------------------------------------\n */\n\nexport interface Pet {}\n')
        pyuic = (
            "# -*- coding: utf-8 -*-\n\n# Form implementation generated from reading ui file 'x.ui'\n#\n"
            '# WARNING: Any manual changes made to this file will be lost when pyuic5 is\n'
            '# run again.  Do not edit this file unless you know what you are doing.\n\nfrom PyQt5 import QtCore\n')
        cases = {
            'auto_ids.dart': ('src', '// Auto-generated IDs are assigned by Firestore.\n'),
            'openapi.ts': ('gen', openapi),
            'swagger.ts': ('gen', swagger),
            'pyuic.py': ('gen', pyuic),
            'shebang_pyuic.py': ('gen', '#!/usr/bin/env python3\n' + pyuic),
            'protobuf.dart': ('gen', '// Generated by the protocol buffer compiler.  DO NOT EDIT!\n// source: a.proto\n\nclass A {}\n'),
            'freezed.dart': ('gen', '// coverage:ignore-file\n// GENERATED CODE - DO NOT MODIFY BY HAND\n'),
            'go_style.ts': ('gen', '// Code generated by protoc-gen-go. DO NOT EDIT.\n'),
            'migration.py': ('src', '# Generated by Django 4.2 on 2023-05-01 10:00\n\nfrom django.db import migrations\n'),
            'doc_gen.py': ('gen', '"""Auto-generated by tool X. Do not edit."""\nimport os\n'),
            'doc_multi.py': ('gen', '"""Settings.\n\nThis file is auto-generated.\n"""\nimport os\n'),
            'doc_prose.py': ('src', '"""Ids are auto-generated by the database.\n"""\nimport os\n'),
            'doc_after_code.py': ('src', 'import os\n"""Auto-generated by tool X. Do not edit."""\n'),
            'after_code.ts': ('src', "import a from './a';\n// Generated by tool X. Do not edit.\n"),
            'marker_after_code.ts': ('src', 'export {};\n// @generated\n'),
            'claim_only.dart': ('src', '// Generated by hand, once, from the spec.\n'),
            'edit_only.dart': ('src', "// Don't edit this without telling the platform team.\n"),
            'wrapped.dart': ('gen', '// This code was generated\n// by a tool.\n//\n// Changes to this file\n// will be lost.\n'),
            'will_be_lost.dart': ('gen', '/// Generated from schema.json\n/// Manual changes will be overwritten.\n'),
            'must_not.dart': ('gen', '// Auto generated.\n// This file must not be edited.\n'),
            'blank_lines.dart': ('gen', '\n// Generated with build_runner\n\n\n// Do not modify.\n'),
            'sql_style.ts': ('gen', '-- generated from schema\n-- do not edit\n'),
            'wrapped_block.dart': ('gen', '/*\n * Generated by tool.\n * DO NOT\n * EDIT.\n */\n\nclass A {}\n'),
            'wrapped_inline_block.ts': ('gen', '/* Generated by tool. DO NOT\n   EDIT. */\nexport {};\n'),
            'wrapped_line_comments.dart': ('gen', '// Code generated by x.\n// DO NOT\n// EDIT.\n\nclass A {}\n'),
            'wrapped_docs.dart': ('gen', '/// Generated\n/// from schema.json.\n/// Do not\n/// modify.\n'),
            'wrapped_block_prose.dart': ('src', '/*\n * Ids are auto-\n * generated by the database.\n */\n'),
            'far_header.dart': ('src', '//\n' * 30 + '// @generated\n'),
            'last_header_line.dart': ('gen', '//\n' * 29 + '// @generated\n'),
        }
        self.write({f'g/{name}': text for name, (_, text) in cases.items()})
        files, summary = self.inventory('none', '--no-git', '--ext', 'dart', '--ext', 'py', '--ext', 'ts', sources=('g',))
        for name, (kind, _) in cases.items():
            with self.subTest(file=name):
                self.assertEqual(files[f'g/{name}'][1], kind)
        self.assertEqual(summary['generatedByHeader'], sorted(f'g/{n}' for n, (k, _) in cases.items() if k == 'gen'))

    def test_names_a_hand_written_file_can_carry_are_not_generated(self):
        header = '// coverage:ignore-file\n// GENERATED CODE - DO NOT MODIFY BY HAND\n// ignore_for_file: type=lint\n'
        self.write({'pubspec.yaml': 'name: app\n',
                    'lib/character.mapper.dart': 'class CharacterMapper {}\n', 'lib/app.config.dart': 'class AppConfig {}\n',
                    'lib/dog.mapper.dart': header + 'class DogMapper {}\n',
                    'lib/injection.config.dart': header + 'void init() {}\n',
                    'lib/firebase_options.dart': '// File generated by FlutterFire CLI.\nclass O {}\n'})
        files, summary = self.inventory('dart', '--no-git', sources=('lib',))
        self.assertEqual({path: kind for path, (_, kind) in files.items()}, {
            'lib/character.mapper.dart': 'src', 'lib/app.config.dart': 'src', 'lib/dog.mapper.dart': 'gen',
            'lib/injection.config.dart': 'gen', 'lib/firebase_options.dart': 'gen'})
        self.assertEqual(summary['generatedByHeader'], ['lib/dog.mapper.dart', 'lib/injection.config.dart'])

    def test_generated_by_header_leaves_out_name_directory_and_l10n_rules(self):
        self.write({'pubspec.yaml': 'name: app\n', 'l10n.yaml': 'arb-dir: lib/l10n\n',
                    'lib/a.g.dart': '// GENERATED CODE - DO NOT MODIFY BY HAND\n', 'lib/b.dart': '// @generated\n',
                    'lib/generated/c.dart': '// @generated\n', 'lib/l10n/app_localizations.dart': '// @generated\n',
                    'lib/d.dart': 'class D {}\n'})
        files, summary = self.inventory('dart', '--no-git', sources=('lib',))
        self.assertEqual({path for path, (_, kind) in files.items() if kind == 'gen'},
                         {'lib/a.g.dart', 'lib/b.dart', 'lib/generated/c.dart', 'lib/l10n/app_localizations.dart'})
        self.assertEqual(summary['generatedByHeader'], ['lib/b.dart'])

    def test_generated_overrides_win_and_keep_edges(self):
        self.write({'pubspec.yaml': 'name: app\n',
                    'lib/a.dart': "import 'b.g.dart';\nimport 'c.dart';\n", 'lib/b.g.dart': 'class B {}\n',
                    'lib/c.dart': '// @generated\nclass C {}\n', 'lib/d.dart': 'class D {}\n',
                    'lib/e.dart': '// @generated\n', 'lib/other/f.dart': 'class F {}\n'})
        files, summary = self.inventory('dart', '--no-git', '--generated', 'lib/d.*', '--generated', 'lib/other/*',
                                        '--handwritten', 'lib/*.g.dart', '--handwritten', 'lib/c.dart',
                                        '--generated', 'lib/d.*', sources=('lib',))
        self.assertEqual({path: kind for path, (_, kind) in files.items()},
                         {'lib/a.dart': 'src', 'lib/b.g.dart': 'src', 'lib/c.dart': 'src', 'lib/d.dart': 'gen',
                          'lib/e.dart': 'gen', 'lib/other/f.dart': 'gen'})
        self.assertEqual(summary['generatedByHeader'], ['lib/e.dart'])
        self.assertEqual(summary['overrides'], {'generated': ['lib/d.*', 'lib/other/*'],
                                                'handwritten': ['lib/*.g.dart', 'lib/c.dart']})
        self.module_map([('app', 'shared-common', 'no', 'lib', '-')])
        self.metrics('dart')
        self.assertEqual(set(self.edges()), {('lib/a.dart', 'lib/b.g.dart'), ('lib/a.dart', 'lib/c.dart')})

    def test_generated_override_conflict_and_unmatched_glob(self):
        self.write({'lib/a.dart': 'class A {}\n', 'lib/b.dart': 'class B {}\n'})
        base = ['inventory', '--root', str(self.root), '--dir', str(self.art), '--lang', 'dart', '--source', 'lib', '--no-git']
        clash = self.cli(*base, '--generated', 'lib/a*', '--handwritten', 'lib/*.dart', ok=False)
        self.assertEqual(clash.returncode, 1)
        self.assertIn('lib/a.dart matches both --generated lib/a* and --handwritten lib/*.dart', clash.stderr)
        self.assertFalse((self.art / 'files.tsv').exists())
        unmatched = self.cli(*base, '--generated', 'lib/b.dart', '--generated', 'lib/nope/*', '--handwritten', 'x/**')
        self.assertIn('--generated lib/nope/* matches no inventoried file', unmatched.stderr)
        self.assertIn('--handwritten x/** matches no inventoried file', unmatched.stderr)
        self.assertNotIn('lib/b.dart matches no', unmatched.stderr)

    def test_dot_directories_are_skipped(self):
        self.write({'app/__init__.py': '', 'app/main.py': 'import app\n', '.claude/hooks/guard.py': 'import os\n',
                    '.github/scripts/ci.py': 'import sys\n', 'app/.cache/x.py': '',
                    'reports/.artifacts/architecture-audit/data/graph_metrics.py': 'x=1\n'})
        files, _ = self.inventory('py', '--no-git')
        self.assertEqual(set(files), {'app/__init__.py', 'app/main.py'})
        files, _ = self.inventory('py', '--no-git', sources=('.github',))  # a source named explicitly is walked
        self.assertEqual(set(files), {'.github/scripts/ci.py'})

    def test_bot_authors(self):
        is_bot = load_script(self).is_bot
        for name, email, bot in (('Tal', 'talbot@example.com', False), ('Abbot Lee', 'abbot@example.com', False),
                                 ('dependabot[bot]', '49699333+dependabot[bot]@users.noreply.github.com', True),
                                 ('CI', 'ci-bot@example.com', True), ('Builder', 'bot@example.com', True),
                                 ('Deploy', 'deploy.bot@example.com', True), ('Release', 'release_bot@x.io', True),
                                 ('Tagger', 'me+bot@x.io', True), ('Renovate', 'renovate@whitesourcesoftware.com', True),
                                 ('github-actions', 'actions@github.com', True), ('Renovator', 'renovator@x.io', False),
                                 ('Sam', 'sam@renovatesolutions.com', False), ('Ann', 'ann.botha@example.com', False),
                                 ('Project bot', 'project_123_bot_0a1b2c3d4e5f@noreply.gitlab.example.com', True),
                                 ('x', 'group_45_bot_9f8e7d6c@noreply.gitlab.example.com', True),
                                 ('x', 'project_123_bot@noreply.gitlab.example.com', True),
                                 ('x', 'project123_bot4@noreply.gitlab.example.com', True),
                                 ('x', 'group7_bot@gitlab.example.com', True),
                                 ('Pat', 'project_manager@example.com', False), ('Pat', 'group_leader@example.com', False),
                                 ('Release Bot', 'release@example.com', True), ('Deploy (bot)', 'deploy@example.com', True),
                                 ('BOT', 'x@example.com', True), ('Talbot', 'tal@example.com', False),
                                 ('Bot Hunter', 'hunter@example.com', False),
                                 ('Jane', 'jane@renovate-corp.com', False), ('Jane', 'jane@dependabot.example.com', False),
                                 ('renovate[bot]', '29139614+renovate[bot]@users.noreply.github.com', True),
                                 ('Jane', 'renovate@example.com', True), ('Jane', '29139614+renovate[bot]@users.noreply.github.com', True)):
            with self.subTest(email=email):
                self.assertEqual(is_bot(name, email), bot)

    def test_bot_patterns_exclude_authors_and_are_recorded(self):
        now = dt.datetime.now(dt.timezone.utc)
        self.git('init', '-q', '-b', 'main')

        def commit_as(name, email, message):
            stamp = (now - dt.timedelta(minutes=1)).strftime('%Y-%m-%dT%H:%M:%S+00:00')
            env = dict(GIT_ENV, GIT_AUTHOR_NAME=name, GIT_AUTHOR_EMAIL=email, GIT_AUTHOR_DATE=stamp, GIT_COMMITTER_DATE=stamp)
            self.commit(message, {'lib/a.dart': f'// {message}\n'}, env=env)

        commit_as('Ann', 'ann@example.com', 'ann')
        commit_as('Jenkins CI', 'builds@example.com', 'jenkins')
        commit_as('Pipeline', 'pipeline@ci.example.com', 'pipeline')
        commit_as('Jane', 'jane@renovate-corp.com', 'jane')
        args = ('--root', str(self.root), '--dir', str(self.art), '--lang', 'dart', '--source', 'lib')
        result = self.cli('inventory', *args)
        facts = json.loads((self.art / 'inventory.json').read_text(encoding='utf-8'))['git']
        self.assertEqual(facts['peakMonthlyContributors'], 4)
        self.assertEqual((facts['botsExcluded'], facts['botPatterns']), ([], []))
        self.assertNotIn('--bot', result.stderr)
        result = self.cli('inventory', *args, '--bot', 'JENKINS*', '--bot', '*@ci.example.com', '--bot', 'ghost*',
                          '--bot', 'JENKINS*')
        facts = json.loads((self.art / 'inventory.json').read_text(encoding='utf-8'))['git']
        self.assertEqual(facts['peakMonthlyContributors'], 2)  # Ann and Jane: the renovate-corp domain is no bot
        self.assertEqual(facts['botsExcluded'], ['Jenkins CI <builds@example.com>', 'Pipeline <pipeline@ci.example.com>'])
        self.assertEqual(facts['botPatterns'], ['*@ci.example.com', 'JENKINS*', 'ghost*'])
        self.assertIn('--bot ghost* matched no author', result.stderr)
        self.assertNotIn('--bot JENKINS*', result.stderr)
        self.assertNotIn('--bot *@ci.example.com', result.stderr)

    def test_bot_patterns_without_history_are_still_recorded(self):
        self.write({'lib/a.dart': 'class A {}\n'})
        self.cli('inventory', '--root', str(self.root), '--dir', str(self.art), '--lang', 'dart', '--source', 'lib',
                 '--no-git', '--bot', 'ci*')
        facts = json.loads((self.art / 'inventory.json').read_text(encoding='utf-8'))['git']
        self.assertEqual((facts['botsExcluded'], facts['botPatterns'], facts['reason']), (None, ['ci*'], '--no-git'))

    def test_inventory_never_writes_through_a_symlink(self):
        self.write({'lib/a.dart': 'class A {}\n', 'keep.txt': 'precious\n'})
        (self.art / 'files.tsv').symlink_to(self.root / 'keep.txt')
        result = self.cli('inventory', '--root', str(self.root), '--dir', str(self.art), '--lang', 'dart',
                          '--source', 'lib', '--no-git', ok=False)
        self.assertEqual(result.returncode, 1)
        self.assertIn(f'{self.art / "files.tsv"} is a symlink', result.stderr)
        self.assertEqual((self.root / 'keep.txt').read_text(), 'precious\n')
        self.assertFalse((self.art / 'inventory.json').exists())

    def test_contributors_count_only_commits_touching_the_sources(self):
        now = dt.datetime.now(dt.timezone.utc)
        self.git('init', '-q', '-b', 'main')

        def commit_as(name, path):
            stamp = now.strftime('%Y-%m-%dT%H:%M:%S+00:00')
            env = dict(GIT_ENV, GIT_AUTHOR_NAME=name, GIT_AUTHOR_EMAIL=f'{name.lower()}@example.com',
                       GIT_AUTHOR_DATE=stamp, GIT_COMMITTER_DATE=stamp)
            self.commit(f'{name} {path}', {path: f'// {name}\n'}, env=env)

        commit_as('Ann', 'apps/a/lib/a.dart')
        commit_as('Bob', 'apps/a/lib/b.dart')
        commit_as('Cy', 'apps/b/lib/c.dart')
        commit_as('Dee', 'apps/b/lib/d.dart')
        commit_as('Eve', 'README.md')

        def facts(*sources, root=None):
            root = root or self.root
            self.cli('inventory', '--root', str(root), '--dir', str(self.art), '--lang', 'dart',
                     *(arg for source in sources for arg in ('--source', source)))
            return json.loads((self.art / 'inventory.json').read_text(encoding='utf-8'))['git']

        one = facts('apps/a/lib')
        self.assertEqual((one['peakMonthlyContributors'], one['contributors90d']), (2, 2))  # Ann, Bob
        self.assertEqual(one['contributorPaths'], ['apps/a/lib'])
        both = facts('apps/b/lib', 'apps/a/lib')
        self.assertEqual((both['peakMonthlyContributors'], both['contributors90d']), (4, 4))
        self.assertEqual(both['contributorPaths'], ['apps/a/lib', 'apps/b/lib'])
        whole = facts('.')
        self.assertEqual((whole['peakMonthlyContributors'], whole['contributorPaths']), (5, ['.']))
        below = facts('lib', root=self.root / 'apps' / 'b')  # --root below the repository top
        self.assertEqual(below['peakMonthlyContributors'], 2)  # Cy, Dee
        self.assertEqual(one['firstCommitDate'], whole['firstCommitDate'])  # the age stays repo-wide

    def test_lang_none_needs_extensions(self):
        self.write({'db/a.sql': 'select 1;\n'})
        result = self.cli('inventory', '--root', str(self.root), '--dir', str(self.art), '--lang', 'none',
                          '--source', 'db', '--no-git', ok=False)
        self.assertNotEqual(result.returncode, 0)
        files, _ = self.inventory('none', '--no-git', '--ext', 'sql', sources=('db',))
        self.assertEqual(files, {'db/a.sql': (1, 'src')})

    def test_git_facts(self):
        now = dt.datetime.now(dt.timezone.utc)
        self.git('init', '-q', '-b', 'main')

        def commit_as(name, email, when, message):
            stamp = when.strftime('%Y-%m-%dT%H:%M:%S+00:00')
            env = dict(GIT_ENV, GIT_AUTHOR_NAME=name, GIT_AUTHOR_EMAIL=email, GIT_AUTHOR_DATE=stamp,
                       GIT_COMMITTER_DATE=stamp)
            self.commit(message, {'lib/a.dart': f'// {message}\n'}, env=env)

        commit_as('Old Timer', 'old@example.com', now - dt.timedelta(days=730), 'first')
        recent = [now - dt.timedelta(minutes=minutes) for minutes in range(9, 0, -1)]
        if recent[0].month != now.month:  # keep every recent commit in the current month
            recent = [now] * len(recent)
        commit_as('Ann', 'ann@example.com', recent[0], 'ann')
        commit_as('Ann Work', 'ann@work.example', recent[1], 'ann work')
        commit_as('Bob', 'bob@example.com', recent[2], 'bob')
        commit_as('Tal', 'talbot@example.com', recent[3], 'tal')
        commit_as('dependabot[bot]', '49699333+dependabot[bot]@users.noreply.github.com', recent[4], 'bot')
        commit_as('Renovate Bot', 'bot@renovateapp.com', recent[5], 'renovate')
        commit_as('CI', 'ci-bot@example.com', recent[6], 'ci')
        commit_as('Release Bot', 'release@example.com', recent[7], 'release')
        commit_as('Pipeline', 'project_9_bot_ab12cd34@noreply.gitlab.example.com', recent[8], 'pipeline')
        self.write({'.mailmap': 'Ann <ann@example.com> Ann Work <ann@work.example>\n'})
        self.commit('mailmap')  # authored by Ann through GIT_ENV
        _, summary = self.inventory('dart', sources=('lib',))
        facts = summary['git']
        self.assertEqual((facts['isShallow'], facts['reason']), (False, None))
        self.assertEqual((facts['peakMonthlyContributors'], facts['contributors90d']), (3, 3))  # Ann, Bob, Tal
        self.assertEqual(facts['botsExcluded'], [
            'CI <ci-bot@example.com>', 'Pipeline <project_9_bot_ab12cd34@noreply.gitlab.example.com>',
            'Release Bot <release@example.com>', 'Renovate Bot <bot@renovateapp.com>',
            'dependabot[bot] <49699333+dependabot[bot]@users.noreply.github.com>'])
        self.assertEqual(facts['botPatterns'], [])
        self.assertIn(facts['ageDays'], (729, 730))
        self.assertEqual(facts['firstCommitDate'][:10], (now - dt.timedelta(days=730)).strftime('%Y-%m-%d'))


if __name__ == '__main__':
    unittest.main(verbosity=1)
