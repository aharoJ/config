#!/usr/bin/python3
"""Offline tests only; no native client, tmux, or user's session log is read."""
import json
import sqlite3
import tempfile
from pathlib import Path
import runpy
import unittest

O = runpy.run_path(str(Path(__file__).parent / 'fixtures/keeper_oracles.py'))
PROBE = runpy.run_path(str(Path(__file__).parent / 'fixtures/window-native-e2e.py'))['PROBE']

def snapshot(screen, meta, client, expected):
    return O['draft_snapshot'](screen, meta, client, expected, PROBE)

SESSION = '11111111-2222-4333-8444-555555555555'
WIRE = b'source (session:source): #k63_unit Reply K63_OK.'


class Keepers(unittest.TestCase):
    def test_full_native_turn_not_normalized_or_fragment_matched(self):
        native = dict(type='user', sessionId=SESSION, isSidechain=False, uuid='turn-1',
                      message=dict(role='user', content=[dict(type='text', text=WIRE.decode())]))
        data = (json.dumps(native) + '\n').encode()
        turns = O['claude_turns'](data, SESSION)
        self.assertTrue(O['exact_turn'](turns, WIRE))
        item = json.dumps(dict(type='userMessage', content=[dict(type='text', text=WIRE.decode())]))
        self.assertTrue(O['exact_turn'](O['codex_turns']([item]), WIRE))
        for actual in [[], [WIRE, WIRE], [WIRE + b'\n'], [WIRE.replace(b': #', b':  #')], [b'#k63_unit']]:
            self.assertFalse(O['exact_turn'](actual, WIRE))
        for invalid in [data[:-1], data.replace(SESSION.encode(), b'foreign-session'),
                        data.replace(b'"text"', b'"image"')]:
            with self.assertRaises(ValueError):
                O['claude_turns'](invalid, SESSION)
        self.assertFalse(O['exact_turn'](O['claude_turns'](data + data, SESSION), WIRE))
        with self.assertRaises(ValueError):
            O['codex_turns']([json.dumps(dict(type='userMessage', content=[dict(type='image')]))])

    def test_native_draft_complete_exact_and_identity_bound(self):
        meta = ('7', '1', '80', '4', '0', '0', '%900', '123', '/dev/ttys999', '1', '2', '/native')
        screen = '\n\x1b[1m›\x1b[0m draft\n\n  model · context'
        before = snapshot(screen, meta, 'codex', b'draft')
        self.assertEqual(before, snapshot(screen, meta, 'codex', b'draft'))
        changed_identity = meta[:7] + ('124',) + meta[8:]
        self.assertNotEqual(before, snapshot(screen, changed_identity, 'codex', b'draft'))
        for changed, metadata in [(screen.replace('draft', 'drift'), meta),
                                  (screen.replace('draft', 'draft!'), meta),
                                  (screen.replace('\n\n  model · context', '\nextra line\nfooter'), meta),
                                  (screen, ('6',) + meta[1:]),
                                  (screen + '\n', meta),
                                  (screen.replace('draft', '\x1b[8mdraft'), meta)]:
            with self.assertRaises(ValueError):
                snapshot(changed, metadata, 'codex', b'draft')
        ghost = '\n› \x1b[2mplaceholder\x1b[0m\n\n  model · context'
        self.assertEqual(snapshot(ghost, ('2',) + meta[1:], 'codex', b'')[1], b'')

    def test_claude_nbsp_uses_rust_and_refusal_is_diagnosable(self):
        meta = ('2', '0', '20', '3', '0', '0', '%900', '123', '/dev/ttys999')
        screen = '❯\u00a0\n────────────────────\n'
        self.assertEqual(snapshot(screen, meta, 'claude', b'')[1], b'')
        private = '❯\u00a0private123\n────────────────────\n'
        meta = ('12',) + meta[1:]
        with self.assertRaises(ValueError) as caught:
            snapshot(private, meta, 'claude', b'wrong')
        self.assertEqual(str(caught.exception),
                         'expected=exact-draft; composer::screen=Hold; composer::classify=Draft')
        fixture = json.dumps(caught.exception.fixture)
        self.assertNotIn('private123', fixture)
        self.assertIn('xxxxxxxxxx', fixture)

    def test_probe_masks_every_prompt_and_box_glyph_in_draft(self):
        meta = ('9', '0', '20', '3', '0', '0', '%900', '123', '/synthetic')
        for glyph in '❯›─━│':
            with self.subTest(glyph=glyph), self.assertRaises(ValueError) as caught:
                snapshot('❯\u00a0' + glyph + 'secret\n────────────────────\n',
                         meta, 'claude', b'different')
            fixture = caught.exception.fixture
            self.assertTrue(fixture['all_visible_text_masked'])
            self.assertTrue(all(ch == 'x' or ch.isspace() for ch in fixture['capture']))
            self.assertTrue(fixture['capture'].startswith('x\u00a0xxxxxxx\n'))
            self.assertEqual(fixture['glyph'], '❯')

    def test_rust_startup_readiness_without_banner_and_masked_refusal(self):
        controller = runpy.run_path(str(Path(__file__).parent / 'fixtures/window-native-e2e.py'))
        fixture = (Path(__file__).parent / 'fixtures/codex-162-empty-composer.ansi').read_text().removesuffix('\n')
        meta = ('2', '0', '215', '3', '0', '0', '%900', '123', '/synthetic')
        predicates = controller['startup_predicates'](fixture)
        self.assertFalse(predicates['banner'])
        self.assertFalse(predicates['model'])
        reports = []
        self.assertEqual(O['draft_snapshot'](fixture, meta, 'codex', b'', PROBE, report=reports.append)[1], b'')
        self.assertTrue(reports[0]['accepted'])
        self.assertEqual(reports[0]['reason'], 'expected=empty; composer::screen=Empty; composer::classify=EmptyCandidate')
        reports = []
        with self.assertRaises(ValueError) as caught:
            O['draft_snapshot']('startup notice\n\n', meta, 'codex', b'', PROBE, report=reports.append)
        self.assertFalse(reports[0]['accepted'])
        self.assertEqual(str(caught.exception), 'expected=empty; composer::screen=Hold; composer::classify=Unrecognized')
        self.assertTrue(all(ch == 'x' or ch.isspace() for ch in caught.exception.fixture['capture']))

    def test_unpersisted_fresh_session_is_empty_not_missing_file(self):
        with tempfile.TemporaryDirectory(prefix='k71-session-') as name:
            home = Path(name)
            with sqlite3.connect(home / 'state_5.sqlite') as db:
                db.execute('CREATE TABLE threads (id TEXT,cwd TEXT,cli_version TEXT,created_at_ms INTEGER,history_mode TEXT)')
            with sqlite3.connect(home / 'thread_history_1.sqlite') as db:
                db.execute('CREATE TABLE thread_items (thread_id TEXT,item_type TEXT,rollout_ordinal INTEGER,item_json TEXT)')
            self.assertEqual(O['native_turns']('codex', SESSION, Path('/fixture'), 100, codex_home=home), [])
            with sqlite3.connect(home / 'state_5.sqlite') as db:
                db.execute('INSERT INTO threads VALUES (?,?,?,?,?)', (SESSION, '/fixture', '0.162.1', 100, 'paginated'))
            with sqlite3.connect(home / 'thread_history_1.sqlite') as db:
                item = json.dumps(dict(type='userMessage', content=[dict(type='text', text=WIRE.decode())]))
                db.execute('INSERT INTO thread_items VALUES (?,?,?,?)', (SESSION, 'userMessage', 1, item))
            self.assertTrue(O['exact_turn'](O['native_turns']('codex', SESSION, Path('/fixture'), 100, codex_home=home), WIRE))
            (home / 'state_5.sqlite').unlink()
            with self.assertRaises(FileNotFoundError) as caught:
                O['native_turns']('codex', SESSION, Path('/fixture'), 100, codex_home=home)
            self.assertEqual(caught.exception.filename, str(home / 'state_5.sqlite'))

    def test_pending_history_is_dispatch_barrier(self):
        valid = [['pending-no-input']]
        self.assertTrue(O['pending_no_input'](6, valid))
        self.assertFalse(O['pending_no_input'](0, valid))
        self.assertFalse(O['pending_no_input'](6, valid + valid))
        for state in ['input-intent', 'pasted', 'submit-intent', 'submitted', 'input-unknown']:
            self.assertFalse(O['pending_no_input'](6, [[state, 'pending-no-input']]))


if __name__ == '__main__':
    unittest.main()
