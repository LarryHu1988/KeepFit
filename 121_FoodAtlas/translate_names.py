"""Build a resumable, offline bilingual display-name cache. No nutrient edits."""
import argparse
import json
from pathlib import Path
import sqlite3
import time
import urllib.request

ROOT = Path(__file__).resolve().parent
MODELS = {
    'en-zh': ('gaudi/opus-mt-en-zh-ctranslate2', 'dcd22168f08b99dd34c62bc2195e31dc2f04e90b'),
    'zh-en': ('gaudi/opus-mt-zh-en-ctranslate2', '05d8fc158397bae0c65b8d46c858b6c18e094c12'),
}


def download_model(direction):
    repo, revision = MODELS[direction]
    folder = ROOT / '.data/models' / direction
    folder.mkdir(parents=True, exist_ok=True)
    for name in ('config.json', 'model.bin', 'shared_vocabulary.json', 'source.spm', 'target.spm'):
        path = folder / name
        if path.exists():
            continue
        url = 'https://huggingface.co/%s/resolve/%s/%s' % (repo, revision, name)
        print('Downloading', direction, name, flush=True)
        for attempt in range(4):
            try:
                with urllib.request.urlopen(url, timeout=180) as response, path.with_suffix('.part').open('wb') as output:
                    while True:
                        chunk = response.read(1024 * 1024)
                        if not chunk:
                            break
                        output.write(chunk)
                path.with_suffix('.part').replace(path)
                break
            except OSError:
                if attempt == 3:
                    raise
                time.sleep(2 ** attempt)
    return folder


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--limit', type=int, default=0)
    args = parser.parse_args()
    import ctranslate2
    import sentencepiece
    db = sqlite3.connect(ROOT / '.data/foods.sqlite')
    names = db.execute('SELECT name, name_zh, name_en FROM foods').fetchall()
    output = ROOT / '.data/display-translations.json'
    cache = json.loads(output.read_text()) if output.exists() else {}
    for direction in MODELS:
        texts = sorted({r[0] for r in names if not r[1 if direction == 'en-zh' else 2]})
        texts = [t for t in texts if cache.get(direction + ':' + t, {}).get('decoder_version') != 2]
        if args.limit:
            texts = texts[:args.limit]
        if not texts:
            continue
        folder = download_model(direction)
        source = sentencepiece.SentencePieceProcessor(model_file=str(folder / 'source.spm'))
        target = sentencepiece.SentencePieceProcessor(model_file=str(folder / 'target.spm'))
        translator = ctranslate2.Translator(str(folder), device='cpu', compute_type='int8', intra_threads=4)
        start = time.monotonic()
        for offset in range(0, len(texts), 32):
            batch = texts[offset:offset + 32]
            # Marian tokenization requires an explicit source end-of-sentence token.
            tokens = [source.encode(t, out_type=str) + ['</s>'] for t in batch]
            if direction == 'en-zh':
                tokens = [['>>cmn_Hans<<'] + t for t in tokens]
            results = translator.translate_batch(tokens, beam_size=3, max_decoding_length=100,
                                                 repetition_penalty=1.1)
            for text, result in zip(batch, results):
                translated = target.decode(result.hypotheses[0]).strip()
                if translated:
                    cache[direction + ':' + text] = dict(text=translated, method='OPUS-MT / machine translation',
                        model=MODELS[direction][0], revision=MODELS[direction][1], decoder_version=2)
            if offset % 320 == 0 or offset + 32 >= len(texts):
                temporary = output.with_suffix('.tmp')
                temporary.write_text(json.dumps(cache, ensure_ascii=False), encoding='utf-8')
                temporary.replace(output)
                print('%s %d/%d (%.1fs)' % (direction, min(offset + 32, len(texts)), len(texts),
                                            time.monotonic() - start), flush=True)
        del translator
    db.close()


if __name__ == '__main__':
    main()
