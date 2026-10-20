#!/usr/bin/env python3
"""Print a workspace's taps / app opens since an ISO time, normalised
for assertions: one line per row, sorted; tap ids replaced by letters (A, B, …)
so "the open joins its tap" reads as the same letter on both lines.

  analytics_rows.py <tenant_id> <since-iso>     (needs redirect-engine/.env)
"""
import json, os, subprocess, sys

tenant, since = sys.argv[1], sys.argv[2]
engine = os.path.join(os.path.dirname(__file__), '..', '..', '..', 'redirect-engine')
sql = f"""
select 'TAP' k, coalesce((select slug from links where id=link_id),'-') slug,
       source||' '||coalesce(sent_to,'-') v, click_id::text tap, clicked_at t
  from link_clicks where tenant_id='{tenant}' and source <> 'match'
   -- a tap reported later by the app is dated by the PHONE's clock (can trail this
   -- machine by a second or two); scenarios are ≥ 7 s apart, so 3 s is safe
   and clicked_at >= timestamptz '{since}' - interval '3 seconds'
union all
select 'OPEN', coalesce((select slug from links where id=coalesce(o.link_id,(select link_id from link_clicks c where c.click_id=o.click_id))),'-'),
       route||' '||coalesce(app_state,'-')||' '||case when is_install then 'new' else 'existing' end||' '||case when matched then 'ok' else 'failed:'||coalesce(reason,'') end,
       click_id::text, opened_at
  -- opened_at, not received_at/installs: both go in contract step 0068. Phone clock, same 3 s grace as taps.
  from app_opens o where tenant_id='{tenant}' and opened_at >= timestamptz '{since}' - interval '3 seconds'
order by 5"""
out = subprocess.run(['node', '--env-file=.env', 'scripts/q.mjs', sql], cwd=engine, capture_output=True, text=True, check=True).stdout
rows = json.loads(out[out.index('['):])
letters = {}
def tag(tap):
    if not tap: return '-'
    letters.setdefault(tap, chr(ord('A') + len(letters)))
    return letters[tap]
lines = [f"{r['k']} {r['slug']} {r['v']} tap={tag(r['tap'])}" for r in rows]
# Taps only show their letter when something else references the same tap.
counts = {}
for r in rows:
    if r['tap']: counts[r['tap']] = counts.get(r['tap'], 0) + 1
lines = [l if not l.startswith('TAP') or counts.get(r['tap'], 0) > 1 else l.rsplit(' tap=', 1)[0] + ' tap=-' for l, r in zip(lines, rows)]
print('\n'.join(sorted(lines)))
