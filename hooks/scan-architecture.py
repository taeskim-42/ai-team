#!/usr/bin/env python3
"""
Scan project source tree and generate ARCHITECTURE.md.
Gives LLMs a persistent "mental map" so they don't waste context exploring.

Inspired by Gas Town's persistent state approach:
  agents are stateless → give them a map instead of making them explore.

Usage: python3 scan-architecture.py <project-root>
"""

import os, re, sys
from pathlib import Path
from datetime import datetime
from collections import defaultdict

IGNORE_DIRS = {
    '.git', 'node_modules', '.next', 'dist', 'build', 'out', '.nuxt',
    '__pycache__', '.claude', 'vendor', 'target', '.dart_tool',
    'coverage', '.nyc_output', '.pytest_cache', '.mypy_cache',
    'Pods', '.build', 'DerivedData', 'bin', 'obj', '.svelte-kit',
    '.turbo', '.vercel', '.output', '.gen',
}

# Directories whose files are listed as summary only (not individually)
GENERATED_DIRS = {'generated', 'Generated', 'gen', '__generated__'}

SOURCE_EXTS = {
    '.ts', '.tsx', '.js', '.jsx', '.mjs',
    '.py', '.go', '.swift', '.rb',
    '.rs', '.java', '.kt', '.php',
    '.dart', '.cs', '.scala',
}

LAYER_KEYWORDS = {
    'domain':         ['domain', 'entities', 'core', 'value-objects', 'aggregates'],
    'application':    ['application', 'usecases', 'use-cases', 'use_cases', 'services', 'commands', 'queries'],
    'infrastructure': ['infrastructure', 'infra', 'adapters', 'persistence', 'external', 'data-source', 'repositories'],
    'presentation':   ['presentation', 'controllers', 'handlers', 'routes', 'views', 'pages', 'screens', 'ui', 'api'],
}

# Symbol extraction patterns per language
_TS = [
    (r'export\s+(?:default\s+)?(?:abstract\s+)?class\s+(\w+)', 'class'),
    (r'export\s+(?:default\s+)?interface\s+(\w+)', 'interface'),
    (r'export\s+(?:default\s+)?type\s+(\w+)', 'type'),
    (r'export\s+(?:default\s+)?(?:async\s+)?function\s+(\w+)', 'fn'),
    (r'export\s+const\s+(\w+)\s*=', 'const'),
]
_PY = [
    (r'^class\s+(\w+)', 'class'),
    (r'^def\s+(\w+)', 'fn'),
]
_GO = [
    (r'^type\s+(\w+)\s+struct', 'struct'),
    (r'^type\s+(\w+)\s+interface', 'interface'),
    (r'^func\s+(\w+)\s*\(', 'fn'),
]
_SWIFT = [
    (r'(?:public\s+|open\s+)?class\s+(\w+)', 'class'),
    (r'(?:public\s+)?struct\s+(\w+)', 'struct'),
    (r'(?:public\s+)?protocol\s+(\w+)', 'protocol'),
    (r'(?:public\s+)?enum\s+(\w+)', 'enum'),
]
_RS = [
    (r'pub\s+struct\s+(\w+)', 'struct'),
    (r'pub\s+trait\s+(\w+)', 'trait'),
    (r'pub\s+enum\s+(\w+)', 'enum'),
    (r'pub\s+(?:async\s+)?fn\s+(\w+)', 'fn'),
]
_JAVA = [
    (r'(?:public\s+)?(?:abstract\s+)?class\s+(\w+)', 'class'),
    (r'(?:public\s+)?interface\s+(\w+)', 'interface'),
    (r'(?:public\s+)?enum\s+(\w+)', 'enum'),
]
_RB = [(r'^class\s+(\w+)', 'class'), (r'^\s*module\s+(\w+)', 'module')]
_DART = [(r'class\s+(\w+)', 'class'), (r'enum\s+(\w+)', 'enum')]
_PHP = [(r'class\s+(\w+)', 'class'), (r'interface\s+(\w+)', 'interface')]

SYMBOL_PATTERNS = {
    '.ts': _TS, '.tsx': _TS, '.js': _TS, '.jsx': _TS, '.mjs': _TS,
    '.py': _PY, '.go': _GO, '.swift': _SWIFT, '.rs': _RS,
    '.java': _JAVA, '.kt': _JAVA, '.cs': _JAVA, '.scala': _JAVA,
    '.rb': _RB, '.dart': _DART, '.php': _PHP,
}

SOURCE_ROOTS = {'src', 'lib', 'app', 'pkg', 'internal', 'packages', 'modules', 'apps'}


def _is_in_generated(filepath):
    """Check if file is inside a generated directory."""
    parts = filepath.split('/')
    return any(p in GENERATED_DIRS for p in parts)


def find_source_files(root):
    """Walk tree, return source file paths relative to root."""
    files = []
    generated_count = 0
    root_p = Path(root)
    for dirpath, dirnames, filenames in os.walk(root_p):
        dirnames[:] = [d for d in sorted(dirnames)
                       if d not in IGNORE_DIRS and not d.startswith('.')]
        rel_dir = Path(dirpath).relative_to(root_p)
        for fname in sorted(filenames):
            if Path(fname).suffix in SOURCE_EXTS:
                rel_path = str(rel_dir / fname)
                if _is_in_generated(rel_path):
                    generated_count += 1
                else:
                    files.append(rel_path)
    return files, generated_count


def classify_layer(filepath):
    """Detect architectural layer from file path."""
    parts = filepath.lower().replace('\\', '/').split('/')
    for layer, keywords in LAYER_KEYWORDS.items():
        if any(kw in parts for kw in keywords):
            return layer
    return None


def extract_symbols(root, filepath):
    """Extract key exported symbols from a source file."""
    ext = Path(filepath).suffix
    patterns = SYMBOL_PATTERNS.get(ext, [])
    if not patterns:
        return []
    try:
        content = (Path(root) / filepath).read_text(errors='ignore')
    except OSError:
        return []

    seen, symbols = set(), []
    for pattern, kind in patterns:
        for m in re.finditer(pattern, content, re.MULTILINE):
            name = m.group(1)
            if name.startswith('_') and ext in ('.py', '.go'):
                continue
            if name not in seen:
                seen.add(name)
                symbols.append((name, kind))
    return symbols


def detect_modules(files):
    """Group files into modules. Returns {module_name: [(filepath, layer)]}."""
    first_dirs = {f.split('/')[0] for f in files if '/' in f}
    has_src_root = bool(first_dirs & SOURCE_ROOTS)

    # Detect monorepo (packages/X/ or apps/X/)
    monorepo_roots = first_dirs & {'packages', 'apps', 'modules'}

    modules = defaultdict(list)
    for filepath in files:
        parts = filepath.split('/')
        if len(parts) <= 1:
            module = '(root)'
        elif parts[0] in monorepo_roots and len(parts) > 2:
            module = f"{parts[0]}/{parts[1]}"
        elif has_src_root and parts[0] in SOURCE_ROOTS and len(parts) > 2:
            module = parts[1]
        elif parts[0] in ('test', 'tests', 'spec', 'specs', '__tests__'):
            module = '(tests)'
        else:
            module = parts[0]
        modules[module].append((filepath, classify_layer(filepath)))
    return dict(modules)


def detect_imports(root, files, modules):
    """Best-effort cross-module import detection."""
    module_names = set(modules.keys()) - {'(root)', '(tests)'}
    if len(module_names) < 2:
        return set()

    deps = set()
    file_to_module = {}
    for mod, mod_files in modules.items():
        for fp, _ in mod_files:
            file_to_module[fp] = mod

    for filepath in files:
        current = file_to_module.get(filepath)
        if not current or current in ('(root)', '(tests)'):
            continue
        try:
            content = (Path(root) / filepath).read_text(errors='ignore')
        except OSError:
            continue
        for other in module_names:
            if other == current:
                continue
            # Match import/from/require referencing other module
            if re.search(rf"""(?:import|from|require)\s*[\(]?\s*['"].*[/\\]{re.escape(other)}[/\\'"s]""", content):
                deps.add((current, other))
    return deps


def generate_markdown(root, modules, deps, generated_count=0):
    """Produce ARCHITECTURE.md content."""
    project = Path(root).name
    now = datetime.now().strftime('%Y-%m-%d %H:%M')
    total = sum(len(fs) for fs in modules.values())
    layers_used = {layer for fs in modules.values() for _, layer in fs if layer}

    lines = [
        f'# Architecture Map — {project}',
        '',
        f'> Auto-generated by ai-team. Last updated: {now}  ',
        f'> **Read this FIRST** before exploring the codebase.',
        '',
        '## Overview',
        f'- {len(modules)} modules, {total} source files',
    ]
    if generated_count:
        lines.append(f'- {generated_count} generated files (excluded from map)')
    if layers_used:
        lines.append(f'- Layers: {", ".join(sorted(layers_used))}')
    if deps:
        lines.append(f'- {len(deps)} cross-module dependencies')
    lines.append('')

    # Modules
    lines.append('## Modules')
    lines.append('')

    layer_order = ['domain', 'application', 'infrastructure', 'presentation', None]
    for mod_name in sorted(modules.keys()):
        mod_files = modules[mod_name]
        lines.append(f'### {mod_name}/')

        by_layer = defaultdict(list)
        for fp, layer in mod_files:
            by_layer[layer].append(fp)

        for layer in layer_order:
            if layer not in by_layer:
                continue
            if layer and layers_used:
                lines.append(f'**{layer}**')
            for fp in sorted(by_layer[layer]):
                syms = extract_symbols(root, fp)
                if syms:
                    s = ', '.join(f'`{n}`({k})' for n, k in syms[:6])
                    if len(syms) > 6:
                        s += f' +{len(syms)-6} more'
                    lines.append(f'- `{fp}` — {s}')
                else:
                    lines.append(f'- `{fp}`')
        lines.append('')

    # Dependencies
    if deps:
        lines.append('## Cross-module Dependencies')
        for src, dst in sorted(deps):
            lines.append(f'- {src} → {dst}')
        lines.append('')

    return '\n'.join(lines)


def main():
    if len(sys.argv) < 2:
        print('Usage: scan-architecture.py <project-root>', file=sys.stderr)
        sys.exit(1)

    root = sys.argv[1]
    if not os.path.isdir(root):
        print(f'Error: {root} is not a directory', file=sys.stderr)
        sys.exit(1)

    files, generated_count = find_source_files(root)
    if not files:
        sys.exit(0)

    modules = detect_modules(files)
    deps = detect_imports(root, files, modules)
    md = generate_markdown(root, modules, deps, generated_count)

    out = os.path.join(root, 'ARCHITECTURE.md')
    with open(out, 'w') as f:
        f.write(md)

    print(f'ARCHITECTURE.md updated ({len(files)} files, {len(modules)} modules)', file=sys.stderr)


if __name__ == '__main__':
    main()
