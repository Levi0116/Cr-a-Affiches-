# Génère la voix off avec ElevenLabs (voix « aude roxane »).
# Usage : python3 make-voice.py voice-dji.json public/dji/voice
import json, os, sys, urllib.request
VOICE = '2KEogF5kYsp0cNGgE2v8'
src, out = sys.argv[1], sys.argv[2]
key = os.environ.get('ELEVENLABS_API_KEY', 'proxy-injected')
os.makedirs(out, exist_ok=True)
for name, text in json.load(open(src, encoding='utf-8')).items():
    path = os.path.join(out, name + '.mp3')
    if os.path.exists(path) and '--force' not in sys.argv:
        continue
    body = json.dumps({'text': text, 'model_id': 'eleven_multilingual_v2',
        'voice_settings': {'stability': 0.45, 'similarity_boost': 0.8, 'style': 0.35, 'use_speaker_boost': True}}).encode()
    req = urllib.request.Request(f'https://api.elevenlabs.io/v1/text-to-speech/{VOICE}?output_format=mp3_44100_128',
        data=body, headers={'xi-api-key': key, 'Content-Type': 'application/json', 'Accept': 'audio/mpeg'})
    with urllib.request.urlopen(req, timeout=120) as r, open(path, 'wb') as f:
        f.write(r.read())
    print('ok', name)
