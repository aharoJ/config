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
NATIVE = runpy.run_path(str(Path(__file__).resolve().with_name('panel-dispatch-native.py')))


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

    def collect_fixture(self, kind='fable'):
        f = self.fixture
        roster = [dict(seat_id=f.seat['seat_id'], attempt_id=f.seat['attempt_id'], transport=kind,
                      window='owned-test', model='model-observed', effort='low',
                      accepted_limitations=['outside-writes-not-confined'] if kind == 'gemini' else [])]
        f.panel['packet']['projection_review'] = f.proof('collector-projection', dict(
            canonical_input=f.intake_ref, delivered_input=f.panel['packet']['delivered_input'],
            prompt=f.panel['packet']['prompt'], exclusion_pass=True, fidelity_pass=True,
            independent=True, unknown_fields=[]))
        launcher = f.proof('collector-launcher', dict(adapter=API['adapter'](), launcher_version='1',
            authorized=True, tai_sha256=API['ref'](API['REPO'] / 'fish/internal/tmux/tai.fish')['sha256'],
            trust_sha256=API['ref'](API['TOOLS'] / 'panel-seat-trust')['sha256']))
        policy = f.proof('collector-policy', dict(authorized=True, authorized_at=API['now'](),
            max_redispatches=0, technical_causes=[], exhaustion='non-response'))
        first = f.proof('collector-first', dict(project_root=str(f.root), roster=roster,
            authorized=True, independent=True, prior_attempts=[]))
        request = dict(version='1', project_root=str(f.root), protocol_root=str(PROTOCOL), **f.identity,
            session='owned-test', packet=f.panel['packet'], roster=roster, launcher_ref=launcher,
            redispatch_policy_ref=policy, first_attempt_ref=first, deadline_seconds=1,
            authorized=True, authorized_at=API['now']())
        request_ref = API['fresh'](f.external / 'collector-request.json', request)
        prepared_ref = API['prepare'](SimpleNamespace(request=request_ref['path'],
            sha256=request_ref['sha256'], batch=str(f.external / 'collector-batch')))
        prepared = API['read'](prepared_ref)
        folder = Path(prepared['seats'][0]['directory'])
        self.addCleanup(lambda: __import__('shutil').rmtree(folder))
        seat = dict(prepared['seats'][0], pane={'test': 'owned'}, launched_at=API['now'](),
                    delivery=dict(native_start='codex: ' + API['START']))
        launch = dict(phase='launched', context=f.identity, request_ref=request_ref,
            prepared_ref=prepared_ref, adapter=API['adapter'](), batch=prepared['batch'], seats=[seat])
        launch_ref = API['fresh'](f.external / 'fixture-launched.json', launch)
        native_case = NATIVE['NativeTests']()
        native_case.folder = folder
        native_case.prompt = API['read'](request['packet']['prompt'], json_proof=False).decode()
        native_case.intake = API['read'](request['packet']['delivered_input'], json_proof=False).decode()
        native_case.seat = seat
        rows = native_case.rows()
        for row in rows:
            row['timestamp'] = API['now']()
        native_ref = API['fresh'](f.external / 'fixture-native.jsonl',
            b''.join((json.dumps(row) + '\n').encode() for row in rows))
        bound = dict(seat_id=seat['seat_id'], attempt_id=seat['attempt_id'], session_id='session-a')
        final = 'Grounded reasoning.\nVerdict: PASS\n'
        boundary = f.proof('collector-boundary', dict(**bound, native_ref=native_ref, descendants=[],
            launch_ref=launch_ref, pane=seat['pane'], session_binding_verified=True,
            final_sha256=__import__('hashlib').sha256(final.encode()).hexdigest(), raw_verdict='PASS',
            independent=True, isolation_pass=True, external_input_pass=True))
        index = API['fresh'](f.external / 'fixture-native-index.json', dict(context=f.identity,
            launch_ref=launch_ref, seats=[dict(seat_id=seat['seat_id'], attempt_id=seat['attempt_id'],
            native_ref=native_ref, format=API['KINDS'][kind], descendants=[], boundary_review_ref=boundary,
            account_ref=None)]))
        result = API['collect'](SimpleNamespace(launched=launch_ref['path'], sha256=launch_ref['sha256'],
            native_index=index['path'], native_sha256=index['sha256']))
        collected = API['read'](result)
        f.panel['seats'] = [collected['seats'][0]['canonical_record_only_seat']]
        f.seat = f.panel['seats'][0]
        f.attempt = f.seat['attempts'][0]
        f.bound = bound
        f.panel['redispatch_policy_ref'] = policy
        f.dispatch.update(packet=copy.deepcopy(f.panel['packet']), launcher_ref=launcher,
                          redispatch_policy_ref=policy, seats=copy.deepcopy(f.panel['seats']))
        f.panel['identity_records'] = [record for record in f.panel['identity_records']
                                      if record['role'] != 'seat']
        f.decision_roles()
        f.refresh()
        return launch_ref, result

    def test_actual_collect_output_reaches_owner_consumer(self):
        self.collect_fixture()
        self.assertEqual(API['read'](self.verify())['status'], 'PASS')

    def test_actual_collected_final_mutation_refused_by_owner(self):
        self.collect_fixture()
        Path(self.fixture.attempt['final_ref']['path']).chmod(0o600)
        Path(self.fixture.attempt['final_ref']['path']).write_text('substituted final')
        with self.assertRaises(ValueError):
            self.verify()

    def test_actual_collected_qualified_account_reaches_owner_consumer(self):
        self.collect_fixture()
        self.fixture.qualified()
        result = API['read'](self.verify())
        self.assertEqual(result['qualification_mode'], 'qualified')
        self.assertIn(self.fixture.seat['seat_id'], result['pass_sources'])

    def test_cleanup_actual_collected_missing_preservation_refused(self):
        launch, collected = self.collect_fixture()
        value = API['read'](collected)
        value['seats'][0]['final_ref'] = None
        path = Path(collected['path'])
        path.chmod(0o600)
        path.write_text(json.dumps(value))
        with self.assertRaisesRegex(ValueError, 'admitted preservation missing'):
            self.cleanup_until_target(launch, API['ref'](path))

    def test_actual_collected_current_session_substitution_refused(self):
        self.collect_fixture()
        self.fixture.attempt['session_id'] = 'wrong-current-session'
        with self.assertRaises(ValueError):
            self.verify()

    def test_actual_agy_collector_refuses_admission(self):
        with self.assertRaisesRegex(ValueError, 'Agy automatic admission unqualified'):
            self.collect_fixture('gemini')

    def test_two_authorized_requests_cannot_start_same_round(self):
        launch, collected = self.collect_fixture()
        first_ref = API['read'](launch)['request_ref']
        first = API['read'](first_ref)
        second = copy.deepcopy(first)
        second['roster'][0]['attempt_id'] = 'two'
        second['first_attempt_ref'] = self.fixture.proof('second-first', dict(
            project_root=second['project_root'], roster=second['roster'], independent=True,
            authorized=True, prior_attempts=[]))
        second_ref = API['fresh'](self.directory / 'second-request.json', second)
        runtime = API['claim_launch'].__globals__
        with mock.patch.dict(runtime, launch_slot=lambda request: self.directory / 'claim.json'):
            API['request_check'](first_ref)
            API['claim_launch'](first, first_ref)
            with self.assertRaisesRegex(ValueError, 'another current attempt'):
                API['request_check'](second_ref)
            with self.assertRaises(FileExistsError):
                API['claim_launch'](first, first_ref)
            self.assertEqual(API['read'](API['ref'](self.directory / 'claim.json'))['request_ref'], first_ref)

    def test_existing_round_ledger_refuses_first_attempt_claim(self):
        launch, collected = self.collect_fixture()
        reference = API['read'](launch)['request_ref']
        request = API['read'](reference)
        state = Path(request['project_root']) / 'reviews' / request['topic'] / 'state' / request['cycle_type']
        state.mkdir(parents=True)
        (state / ('resolve-r' + str(request['round']) + '.json')).write_text('{}')
        with self.assertRaisesRegex(ValueError, 'existing round ledger'):
            API['request_check'](reference)

    def test_replacement_authority_cannot_revive_predecessor(self):
        launch, collected = self.collect_fixture()
        reference = API['read'](launch)['request_ref']
        request = API['read'](reference)
        proof = API['read'](request['first_attempt_ref'])
        proof['prior_attempts'] = ['failed-predecessor']
        request['first_attempt_ref'] = API['fresh'](self.directory / 'replacement-proof.json', proof)
        replacement = API['fresh'](self.directory / 'replacement-request.json', request)
        with self.assertRaisesRegex(ValueError, 'replacements unsupported'):
            API['request_check'](replacement)

    def test_cross_request_and_cross_batch_launch_are_refused(self):
        runtime = API['claim_launch'].__globals__
        context = dict(topic='test', cycle_type='implementation', cycle='one', round=1)
        proof = API['fresh'](self.directory / 'first.json', dict(context=context,
            project_root=str(self.fixture.root), roster=[], authorized=True, independent=True, prior_attempts=[]))
        request = dict(**context, project_root=str(self.fixture.root), roster=[], first_attempt_ref=proof)
        reference = dict(path='request-one', sha256='0' * 64)
        with mock.patch.dict(runtime, launch_slot=lambda request: self.directory / 'slot.json'):
            API['claim_launch'](request, reference)
            with self.assertRaisesRegex(ValueError, 'another current attempt'):
                API['first_attempt_check'](request, dict(path='request-two', sha256='1' * 64))
            with self.assertRaises(FileExistsError):
                API['claim_launch'](request, reference)

    def retention_fixture(self, observed=False):
        context = self.fixture.identity
        launcher = API['fresh'](self.directory / 'cleanup-launcher.json', dict(context=context, adapter=API['adapter']()))
        request = API['fresh'](self.directory / 'cleanup-request.json', dict(**context, authorized=True, session='owned-test', launcher_ref=launcher))
        seat = dict(seat_id='a', attempt_id='one', window='owned-window')
        batch = self.directory / 'cleanup-batch'
        batch.mkdir()
        prepared = dict(context=context, request_ref=request, batch=str(batch),
                        adapter=API['adapter'](), seats=[seat, dict(seat_id='not-launched', attempt_id='one')])
        prepared['phase'] = 'prepared'
        prepared_ref = API['fresh'](batch / 'prepared.json', prepared)
        launch = dict(prepared, phase='owned-launch', prepared_ref=prepared_ref, seats=[seat])
        launch_ref = API['fresh'](self.directory / 'cleanup-owned.json', launch)
        native = API['fresh'](self.directory / 'cleanup-native.jsonl', b'preserved native finding\n') if observed else None
        index = API['fresh'](self.directory / 'cleanup-index.json', dict(context=context, launch_ref=launch_ref,
            seats=[dict(**seat, cause='failed before native observation' if not observed else 'unqualified native',
                        native_ref=native, non_observation=not observed)]))
        retained_ref = API['retain'](SimpleNamespace(launched=launch_ref['path'], sha256=launch_ref['sha256'],
            native_index=index['path'], native_sha256=index['sha256'], output=str(self.directory / 'cleanup-retained.json')))
        return launch_ref, retained_ref

    def cleanup_until_target(self, launch, retained):
        runtime = API['cleanup'].__globals__
        run = mock.Mock()
        with mock.patch.dict(runtime, exact_pane=mock.Mock(side_effect=ValueError('owned target reached')), run=run):
            try:
                API['cleanup'](SimpleNamespace(launched=launch['path'], sha256=launch['sha256'],
                    collected=retained['path'], collected_sha256=retained['sha256'],
                    output=str(self.directory / 'cleanup-out.json')))
            finally:
                run.assert_not_called()

    def test_partial_launch_retention_explicit_nonobservation_accepted(self):
        launch, retained = self.retention_fixture()
        with self.assertRaisesRegex(ValueError, 'owned target reached'):
            self.cleanup_until_target(launch, retained)

    def test_partial_launch_retained_native_accepted(self):
        launch, retained = self.retention_fixture(True)
        with self.assertRaisesRegex(ValueError, 'owned target reached'):
            self.cleanup_until_target(launch, retained)

    def test_cleanup_wrong_phase_refused_before_any_target(self):
        launch, retained = self.retention_fixture()
        value = API['read'](retained)
        value['phase'] = 'anything-at-all'
        bad = API['fresh'](self.directory / 'bad.json', value)
        with self.assertRaisesRegex(ValueError, 'typed preserved'):
            self.cleanup_until_target(launch, bad)

    def test_cleanup_wrong_batch_refused_before_any_target(self):
        launch, retained = self.retention_fixture()
        value = API['read'](retained)
        value['batch'] = '/wrong-batch'
        bad = API['fresh'](self.directory / 'bad.json', value)
        with self.assertRaisesRegex(ValueError, 'retention chain'):
            self.cleanup_until_target(launch, bad)

    def test_cleanup_wrong_context_refused_before_any_target(self):
        launch, retained = self.retention_fixture()
        value = API['read'](retained)
        value['context']['round'] += 1
        bad = API['fresh'](self.directory / 'bad.json', value)
        with self.assertRaisesRegex(ValueError, 'context/source'):
            self.cleanup_until_target(launch, bad)

    def test_cleanup_missing_retained_native_refused_before_any_target(self):
        launch, retained = self.retention_fixture(True)
        value = API['read'](retained)
        value['seats'][0]['native_session_ref'] = None
        bad = API['fresh'](self.directory / 'bad.json', value)
        with self.assertRaisesRegex(ValueError, 'retained native provenance'):
            self.cleanup_until_target(launch, bad)

    def test_cleanup_missing_nonobservation_cause_refused_before_any_target(self):
        launch, retained = self.retention_fixture()
        value = API['read'](retained)
        value['seats'][0]['cause'] = ''
        bad = API['fresh'](self.directory / 'bad.json', value)
        with self.assertRaisesRegex(ValueError, 'non-observation/retention cause'):
            self.cleanup_until_target(launch, bad)

    def test_spawn_receipt_precedes_fallible_process_snapshot(self):
        runtime = API['own'].__globals__
        context = self.fixture.identity
        request = API['fresh'](self.directory / 'own-request.json', dict(session='owned-test'))
        batch = self.directory / 'own-batch'
        batch.mkdir()
        seat = dict(seat_id='a', attempt_id='one', window='owned-window', directory=str(self.directory))
        prepared = API['fresh'](self.directory / 'own-prepared.json', dict(context=context,
            request_ref=request, batch=str(batch), adapter=API['adapter'](), seats=[seat]))
        pane = dict(pane_id='%1', window_id='@1', pid='123', cwd=str(self.directory))
        calls = []
        def identity(pid):
            self.assertTrue((batch / 'a-spawn-intent.json').exists())
            self.assertTrue((batch / 'a-spawn.json').exists())
            calls.append(pid)
            if len(calls) == 1:
                raise ValueError('transient snapshot failure')
            return dict(pid=123)
        with mock.patch.dict(runtime, exact_pane=lambda *args: pane, process_identity=identity):
            receipt = API['own'](SimpleNamespace(prepared=prepared['path'], sha256=prepared['sha256'],
                seat_id='a', pane='%1'))
        self.assertEqual(API['read'](receipt)['phase'], 'owned-launch')
        self.assertEqual(len(calls), 2)

    def test_launch_error_runs_prestart_recovery_without_retry(self):
        runtime = API['launch'].__globals__
        recovery = mock.Mock()
        record = dict(batch=str(self.directory))
        with mock.patch.dict(runtime, read=lambda reference: record, recover_prestart=recovery,
            launch_prestart=mock.Mock(side_effect=ValueError('post-spawn failure'))):
            with self.assertRaisesRegex(ValueError, 'post-spawn failure'):
                API['launch'](SimpleNamespace(prepared='prepared', sha256='0' * 64))
        recovery.assert_called_once()

    def test_possible_start_never_uses_prestart_nonobservation_recovery(self):
        runtime = API['launch'].__globals__
        recovery = mock.Mock()
        (self.directory / 'starts-entered.json').write_text('{}')
        with mock.patch.dict(runtime, read=lambda reference: dict(batch=str(self.directory)),
            recover_prestart=recovery, launch_prestart=mock.Mock(side_effect=ValueError('delivery unknown'))):
            with self.assertRaisesRegex(ValueError, 'delivery unknown'):
                API['launch'](SimpleNamespace(prepared='prepared', sha256='0' * 64))
        recovery.assert_not_called()

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
                             claim_launch=lambda *args: {},
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
        launch = dict(context={}, batch=str(self.directory), adapter=API['adapter'](), request_ref={}, prepared_ref={}, seats=[dict(seat_id='a', attempt_id='one')])
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
