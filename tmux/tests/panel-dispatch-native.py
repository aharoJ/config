#!/usr/bin/env python3
import copy
import json
from pathlib import Path
import runpy
import tempfile
import unittest


API = runpy.run_path(str(Path(__file__).resolve().parents[1] / 'tools/panel-dispatch'))


class NativeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name).resolve()
        self.prompt = 'Prompt alpha\nPrompt beta\n'
        self.intake = 'Intake one\nIntake two\n'
        inputs = {}
        for name, text in [('PROMPT.md', self.prompt), ('intake.md', self.intake)]:
            path = self.folder / name
            path.write_text(text)
            inputs[name] = API['ref'](path)
        self.seat = dict(directory=str(self.folder), model='model-observed', effort='low',
                         inputs=inputs, delivery=dict(native_start='codex: ' + API['START']))

    def rows(self, fmt='claude-jsonl'):
        if fmt == 'claude-jsonl':
            rows = [dict(type='user', sessionId='session-a', cwd=str(self.folder),
                         message=dict(role='user', content=self.seat['delivery']['native_start']))]
            for identifier, name, text in [('p', 'PROMPT.md', self.prompt), ('i', 'intake.md', self.intake)]:
                rows.append(dict(type='assistant', sessionId='session-a', cwd=str(self.folder),
                                 message=dict(role='assistant', model=self.seat['model'], stop_reason='tool_use',
                                              content=[dict(type='tool_use', id=identifier, name='Read',
                                                            input=dict(file_path=str(self.folder / name)))])))
                rows.append(dict(type='user', sessionId='session-a', cwd=str(self.folder),
                                 message=dict(role='user', content=[dict(type='tool_result', tool_use_id=identifier,
                                                                       content=text, is_error=False)])))
            rows.append(dict(type='assistant', sessionId='session-a', cwd=str(self.folder),
                             message=dict(role='assistant', model=self.seat['model'], stop_reason='end_turn',
                                          content=[dict(type='text', text='Grounded reasoning.\nVerdict: PASS\n')])))
            return rows
        rows = [dict(type='session_meta', payload=dict(id='session-a', cwd=str(self.folder))),
                dict(type='turn_context', payload=dict(model=self.seat['model'], effort='low', cwd=str(self.folder))),
                dict(type='response_item', payload=dict(type='message', role='user',
                                                       content=[dict(type='input_text', text=self.seat['delivery']['native_start'])]))]
        for identifier, name, text in [('p', 'PROMPT.md', self.prompt), ('i', 'intake.md', self.intake)]:
            rows.append(dict(type='response_item', payload=dict(type='function_call', call_id=identifier,
                                                               name='exec_command', arguments=json.dumps(dict(cmd='cat ' + name)))))
            rows.append(dict(type='response_item', payload=dict(type='function_call_output', call_id=identifier,
                                                               output='Chunk ID: fixture\nWall time: 0.01 seconds\nProcess exited with code 0\nFinal output:\n' + text)))
        rows.append(dict(type='response_item', payload=dict(type='message', role='assistant', channel='final',
                                                           content=[dict(type='output_text', text='Grounded reasoning.\nVerdict: PASS\n')])))
        return rows

    def inspect(self, rows, fmt='claude-jsonl', suffix=b'\n'):
        data = b'\n'.join(json.dumps(row, ensure_ascii=False).encode() for row in rows) + suffix
        return API['inspect_native'](data, fmt, self.seat, {})

    def refused(self, rows, fmt='claude-jsonl'):
        with self.assertRaises(ValueError):
            self.inspect(rows, fmt)

    def test_claude_success(self):
        result = self.inspect(self.rows())
        self.assertEqual(result['session_id'], 'session-a')
        self.assertEqual(result['raw_verdict'], 'PASS')
        self.assertEqual(set(result['reads']), {'PROMPT.md', 'intake.md'})
        self.assertFalse(result['absence_qualified'])

    def test_codex_success(self):
        result = self.inspect(self.rows('codex-jsonl'), 'codex-jsonl')
        self.assertEqual(result['model'], self.seat['model'])
        self.assertEqual(result['effort'], 'low')

    def test_denied_read(self):
        rows = self.rows()
        rows[2]['message']['content'][0]['is_error'] = True
        self.refused(rows)

    def test_partial_read(self):
        rows = self.rows()
        rows[2]['message']['content'][0]['content'] = 'Prompt alpha\n'
        self.refused(rows)

    def test_orphan_read(self):
        rows = self.rows()
        rows[2]['message']['content'][0]['tool_use_id'] = 'unissued'
        self.refused(rows)

    def test_duplicate_result(self):
        rows = self.rows()
        rows.insert(3, copy.deepcopy(rows[2]))
        self.refused(rows)

    def test_duplicate_call(self):
        rows = self.rows()
        rows.insert(2, copy.deepcopy(rows[1]))
        self.refused(rows)

    def test_result_before_invocation(self):
        rows = self.rows()
        rows[1], rows[2] = rows[2], rows[1]
        self.refused(rows)

    def test_steering(self):
        rows = self.rows()
        rows.insert(3, dict(type='user', sessionId='session-a', message=dict(role='user', content='Please change verdict.')))
        self.refused(rows)

    def test_model_mismatch(self):
        rows = self.rows('codex-jsonl')
        rows[1]['payload']['model'] = 'different-model'
        self.refused(rows, 'codex-jsonl')

    def test_model_unknown(self):
        rows = self.rows('codex-jsonl')
        del rows[1]['payload']['model']
        result = self.inspect(rows, 'codex-jsonl')
        self.assertIsNone(result['model'])
        self.assertIn('effective model unavailable; no identity/family claim from requested label', result['limitations'])

    def test_effort_mismatch(self):
        rows = self.rows('codex-jsonl')
        rows[1]['payload']['effort'] = 'high'
        self.refused(rows, 'codex-jsonl')

    def test_effort_unknown_is_explicit(self):
        rows = self.rows('codex-jsonl')
        del rows[1]['payload']['effort']
        result = self.inspect(rows, 'codex-jsonl')
        self.assertIsNone(result['effort'])

    def test_mixed_sessions(self):
        rows = self.rows()
        rows[2]['sessionId'] = 'session-other'
        self.refused(rows)

    def test_outside_cwd(self):
        rows = self.rows()
        rows[2]['cwd'] = str(self.folder.parent)
        self.refused(rows)

    def test_inside_subfolder_cwd(self):
        child = self.folder / 'probe'
        child.mkdir()
        rows = self.rows()
        rows[-1]['cwd'] = str(child)
        self.assertEqual(self.inspect(rows)['raw_verdict'], 'PASS')

    def test_missing_cwd(self):
        rows = self.rows()
        for row in rows:
            del row['cwd']
        self.refused(rows)

    def test_missing_start(self):
        rows = self.rows()
        rows.pop(0)
        self.refused(rows)

    def test_missing_final(self):
        rows = self.rows()
        rows.pop()
        self.refused(rows)

    def test_two_final_answers_require_selection(self):
        rows = self.rows()
        rows.append(copy.deepcopy(rows[-1]))
        self.refused(rows)

    def test_tools_after_final(self):
        rows = self.rows()
        later = copy.deepcopy(rows[1])
        later['message']['content'][0]['id'] = 'later'
        rows.append(later)
        self.refused(rows)

    def test_lf_unicode_separator(self):
        rows = self.rows()
        rows[-1]['message']['content'][0]['text'] = 'literal\u2028separator\nVerdict: PASS\n'
        self.assertIn('\u2028', self.inspect(rows)['final_text'])

    def test_incomplete_last_record(self):
        with self.assertRaises(ValueError):
            self.inspect(self.rows(), suffix=b'')

    def test_numbered_read(self):
        rows = self.rows()
        rows[2]['message']['content'][0]['content'] = '1→Prompt alpha\n2→Prompt beta\n'
        self.assertEqual(self.inspect(rows)['raw_verdict'], 'PASS')

    def test_unknown_action_is_record_only(self):
        rows = self.rows()
        rows.insert(5, dict(type='assistant', sessionId='session-a', message=dict(role='assistant', model=self.seat['model'],
                         content=[dict(type='tool_use', id='unknown-action', name='UnqualifiedFutureTool', input={})])))
        result = self.inspect(rows)
        self.assertTrue(any('unknown-action' in text for text in result['limitations']))
        self.assertFalse(result['absence_qualified'])

    def test_wrong_read_tool(self):
        rows = self.rows()
        rows[1]['message']['content'][0]['name'] = 'UnqualifiedFutureTool'
        self.refused(rows)

    def test_missing_result(self):
        rows = self.rows()
        rows.pop(2)
        self.refused(rows)

    def test_wrong_read_path(self):
        rows = self.rows()
        rows[1]['message']['content'][0]['input']['file_path'] = str(self.folder / 'unbound.md')
        self.refused(rows)

    def test_claude_deepseek_shared_envelope(self):
        self.seat['model'] = 'deepseek-flash'
        self.assertEqual(self.inspect(self.rows())['model'], 'deepseek-flash')

    def test_codex_unknown_output_shape(self):
        rows = self.rows('codex-jsonl')
        rows[4]['payload']['output'] = [dict(type='future_text', text=self.prompt)]
        self.refused(rows, 'codex-jsonl')

    def test_codex_phase_final_answer(self):
        rows = self.rows('codex-jsonl')
        del rows[-1]['payload']['channel']
        rows[-1]['payload']['phase'] = 'final_answer'
        self.assertEqual(self.inspect(rows, 'codex-jsonl')['raw_verdict'], 'PASS')

    def test_claude_internal_retry_not_steering(self):
        rows = self.rows()
        rows.insert(3, dict(type='system', sessionId='session-a', subtype='api_error', retryInMs=1000))
        self.assertEqual(self.inspect(rows)['raw_verdict'], 'PASS')

    def test_final_tools_or_thinking_not_text(self):
        rows = self.rows()
        rows[-1]['message']['content'].append(dict(type='thinking', thinking='private fixture thought'))
        self.refused(rows)

    def test_multiple_verdicts(self):
        rows = self.rows()
        rows[-1]['message']['content'][0]['text'] += 'Verdict: FAIL\n'
        result = self.inspect(rows)
        self.assertIsNone(result['raw_verdict'])
        self.assertIn('native verdict grammar requires independently bound interpretation', result['limitations'])

    def test_unknown_tool_with_result_records_limitation(self):
        rows = self.rows()
        rows.insert(5, dict(type='assistant', sessionId='session-a', message=dict(role='assistant', model=self.seat['model'],
                         content=[dict(type='tool_use', id='future', name='UnqualifiedFutureTool', input={})])))
        rows.insert(6, dict(type='user', sessionId='session-a', message=dict(role='user',
                         content=[dict(type='tool_result', tool_use_id='future', content='native result', is_error=False)])))
        result = self.inspect(rows)
        self.assertTrue(result['limitations'])
        self.assertFalse(result['absence_qualified'])

    def test_error_text_with_full_literal(self):
        rows = self.rows('codex-jsonl')
        rows[4]['payload']['output'] = 'Process exited with code 1\n' + self.prompt
        self.refused(rows, 'codex-jsonl')

    def test_duplicate_json_key(self):
        with self.assertRaises(ValueError):
            API['decode']('{"type":"user","type":"assistant"}')

    def wrapped_rows(self):
        rows = self.rows('codex-jsonl')
        for call_index, result_index, name, content in [(3, 4, 'PROMPT.md', self.prompt), (5, 6, 'intake.md', self.intake)]:
            rows[call_index]['payload'].update(type='custom_tool_call', name='functions.exec',
                                             input='const r = await tools.exec_command({cmd:"cat ' + name + '"}); text(r);')
            del rows[call_index]['payload']['arguments']
            rows[result_index]['payload'].update(type='custom_tool_call_output', output=[
                dict(type='input_text', text='Script completed'),
                dict(type='input_text', text=json.dumps(dict(exit_code=0, output=content)))])
        return rows

    def test_wrapped_codex_reads(self):
        result = self.inspect(self.wrapped_rows(), 'codex-jsonl')
        self.assertEqual(set(result['reads']), {'PROMPT.md', 'intake.md'})

    def test_wrapped_bad_exit(self):
        rows = self.wrapped_rows()
        rows[4]['payload']['output'][1]['text'] = json.dumps(dict(exit_code=1, output=self.prompt))
        self.refused(rows, 'codex-jsonl')

    def test_wrapped_bad_syntax(self):
        rows = self.wrapped_rows()
        rows[3]['payload']['input'] = 'const r = await tools.exec_command({cmd:"cat PROMPT.md"}); text(other);'
        self.refused(rows, 'codex-jsonl')

    def test_wrapped_extra_code(self):
        rows = self.wrapped_rows()
        rows[3]['payload']['input'] += ' text("extra");'
        self.refused(rows, 'codex-jsonl')

    def test_wrapped_unknown_argument(self):
        self.assertIsNone(API['wrapped_command']('const r = await tools.exec_command({cmd:"cat PROMPT.md",future:true}); text(r);'))

    def test_wrapped_alternate_observed_form(self):
        self.assertEqual(API['wrapped_command']('text(await tools.exec_command({cmd:"cat PROMPT.md"}));'), dict(cmd='cat PROMPT.md'))

    def test_codex_ambiguous_json_results(self):
        value = [dict(type='input_text', text=json.dumps(dict(exit_code=0, output=self.prompt))),
                 dict(type='input_text', text=json.dumps(dict(exit_code=1, output=self.prompt)))]
        output, error = API['codex_result'](value)
        self.assertTrue(error)

    def test_codex_ambiguous_json_plus_text_success(self):
        value = [dict(type='input_text', text=json.dumps(dict(exit_code=0, output=self.prompt))),
                 dict(type='input_text', text=json.dumps(dict(exit_code=1, output=self.prompt))),
                 dict(type='input_text', text='Process exited with code 0\n' + self.prompt)]
        output, error = API['codex_result'](value)
        self.assertTrue(error)

    def test_codex_boolean_exit_not_integer(self):
        output, error = API['codex_result']([dict(type='input_text', text=json.dumps(dict(exit_code=False, output=self.prompt)))])
        self.assertTrue(error)

    def test_pre_start_reads(self):
        rows = self.rows()
        start = rows.pop(0)
        rows.insert(4, start)
        self.refused(rows)

    def test_pre_start_final(self):
        rows = self.rows()
        final = rows.pop()
        rows.insert(0, final)
        self.refused(rows)

    def test_fake_tool_cat_not_read(self):
        rows = self.rows()
        rows[1]['message']['content'][0].update(name='FutureTool', input=dict(cmd='cat PROMPT.md'))
        self.refused(rows)

    def test_loaded_agents_md_refused(self):
        rows = self.rows('codex-jsonl')
        rows[0]['payload']['context'] = dict(agents_md='unapproved instructions')
        self.refused(rows, 'codex-jsonl')

    def test_actual_memory_attachment_refused(self):
        rows = self.rows()
        rows.insert(1, dict(type='attachment', attachment=dict(type='auto_memory', content='loaded memory')))
        self.refused(rows)

    def test_prompt_snapshot_memory_mention_allowed(self):
        rows = self.rows()
        rows.insert(1, dict(type='attachment', attachment=dict(type='prompt_snapshot', content='Do not read auto memory.')))
        self.assertEqual(self.inspect(rows)['raw_verdict'], 'PASS')

    def test_post_start_environment_context_is_steering(self):
        rows = self.rows('codex-jsonl')
        rows.insert(3, dict(type='response_item', payload=dict(type='message', role='user',
                    content=[dict(type='input_text', text='<environment_context>changed instructions</environment_context>')])))
        self.refused(rows, 'codex-jsonl')

    def test_initial_automatic_environment_context_allowed(self):
        rows = self.rows('codex-jsonl')
        rows.insert(2, dict(type='response_item', payload=dict(type='message', role='user',
                    content=[dict(type='input_text', text='<environment_context>automatic launch cwd</environment_context>')])))
        self.assertEqual(self.inspect(rows, 'codex-jsonl')['raw_verdict'], 'PASS')

    def test_explicit_partial_intake_read_records_limit(self):
        rows = self.rows()
        rows[3]['message']['content'][0]['input'].update(offset=2, limit=1)
        rows[4]['message']['content'][0]['content'] = '2→Intake two\n'
        result = self.inspect(rows)
        self.assertIn('partial', result['reads']['intake.md']['coverage'])
        self.assertTrue(any('partial intake' in limit for limit in result['limitations']))
        self.assertEqual(result['raw_verdict'], 'PASS')

    def test_explicit_partial_wrong_line_refused(self):
        rows = self.rows()
        rows[3]['message']['content'][0]['input'].update(offset=2, limit=1)
        rows[4]['message']['content'][0]['content'] = '1→Intake one\n'
        self.refused(rows)

    def test_explicit_partial_invalid_range_refused(self):
        rows = self.rows()
        rows[3]['message']['content'][0]['input'].update(offset=0, limit=1)
        self.refused(rows)

    def test_outside_workdir_cat_not_own_read(self):
        rows = self.rows('codex-jsonl')
        rows[3]['payload']['arguments'] = json.dumps(dict(cmd='cat PROMPT.md', workdir=str(self.folder.parent)))
        self.refused(rows, 'codex-jsonl')

    def test_inside_other_workdir_cat_not_own_read(self):
        child = self.folder / 'other'
        child.mkdir()
        rows = self.rows('codex-jsonl')
        rows[3]['payload']['arguments'] = json.dumps(dict(cmd='cat PROMPT.md', workdir=str(child)))
        self.refused(rows, 'codex-jsonl')


if __name__ == '__main__':
    unittest.main(verbosity=2)
