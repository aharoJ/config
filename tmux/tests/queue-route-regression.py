#!/usr/bin/env python3
import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import time
import unittest
from unittest.mock import patch

TOOLS = Path(__file__).resolve().parents[1] / 'tools'


def load(name):
    loader = importlib.machinery.SourceFileLoader(name.replace('-', '_'), str(TOOLS / name))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


queue = load('cc-msg-queue')
clear = load('relay-clear-draft')


class RouteTests(unittest.TestCase):
    def test_denied_enqueue_precedes_sweep_persistence_and_capture(self):
        env = dict(CC_MSG_SESSION='other', CC_MSG_WINDOW='claude')
        for args in (['queue', 'payload'], ['queue', '--operator', 'payload']):
            with patch.dict(os.environ, env), patch.object(queue.sys, 'argv', args), patch.object(queue, 'routing_source', side_effect=queue.RoutingError('cross-session send refused')), patch.object(queue, 'sweep') as sweep, patch.object(queue, 'save') as save, patch.object(queue, 'identity') as identity:
                with self.assertRaises(queue.RoutingError):
                    queue.main()
                sweep.assert_not_called()
                save.assert_not_called()
                identity.assert_not_called()

    def test_legacy_worker_refuses_before_screen_or_delivery(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'legacy.json'
            path.write_text(json.dumps(dict(id='legacy', state='queued', deadline=time.time() + 60, environment={}, identity={})))
            with patch.object(queue, 'routing_source', side_effect=queue.RoutingError('cross-session send refused')), patch.object(queue, 'identity') as identity, patch.object(queue, 'stable_screen') as screen, patch.object(queue, 'deliver') as deliver:
                queue.worker(path)
                identity.assert_not_called()
                screen.assert_not_called()
                deliver.assert_not_called()
            data = json.loads(path.read_text())
            self.assertEqual((data['state'], data['code']), ('failed', 1))

    def test_worker_source_change_precedes_screen_and_retry(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'queued.json'
            target = dict(pane='%2')
            path.write_text(json.dumps(dict(id='queued', state='queued', deadline=time.time() + 60, environment={}, identity=target, source=dict(pane='%1'))))
            with patch.object(queue, 'routing_source', side_effect=[dict(pane='%1'), queue.RoutingError('cross-session send refused')]), patch.object(queue.time, 'sleep'), patch.object(queue, 'identity', return_value=target), patch.object(queue, 'stable_screen') as screen, patch.object(queue, 'deliver') as deliver:
                queue.worker(path)
                screen.assert_not_called()
                deliver.assert_not_called()
            self.assertEqual(json.loads(path.read_text())['code'], 1)

    def test_recovery_proves_record_source_in_its_worker(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            target = root / 'target'
            target.mkdir()
            path = target / 'legacy.json'
            path.write_text(json.dumps(dict(id='legacy', state='queued', deadline=time.time() + 60, environment={})))
            with patch.object(queue, 'ROOT', root), patch.object(queue, 'routing_source', side_effect=queue.RoutingError('cross-session send refused')) as route, patch.object(queue, 'launch_worker') as launch:
                queue.sweep()
                route.assert_not_called()
                launch.assert_called_once()
                self.assertEqual(json.loads(path.read_text())['state'], 'queued')
                with patch.object(queue, 'deliver') as deliver, patch.object(queue, 'identity') as identity:
                    queue.worker(path)
                    deliver.assert_not_called()
                    identity.assert_not_called()
            self.assertEqual(json.loads(path.read_text())['code'], 1)

    def test_denied_clear_precedes_persistence(self):
        with patch.dict(os.environ, dict(CC_MSG_SESSION='other', CC_MSG_WINDOW='claude')), patch.object(clear.sys, 'argv', ['clear', 'claude', '--expect', 'x']), patch.object(clear.queue, 'routing_source', side_effect=clear.queue.RoutingError('cross-session send refused')), patch.object(clear.queue, 'save') as save, patch.object(clear, 'request') as request:
            self.assertEqual(clear.main(), 1)
            save.assert_not_called()
            request.assert_not_called()

    def test_clear_final_proof_rechecks_bound_record(self):
        plan = dict(record='/bound/record.json', environment={}, identity={})
        with patch.object(clear.queue, 'routing_source', side_effect=clear.queue.RoutingError('cross-session send refused')) as route, patch.object(clear.queue, 'identity') as identity:
            with self.assertRaises(clear.Refused):
                clear.prove(plan)
            route.assert_called_once_with({}, '/bound/record.json')
            identity.assert_not_called()

    def test_transport_carries_bound_record_not_source_env_grant(self):
        process = type('Process', (), {'returncode': 0, 'communicate': lambda self, text, timeout: ('done', '')})()
        with patch.object(queue.subprocess, 'Popen', return_value=process) as launch:
            queue.transport(dict(message='payload', identity=None, record='/bound/record.json', source=dict(pane='%1')), {})
        self.assertEqual(launch.call_args.kwargs['env']['RELAY_MESSAGE_RECORD'], '/bound/record.json')
        self.assertNotIn('RELAY_SOURCE', launch.call_args.kwargs['env'])


if __name__ == '__main__':
    unittest.main()
