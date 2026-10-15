from pathlib import Path
import argparse,hashlib,json,re

parser=argparse.ArgumentParser()
parser.add_argument('--home',default=str(Path.home()))
parser.add_argument('--repo',default=str(Path.home()/'desk/lab/tmux-to-rust'))
parser.add_argument('--audit',default=str(Path.home()/'desk/audits/relay/rustify/review'))
args=parser.parse_args()
home=Path(args.home)
repo=Path(args.repo)
staged=repo/'tmux/cutover/staged/home'
audit=Path(args.audit)
entries=[]
changes={}
previous=json.loads((audit/'s6x-doc-migration.json').read_text())['entries'] if (audit/'s6x-doc-migration.json').exists() else []

def digest(b):
    return hashlib.sha256(b).hexdigest()

def stage(p,text,reason):
    p=Path(p)
    before=p.read_bytes()
    after=text.encode()
    if before==after:
        return
    dest=staged/p.relative_to(home)
    dest.parent.mkdir(parents=True,exist_ok=True)
    dest.write_bytes(after)
    entries.append(dict(path=str(p),beforehash=digest(before),stagedpath=str(dest),afterhash=digest(after),reason=reason))
    changes[str(p)]=reason

pending='Rust exit 6 means durable `pending-no-input`: the foreground invocation ended before a producer, no background worker survives, and explicit recover is deferred. Retain the exact attempt/archive IDs and originating immutable Rust package/store; inspect status there and arrange an authorized manual disposition without automatic resend. Legacy Python exit 6 remains queue-owned: do not resend and inspect it through its originating Python package.'
uncertain='Rust exit 4 and legacy Python exits 3/4 mean uncertain or potentially partial input; inspect the exact durable attempt without automatic replay.'
verification='For Rust, compare the announcement/status numeric `peer` with the independently verified exact session/window/pane, retaining the originating immutable package, configured store, exact attempt ID and separate archive ID; use that Rust package for `relay status <attempt-id>` and `relay read <archive-id> wire` even after rollback. For legacy Python, inspect the originating Python record and its `target.session_name`; never ask Python to interpret Rust IDs.'
environment='The approved installed Rust dispatcher supplies its recorded `ANGELSTAR_RELAY_STORE` and `ANGELSTAR_RELAY_SOCKET`; callers still provide explicit exact role/session/window routing. Inherited store/socket values must match that deployment; a mismatch refuses. Do not guess defaults, unset a mismatch to bypass it, or point Rust at a Python inbox. Direct source-launcher use needs the separately recorded explicit store/socket. Record the resolved immutable package and transport before sending; after a pointer rollback inspect prior Rust attempts with that recorded Rust package/store, and legacy attempts with their original Python package.'
contract='''## Installed transport contract (Rust cutover and Python rollback)

Use only the installed public helpers after verifying the intended existing visible interactive target. Claude Code messages must use `CC_MSG_SESSION=<session> CC_MSG_WINDOW=<exact-window-name> ~/.local/bin/cc-msg "<one-line pointer>"`; never a headless Claude process or raw `tmux send-keys`. Codex messages use `CODEX_SEND_SESSION=<session> ~/.local/bin/codex-send-to <exact-window-name> "<one-line pointer>"`. Plain `codex-send` also requires explicit `CODEX_SEND_SESSION`; set `CODEX_SEND_WINDOW` for a nondefault exact window. A positional `session:window` is not CC routing. Never guess an index or cached pane ID.

'''+environment+'''

Rust send outcomes: 0 means durable `submitted`, with recipient receipt `unproved`; 1 means validation/routing or proved no-input refusal (administrative operations can also fail with 1); 4 means possible input or unavailable outcome proof, so inspect without replay. '''+pending+''' Rust has no send exits 2/3/5: draft/busy/copy holds wait only while the foreground invocation owns them. Returning 6 does not promise later delivery. Successful help/read/status exits 0 only for that operation; a successful status lookup does not prove submission.

Legacy Python retains its installed contract: 2 is initial copy-mode refusal, 5 is a blocked/draft refusal, 3/4 is uncertain, and 6 is queue-owned. Inspect the actual installed version and retained record before correcting or retrying; do not reinterpret a legacy result as Rust. Never automatically resend an uncertain or pending message, clear a draft, cancel copy mode, or press raw Enter to overcome a refusal.

'''+verification+'''

Rust labels identify the actual verified source as `window (session:window)` (or explicit `relay` when absent), and retain explicit codes or a generated `#r<12hex>` code, including in archive pointers. Do not expect the historical fixed `codex:` prefix or legacy record-path output. Submitted input, echoed code and helper completion do not prove a recipient reply; confirm the exact recipient transcript or a bound task result. Preserve both package versions and stores across rollback, and do not send via Python onto a target with an unsettled Rust attempt.
'''

p=home/'.codex/AGENTS.md'
s=p.read_text()
start=s.index('### Sending CC a message')
end=s.index('## Relay routing',start)
s=s[:start]+contract+'\n'+s[end:]
stage(p,s,'Replace legacy-only helper output/exits with explicit routing, provisioned environment and dual Rust/Python foreground pending contract; retain visible CC requirements.')

skill_roots=[home/'.skills/review-protocol']+sorted((home/'.skills/review-protocol-wt').glob('*'))
for root in skill_roots:
    if not root.is_dir():continue
    p=root/'CLAUDE.md'
    if p.is_file():
        s=p.read_text()
        lines=s.splitlines(keepends=True)
        for i,line in enumerate(lines):
            if '**You CAN message the Codex partner' in line:
                lines[i]='- **You CAN message the Codex partner; it is a verified tmux pane.** Use `CODEX_SEND_SESSION=<exact-session> ~/.local/bin/codex-send-to <exact-window-name> "<one-line pointer>"`; never ask Angel to paste routine traffic or use raw tmux input. The installed Rust dispatcher provisions its recorded store/socket and rejects inherited mismatches; never guess them. Rust exit 6 is foreground pending-no-input with no surviving worker: retain exact attempt/archive IDs, inspect through its originating immutable Rust package/store, and arrange authorized manual disposition without automatic resend (recover is deferred). Rust 4 and legacy 3/4 are uncertain; legacy 6 remains queue-owned. Legacy 2/5 remain installed refusal codes; Rust uses 0/1/4/6. An exit-0 send proves submission only, never a reply. Keep every watcher call bounded to at most 5 s and stop on freeze/timeout. Full routing, rollback, and status rules: `.claude/codex-addressing.md`.\n'
        stage(p,''.join(lines),'Correct active Codex routing and versioned exits/foreground ownership; retain watcher and visible-helper rules.')
    p=root/'.claude/codex-addressing.md'
    if p.is_file():
        s=p.read_text()
        start=s.index('## Copy-mode safety')
        end=s.index('## Monitors and freezes',start)
        s=s[:start]+contract+'\nText sent into a copy-mode pane is interpreted as copy-mode input; never cancel copy mode to force a delivery. Rust waits under its bounded foreground owner; legacy refusal semantics remain versioned above. Helpers serialize their own same-target text/Enter sequences; this is not receipt or an all-or-nothing guarantee. Never use `send-keys -N`, `send-keys -X cursor-down`, numeric `command-prompt`, a cancel key or raw numeric repeat construction to route an agent message.\n\n'+s[end:]
        s=s.replace('codex-send-to codex "<text>"','CODEX_SEND_SESSION=<verified-session> ~/.local/bin/codex-send-to codex "<text>"')
        s=s.replace('own-session resolution, copy-mode checks, a per-target lock, and verification.','explicit-session resolution, copy-mode checks, a per-target lock, and verification.')
        stage(p,s,'Retire missing cc-msg.sh path and implicit-session examples; publish complete rollback-aware Rust/Python transport contract.')
    p=root/'notes/codex-desk/watch-setup.md'
    if p.is_file():
        s=p.read_text()
        start=s.index('## Helpers')
        end=s.index('## Known failure modes',start)
        block='''## Helpers

- Use `CODEX_SEND_SESSION=<verified-session> ~/.local/bin/codex-send-to <exact-window-name> "<one-line pointer>"` for the verified existing Codex pane. Plain `codex-send` requires the same explicit session and defaults only its window to `codex`; set `CODEX_SEND_WINDOW` for another exact window. Never use raw `tmux send-keys` to message an agent.
- The installed Rust dispatcher supplies its approved store/socket, rejecting inherited mismatches. Do not guess or override deployment values. Read `.claude/codex-addressing.md` for the full versioned contract before sending.
- Rust exits 0/1/4/6 mean submitted / no-input refusal / possible input / durable pending-no-input. Exit 6 ends the foreground owner; no worker survives and recover is deferred. Retain exact attempt/archive IDs and the originating immutable Rust package/store; inspect there without automatic resend. Legacy Python 6 remains queue-owned, 2/5 remain its refusal codes, and 3/4 remain uncertain. Keep old records readable through their originating package after rollback. Neither transport proves a reply.
- Launch a second Codex only under the task's current launch authority and installed wrapper contract; this watcher recipe grants no launch, prompt-clear, or replacement authority.

'''
        s=s[:start]+block+s[end:]
        legacy_launch=next((line for line in p.read_text().splitlines() if line.startswith('- Launching a second Codex:')), '')
        if legacy_launch:
            s=s.replace("- Launch a second Codex only under the task's current launch authority and installed wrapper contract; this watcher recipe grants no launch, prompt-clear, or replacement authority.",legacy_launch)
        stage(p,s,'Correct watcher relay examples, implicit routing and old-only exits; distinguish foreground pending from legacy queue ownership.')
    p=root/'notes/codex-desk/operating-model.md'
    if p.is_file():
        s=p.read_text().replace('`~/.local/bin/codex-send`.','`CODEX_SEND_SESSION=<verified-session> CODEX_SEND_WINDOW=<exact-window-name> ~/.local/bin/codex-send "<one-line pointer>"`, following the installed versioned outcome contract in `.claude/codex-addressing.md`.')
        stage(p,s,'Supply required explicit Codex role routing in active relay command and reference current outcome contract.')
    p=root/'notes/codex-desk/recovery-playbook.md'
    if p.is_file():
        s=p.read_text().replace('## The nudge that worked (send via `~/.local/bin/codex-send`)','## The nudge that worked\n\nFor a currently authorized send use `CODEX_SEND_SESSION=<verified-session> CODEX_SEND_WINDOW=<exact-window-name> ~/.local/bin/codex-send "<one-line pointer>"` and the versioned outcomes in `.claude/codex-addressing.md`. A Rust exit 6 ends its foreground pending owner; it does not queue a surviving worker or authorize a resend. The historical nudge below is not delivery or replacement authority.')
        stage(p,s,'Replace implicit-session nudge command with explicit role routing and current foreground-pending warning.')

for rel in ['.skills/net/VISIBLE-ROUTING.md','.skills/net/rehearsal/README.md']:
    p=home/rel
    if p.is_file():stage(p,p.read_text().rstrip()+'\n\n'+contract,'Document provisioned installed environment and dual transport pending/inspection behavior for active Net operator callers; executable migration is separate.')

memory_paths=sorted((home/'.claude/projects').glob('*/memory/*.md'))
for p in memory_paths:
    s=p.read_text()
    original=s
    if p.name=='agent-tmux-operations.md':
        if 'Honor helper results:' in s:
            oldline=re.search(r'Honor helper results:[^\n]*',s).group()
            tail=oldline.partition('Never clear a draft to defeat a refusal')[2]
            replacement=pending+' '+uncertain+' Rust 1 is validation/routing or proved no-input refusal; Rust 0 is submitted with receipt unproved. Legacy 2/5 remain its documented refusal codes. Rust has no 2/3/5 send exits. Never clear a draft to defeat a refusal'+tail
            s=s.replace(oldline,replacement)
        else:
            start=s.index('A send receipt establishes')
            end=s.index('Resolve deployed helper identity',start)
            s=s[:start]+contract+'\n\n'+s[end:]
        s=re.sub(r'Production identity comes from[^\n]*','Production identity comes from resolving each public helper link to its immutable package and recording the transport/configuration before sending; `relay-current` selects new Rust or retained Python packages after enrollment. The unchanged `relay-stable` checkout remains a Python baseline, not the active Rust identity. Worktree edits are not deployment. Test and gate a committed candidate before explicit stable deployment under [[feedback_relay_fix_worktree_flow]]. Check pane-watch and Agy links separately because they are outside the four-surface cutover.',s)
        s=re.sub(r'Current detailed contract and fixtures live[^\n]*',environment+" Consult the originating package's helper source and reviewed manifests; legacy fixtures/README remain in the retained stable checkout. This memory is a retrieval cue, not a replacement implementation contract.",s)
        s=s.replace('Resolve deployed helper identity through each ~/.local/bin link and the relay\nstable Git revision; inspect pane-watch\'s link separately. The installed source\nis the transport contract.','Resolve each ~/.local/bin helper to its immutable package and transport; relay-stable is the retained Python baseline, not active Rust identity. Inspect pane-watch separately. The originating installed package/configuration is the transport contract.')
        s=re.sub(r'- cc-msg target = env only:[^\n]*','- cc-msg target = env only: `CC_MSG_SESSION=<session> CC_MSG_WINDOW=<exact-window-name> ~/.local/bin/cc-msg "<one-line pointer>"`. A positional `session:window` is message text. '+verification+' Rust self-send refuses and has no `--allow-self` mode; read the originating legacy source for any historical mode.',s)
        if contract not in s:
            s=s.rstrip()+'\n\n'+verification+'\n\nRust wire identifies the actual verified sender and retains explicit codes or generated `#r<12hex>` codes, including in archive pointers. A Rust status lookup exiting 0 proves lookup only, not stored submission or a reply. Preserve both transports and stores across rollback; do not send via Python onto an unsettled Rust target.\n'
    elif p.name=='codex-reply-binding.md':
        head=s[:s.index('---',3)+3]
        head=re.sub(r'description:.*','description: Versioned Codex reply transport; historical operator binding is not a Rust recovery or queue recipe',head)
        s=head+'\n\nThe October 2026 StudyWithMe operator-binding incident is historical. Its `relay bind-source --operator` command, newest-thread lookup and promise that an exit-6 message lands later are not current Rust instructions. Rust has no bind-source or recover API. Read the exact installed legacy source before any separately authorized legacy binding; do not infer a thread from the newest cwd match.\n\n'+contract
    else:
        replacements={
            'Exit 6 means the queue owns delivery: do not resend.':pending,
            'Exit 6 means queue-owned delivery; do not resend.':pending,
            'Exit 6 means queue-owned delivery: do not resend;':pending+' ',
            'exit 6 is queue-owned (do not resend)':pending,
            'exit 6 is queue-owned':pending,
            'Exit 3/4 means unknown or potentially partial delivery: inspect before any further action.':uncertain,
            'Exit 3/4 means unknown or partial delivery: inspect before acting again.':uncertain,
            'Exit 3/4 means uncertain or partial delivery; inspect without replay.':uncertain,
            'exit 3/4 means uncertain or partial delivery: inspect without replay.':uncertain,
            'exit 3/4 is uncertain (inspect without replay)':'Rust 4 and legacy 3/4 are uncertain (inspect without replay)',
            'exit 3/4 requires inspection':'Rust 4 and legacy 3/4 require inspection',
            'Exit 3/4 is uncertain and must not be replayed automatically':'Rust 4 and legacy 3/4 are uncertain and must not be replayed automatically',
            'durable queue/exit 6, installed contract and production identity':'versioned Rust foreground pending/Python queue outcomes and immutable package identity',
            'exit 6 queue, installed contract;':'versioned foreground pending/legacy queue contract;',
            'exit 6 queued, 3/4 inspect, never resend':'Rust 6 foreground pending, legacy 6 queued; inspect uncertain outcomes without resend',
            'honor queue-owned outcomes':'honor versioned pending and queue outcomes',
            'honor refusals and queue ownership':'honor refusals, Rust foreground pending and legacy Python queue ownership',
            'Delivery/queue ownership':'Delivery or legacy Python queue ownership',
            'exit 3/4 remains uncertain':'Rust exit 4 and legacy Python exits 3/4 remain uncertain',
            'uncertain/queue-owned message':'uncertain, Rust-pending or legacy-queue-owned message',
            'On a refusal, wait and retry or fix the cause;':'On a refusal, inspect the installed version and outcome before correction; never automatically resend a Rust pending or uncertain result;',
            'Installed codex-send-to documents `--help` and guarded `--clear-draft`;':'Rust codex-send-to supports `--help` but no `--clear-draft`; historical legacy clear modes require their own installed contract and explicit authority;',
        }
        for old,new in replacements.items():s=s.replace(old,new)
        s=re.sub(r'check (?:the record\'s )?target\.session_name (?:after every send|in the (?:(?:delivery|relay) )?record)',verification,s)
        s=s.replace("check the record's target.session_name", 'verify the versioned bound target under [[agent-tmux-operations]] (Rust numeric peer from its originating immutable package/store and exact attempt ID; legacy target.session_name from its Python record)')
        if p.name=='libsz-report-v3-loop.md':
            s=s.replace('exit 5 means the target has a draft and nothing was sent.','legacy exit 5 was a draft refusal. For a current Rust send use the installed dispatcher and explicit routing; Rust exit 6 is foreground pending-no-input with no surviving worker, and 4 is uncertain. Inspect using the originating immutable package/store without automatic resend.')
        if s!=original and p.name!='MEMORY.md' and 'ANGELSTAR_RELAY_STORE' not in s:
            s=s.rstrip()+'\n\n'+environment+'\n'
    s=s.replace(pending+', and Rust', pending+' Rust').replace(pending+';',pending).replace(pending+'.',pending).replace(pending+',',pending)
    if s!=original:stage(p,s,'Reconcile active instruction-memory copy with explicit role routing, originating-package inspection and Rust foreground pending versus legacy Python queue semantics; retain unrelated operator instructions.')

current={e['stagedpath'] for e in entries}
for e in previous:
    if e['stagedpath'] not in current:
        Path(e['stagedpath']).unlink(missing_ok=True)
entries.sort(key=lambda e:e['path'])
manifest=dict(schema='relay-caller-migration',version=1,entries=entries)
(audit/'s6x-doc-migration.json').write_text(json.dumps(manifest,indent=2)+'\n')
paths=(audit/'s6x-caller-discovery.txt').read_text().splitlines()+list(changes)
classification=[]
for s in sorted(set(paths)):
    p=Path(s)
    if s in changes:status='active-staged';reason=changes[s]
    elif any(x in p.parts for x in ('reviews','archive','attic','cache','history','debug','transcripts')):status='inactive-evidence';reason='Historical review/intake/archive/cache evidence; no active caller authority.'
    elif '/notes/deferred/' in s or 'HANDOFF-' in p.name:status='inactive-deferred';reason='Deferred design or historical handoff, not an active installed caller recipe.'
    else:status='active-no-change';reason='No stale active four-surface routing/outcome claim; unrelated exits, historical incidents, existing correct explicit routing or references only.'
    classification.append(dict(path=s,status=status,reason=reason))
(audit/'s6x-caller-classification.json').write_text(json.dumps(dict(schema='relay-caller-classification',version=1,entries=classification),indent=2)+'\n')
print(json.dumps(dict(staged_count=len(entries),by_group={key:sum(key in e['path'] for e in entries) for key in ['.claude/projects','.skills/review-protocol-wt','.skills/review-protocol/','.skills/net','.codex/AGENTS.md']}),indent=2))
