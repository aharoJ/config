#!/usr/bin/env python3
# path: ~/.config/tmux/tests/codex-new-ansi-variants.py
# description: Preserve visible attributes while varying SGR resets and ordering.
# date: 2026-10-03
import re

sgr = re.compile(r'\x1b\[([0-9;]*)m')


def update(state, parameters):
    values = list(map(int, parameters.split(';'))) if parameters else [0]
    i = 0
    concealed = False
    while i < len(values):
        value = values[i]
        if value == 0:
            state.clear()
        elif value in (1, 2, 3, 4, 7, 8, 9):
            state[value] = (value,)
            concealed = concealed or value == 8
        elif value == 22:
            state.pop(1, None)
            state.pop(2, None)
        elif value in (23, 24, 27, 28, 29):
            state.pop(value - 20, None)
        elif value in (39, 49):
            state.pop(38 if value == 39 else 48, None)
        elif 30 <= value <= 37 or 90 <= value <= 97:
            state[38] = (value,)
        elif 40 <= value <= 47 or 100 <= value <= 107:
            state[48] = (value,)
        elif value in (38, 48):
            if i + 1 >= len(values) or values[i + 1] not in (2, 5):
                raise ValueError(parameters)
            length = 5 if values[i + 1] == 2 else 3
            group = tuple(values[i:i + length])
            if len(group) != length or any(x > 255 for x in group[2:]):
                raise ValueError(parameters)
            state[value] = group
            i += length - 1
        else:
            raise ValueError(parameters)
        i += 1
    return concealed


def trace(capture):
    state, result, offset = {}, [], 0
    for match in sgr.finditer(capture):
        result.extend((char, tuple(sorted(state.items()))) for char in capture[offset:match.start()])
        update(state, match[1])
        offset = match.end()
    result.extend((char, tuple(sorted(state.items()))) for char in capture[offset:])
    return result


def canonical(capture, reverse=False, split=False, selective=False):
    state, emitted, output, offset = {}, {}, [], 0
    concealed = False

    def text(value):
        nonlocal emitted, concealed
        if not value:
            return
        groups = []
        if selective:
            if (emitted.get(1) and not state.get(1)) or (emitted.get(2) and not state.get(2)):
                groups.append((22,))
            for attr in (3, 4, 7, 8, 9):
                if emitted.get(attr) and not state.get(attr):
                    groups.append((attr + 20,))
            for attr, clear in ((38, 39), (48, 49)):
                if emitted.get(attr) and not state.get(attr):
                    groups.append((clear,))
        else:
            groups.append((0,))
        if concealed and 8 not in state:
            groups.extend([(8,), (28,)])
        attrs = [state[key] for key in sorted(state, reverse=reverse)]
        groups.extend(attrs)
        if not groups:
            groups.append((22,))
        if groups:
            if split:
                output.extend('\x1b[' + ';'.join(map(str, group)) + 'm' for group in groups)
            else:
                output.append('\x1b[' + ';'.join(str(x) for group in groups for x in group) + 'm')
        output.append(value)
        emitted = state.copy()
        concealed = False

    for match in sgr.finditer(capture):
        text(capture[offset:match.start()])
        concealed = update(state, match[1]) or concealed
        offset = match.end()
    text(capture[offset:])
    return ''.join(output)


def variants(capture):
    results = [('original', capture), ('duplicate-sgr', sgr.sub(lambda m: m[0] + m[0], capture)), ('edge-resets', '\x1b[0m\x1b[0m' + capture + '\x1b[0m\x1b[0m')]
    try:
        original = trace(capture)
        results.extend([
            ('full-state', canonical(capture)),
            ('reordered-state', canonical(capture, reverse=True)),
            ('split-state', canonical(capture, reverse=True, split=True)),
            ('without-full-resets', canonical(capture, selective=True)),
            ('split-without-full-resets', canonical(capture, reverse=True, split=True, selective=True)),
        ])
        for name, variant in results:
            assert trace(variant) == original, ('attribute variance changed visible intensity or styling', name)
    except ValueError:
        pass
    return results
