"""Owner-invoked real MiMo trial: at most three calls, isolated synthetic meals.

Run on the server with its existing provider key file. No listener is opened,
no credentials are printed, and no real user's records are read or modified.
This checks the meal API against MiMo; it does not test Apple sign-in or a phone.
"""
import argparse
import json
import os
from pathlib import Path
import secrets
import sys
import tempfile
import time

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--allow-paid-trial', action='store_true')
    parser.add_argument('--key-file', type=Path, default=Path('/opt/keepfit/secrets/provider-key'))
    args = parser.parse_args()
    if not args.allow_paid_trial:
        parser.error('Real vendor requests require --allow-paid-trial (maximum 3 calls).')

    from fastapi.testclient import TestClient
    from keepfit_model.api import create_app
    from keepfit_model.production import ServerRuntime
    from keepfit_model.store import Store

    os.environ['KEEPFIT_MODE'] = 'production'
    os.environ['KEEPFIT_ALLOWED_HOSTS'] = 'testserver'
    usages, evidence = [], []

    class AuditedRuntime(ServerRuntime):
        def provider(self, owner, rules, examples):
            model = super().provider(owner, rules, examples)
            model.report = lambda usage: usages.append(usage)
            return model

    with tempfile.TemporaryDirectory(prefix='keepfit-mimo-trial-') as temp:
        directory = Path(temp)
        runtime = AuditedRuntime(Store(directory), 'mimo', '', per_user=3,
                                 global_limit=3, key_path=args.key_file)
        token = secrets.token_urlsafe(32)
        app = create_app(directory, {'synthetic-trial': token}, runtime=runtime)
        client = TestClient(app, headers={'Authorization': 'Bearer ' + token})

        def post(path, payload, label):
            started = time.monotonic()
            response = client.post(path, json=payload, headers={'Idempotency-Key': 'mimo-smoke-' + label})
            body = response.json()
            evidence.append({'step': label, 'http': response.status_code,
                             'elapsed_seconds': round(time.monotonic() - started, 2), 'result': body})
            if not response.is_success:
                raise AssertionError('API rejected step: ' + label)
            return body

        def confirm(draft, label):
            assert draft['status'] == 'ready_for_confirmation', 'Meal still needs clarification: ' + label
            payload = {'expected_revision': draft['revision'], 'accept_estimates': True}
            path = '/v1/intakes/' + draft['id'] + '/confirm'
            record = post(path, payload, label)
            replay = post(path, payload, label)
            assert record['id'] == replay['id'], 'Confirmation replay created a duplicate'
            return record

        failure = None
        try:
            breakfast = post('/v1/intakes', {
                'source': 'text', 'reference_time': '2026-10-24T09:00:00+08:00',
                'timezone': 'Asia/Shanghai',
                'text': '今天早饭我吃了两个去壳后合计100克的水煮鸡蛋，还有50克熟米饭。面包没吃，牛奶是同事喝的。'
            }, 'breakfast')
            assert breakfast['model']['provider'] == 'mimo' and not breakfast['model']['simulated']
            included = [i for i in breakfast['items'] if i['included_in_totals']]
            assert len(included) == 2, 'Only eggs and cooked rice should count'
            assert any('蛋' in i['name'] and i['consumed_grams'] == 100 for i in included)
            assert any('饭' in i['name'] and i['consumed_grams'] == 50 for i in included)
            assert all('面包' not in i['name'] and '奶' not in i['name'] for i in included)
            confirm(breakfast, 'confirm-breakfast')

            shared = post('/v1/intakes', {
                'source': 'voice', 'reference_time': '2026-10-24T12:30:00+08:00',
                'timezone': 'Asia/Shanghai',
                'transcript': '午饭我和三位同事吃火锅，桌上有肥牛、土豆和米饭。我没称重，记不清自己吃了多少，不能按四个人平均分。'
            }, 'shared-hotpot')
            assert shared['status'] == 'needs_clarification', 'Shared meal must ask for personal portions'
            questions = shared['understanding']['questions']
            assert questions, 'Expected a personal-portion question'
            answer = '我想起来了，我本人只吃了六片薄肥牛、四片土豆和半碗熟米饭，没有喝汤。请按普通火锅食材大小和普通家用饭碗合理估算，明确标注估算即可，不再追问。'
            updated = post('/v1/intakes/' + shared['id'] + '/answers', {
                'expected_revision': shared['revision'], 'answers': {q['id']: answer for q in questions}
            }, 'answer-hotpot')
            assert updated['source'] == 'voice'
            assert updated['totals_complete'] and updated['requires_estimate_acceptance']
            confirm(updated, 'confirm-hotpot')
        except (AssertionError, KeyError, TypeError) as exc:
            failure = str(exc)
        print(json.dumps({'passed': failure is None, 'failure': failure,
                          'paid_requests_issued': runtime.usage('synthetic-trial'),
                          'vendor_usage': usages, 'evidence': evidence}, ensure_ascii=False, indent=2))
        return 1 if failure else 0


if __name__ == '__main__':
    raise SystemExit(main())
