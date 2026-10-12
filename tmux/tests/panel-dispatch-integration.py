#!/usr/bin/env python3
import copy
import json
import os
from pathlib import Path
import runpy
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest import mock

sys.dont_write_bytecode = True
PROTOCOL = Path(os.environ.get('PANEL_PROTOCOL_ROOT', str(Path.home() / '.skills/review-protocol'))).resolve()
sys.path.insert(0, str(PROTOCOL))
from tests.test_agentic_consumers import Fixture

API = runpy.run_path(str(Path(__file__).resolve().parents[1] / 'tools/panel-dispatch'))


class IntegrationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name).resolve()
        self.fixture = Fixture(self.directory)
        f = self.fixture
        current_adapter = API['adapter']()
        f.adapter = current_adapter
        f.panel['adapter'] = current_adapter
        f.dispatch['adapter'] = current_adapter
        launcher = f.proof('launcher', dict(adapter=current_adapter, launcher_version='1'))
        f.dispatch['launcher_ref'] = launcher
        f.attempt['launcher_ref'] = launcher
        f.dispatch['seats'] = copy.deepcopy(f.panel['seats'])
        f.refresh()

    def verify(self, fixture=None):
        f = fixture or self.fixture
        ledger_path = f.external / 'candidate-ledger.json'
        ledger_path.write_text(json.dumps(f.ledger))
        output = f.external / 'verified.json'
        if output.exists():
            output.unlink()
        return API['verify'](SimpleNamespace(protocol_root=str(PROTOCOL), project_root=str(f.root),
                    dispatch=f.authority['path'], sha256=f.authority['sha256'], ledger=str(ledger_path),
                    ledger_sha256=API['ref'](ledger_path)['sha256'], output=str(output)))

    def test_real_consumer_record_only(self):
        result = API['read'](self.verify())
        self.assertEqual(result['status'], 'PASS')
        self.assertEqual(result['qualification_mode'], 'record_only')
        self.assertIn('a', result['pass_sources'])

    def test_real_consumer_qualified(self):
        self.fixture.qualified()
        self.assertEqual(API['read'](self.verify())['qualification_mode'], 'qualified')

    def test_material_account_deficiency_only_floor(self):
        f = self.fixture
        f.removal()
        result = API['read'](self.verify())
        self.assertNotIn('a', result['pass_sources'])
        self.assertTrue(f.seat['admitted'])
        self.assertTrue(f.seat['responding'])
        self.assertEqual(f.seat['raw_verdict'], 'PASS')

    def test_missing_native_bytes_refused(self):
        Path(self.fixture.attempt['native_session_ref']['path']).unlink()
        with self.assertRaises(ValueError):
            self.verify()

    def test_stale_final_hash_refused(self):
        Path(self.fixture.attempt['final_ref']['path']).write_text('changed')
        with self.assertRaises(ValueError):
            self.verify()

    def test_wrong_selected_session_refused(self):
        self.fixture.attempt['session_id'] = 'wrong'
        with self.assertRaises(ValueError):
            self.verify()

    def test_candidate_cannot_self_activate(self):
        self.fixture.panel['activation']['mode'] = 'qualified'
        with self.assertRaises(ValueError):
            self.verify()

    def test_no_canonical_projection_fallback(self):
        f = self.fixture
        bad = f.proof('projection', dict(canonical_input=f.intake_ref, delivered_input=f.panel['packet']['delivered_input'], exclusion_pass=False, fidelity_pass=True))
        f.panel['packet']['projection_review'] = bad
        f.dispatch['packet'] = copy.deepcopy(f.panel['packet'])
        f.refresh()
        with self.assertRaises(ValueError):
            self.verify()

    def test_false_account_deficiency_is_limitation(self):
        f = self.fixture
        f.qualified()
        f.attempt['account_ref'] = f.proof('account', dict(**f.bound, final_ref=f.attempt['final_ref'],
            grounded_reasoning='Grounded static inspection.', material_limitations=['No native action record.'],
            material_deficiency=True, kind='qualified_absence', necessary_record_action_claim=True,
            complete_bound_coverage=False, qualified_event_decoding=True))
        f.dispatch['seats'] = copy.deepcopy(f.panel['seats'])
        f.refresh()
        self.assertIn('a', API['read'](self.verify())['pass_sources'])

    def test_shared_native_final_inode_refused(self):
        f = self.fixture
        final = Path(f.attempt['final_ref']['path'])
        final.unlink()
        os.link(f.attempt['native_session_ref']['path'], final)
        f.attempt['final_ref'] = API['ref'](final)
        f.dispatch['seats'] = copy.deepcopy(f.panel['seats'])
        f.refresh()
        with self.assertRaises(ValueError):
            self.verify()

    def test_launch_preflight_refusal_sends_nothing(self):
        runtime = API['launch'].__globals__
        with mock.patch.dict(runtime, read=lambda reference: {}, prepared_check=mock.Mock(side_effect=ValueError('post-launch gate'))):
            with mock.patch.dict(runtime, run=mock.Mock()) as ignored:
                with self.assertRaises(ValueError):
                    API['launch'](SimpleNamespace(prepared='/not-used', sha256='0' * 64))
                runtime['run'].assert_not_called()

    def test_symlink_evidence_refused(self):
        linked = self.directory / 'linked'
        linked.symlink_to(self.fixture.intake)
        with self.assertRaises(ValueError):
            API['ref'](linked)

    def test_post_launch_gate_refusal_sends_no_start(self):
        runtime = API['launch'].__globals__
        folder = self.directory / 'seat'
        folder.mkdir()
        batch = self.directory / 'batch'
        batch.mkdir()
        seat = dict(seat_id='a', attempt_id='one', transport='astra', window='new-seat',
                    model='gpt-6-sol', effort='low', directory=str(folder), inputs={})
        record = dict(batch=str(batch), seats=[seat], context={}, request_ref={})
        request = dict(session='private-test', deadline_seconds=1)
        pane = dict(command='codex', cwd=str(folder), pid='123', pane_id='%1', window_id='@1')
        relay = mock.Mock()
        gate = mock.Mock(side_effect=[request, ValueError('unexpected runtime file')])
        with mock.patch.dict(runtime, read=lambda reference: record, prepared_check=gate,
                             panes=lambda session: [], exact_pane=lambda *args: pane,
                             run=lambda *args, **kwargs: '', fresh=lambda *args: {},
                             process_identity=lambda pid: {}, ref=lambda path: {'sha256': '0' * 64}, relay_start=relay):
            with self.assertRaisesRegex(ValueError, 'unexpected runtime file'):
                API['launch'](SimpleNamespace(prepared='unused', sha256='0' * 64))
        self.assertEqual(gate.call_args_list[1], mock.call(record, runtime=True))
        relay.assert_not_called()

    def test_nested_symlink_evidence_refused(self):
        linked = self.directory / 'linked'
        linked.symlink_to(self.fixture.external, target_is_directory=True)
        with self.assertRaises(ValueError):
            API['ref'](linked / 'native.txt')

    def test_wait_exhaustion_is_nonresponse_without_retry(self):
        runtime = API['wait'].__globals__
        launch_ref = dict(path='launch', sha256='0' * 64)
        seat = dict(seat_id='a', attempt_id='one', transport='astra')
        launch = dict(request_ref={}, context={}, batch=str(self.directory), seats=[seat])
        locations = dict(context={}, launch_ref=launch_ref,
                         seats=[dict(seat_id='a', attempt_id='one', native_path='/missing')])
        def read(reference):
            return launch if reference['path'] == 'launch' else locations
        with mock.patch.dict(runtime, read=read, request_check=lambda reference: {'deadline_seconds': 0}):
            output = API['wait'](SimpleNamespace(launched='launch', sha256='0' * 64,
                locations='locations', locations_sha256='1' * 64, output=str(self.directory / 'wait.json')))
        result = API['read'](output)
        self.assertEqual(result['automatic_redispatches'], 0)
        self.assertTrue(result['seats'][0]['exhausted'])
        self.assertFalse(result['seats'][0]['candidate'])
        self.assertIn('non-response', result['seats'][0]['accounting'])

    def test_unadmitted_native_findings_are_retained_without_votes(self):
        runtime = API['retain'].__globals__
        launch_ref = dict(path='launch', sha256='0' * 64)
        launch = dict(context={}, batch=str(self.directory), seats=[dict(seat_id='a', attempt_id='one')])
        raw = self.directory / 'raw.jsonl'
        raw.write_bytes(b'{"finding":"real lead needs reproduction"}\n')
        native_ref = API['ref'](raw)
        index = dict(context={}, launch_ref=launch_ref, seats=[dict(seat_id='a', attempt_id='one',
                     cause='unsupported envelope', native_ref=native_ref)])
        original_read = API['read']
        def read(reference, **kwargs):
            if reference['path'] == 'launch':
                return launch
            if reference['path'] == 'index':
                return index
            return original_read(reference, **kwargs)
        with mock.patch.dict(runtime, read=read):
            output = API['retain'](SimpleNamespace(launched='launch', sha256='0' * 64,
                native_index='index', native_sha256='1' * 64, output=str(self.directory / 'retained.json')))
        retained = API['read'](output)['seats'][0]
        self.assertEqual(API['read'](retained['native_session_ref'], json_proof=False), raw.read_bytes())
        self.assertFalse(retained['admitted'])
        self.assertFalse(retained['pass_floor_eligible'])
        self.assertIsNone(retained['raw_verdict'])

    def test_deep_json_refused(self):
        with self.assertRaises(ValueError):
            API['decode']('[' * 33 + '0' + ']' * 33)

    def test_duplicate_json_refused(self):
        with self.assertRaises(ValueError):
            API['decode']('{"x":1,"x":2}')


if __name__ == '__main__':
    unittest.main(verbosity=2)
