"""Download the photographic MODNet ONNX export linked by the official project."""
import hashlib
import json
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / 'assets/models/modnet_photographic_portrait_matting.onnx'
URL = 'https://drive.google.com/uc?export=download&id=1cgycTQlYXpTh26gB9FTnthE7AvruV8hd'
SHA256 = '07c308cf0fc7e6e8b2065a12ed7fc07e1de8febb7dc7839d7b7f15dd66584df9'
SIZE = 25888640

def verified(path):
    return path.is_file() and path.stat().st_size == SIZE and hashlib.sha256(path.read_bytes()).hexdigest() == SHA256

def main():
    if not verified(TARGET):
        partial = TARGET.with_suffix('.onnx.part')
        with urllib.request.urlopen(URL, timeout=60) as response, partial.open('wb') as output:
            while chunk := response.read(1024 * 1024):
                output.write(chunk)
        if not verified(partial):
            raise RuntimeError('MODNet checksum mismatch')
        partial.replace(TARGET)
    metadata = {
        'model': 'MODNet photographic portrait matting',
        'upstream': 'https://github.com/ZHKKKe/MODNet',
        'export_source': 'https://github.com/ZHKKKe/MODNet/tree/master/onnx',
        'download': URL, 'sha256': SHA256, 'bytes': SIZE, 'license': 'Apache-2.0',
        'input': 'input: RGB float32 NCHW, (RGB - 127.5) / 127.5, multiples of 32',
        'output': 'output: float32 [1,1,H,W], alpha in [0,1]',
        'resolution': '512 short edge, 1024 maximum long edge, preserve aspect',
    }
    TARGET.with_suffix('.json').write_text(json.dumps(metadata, indent=2)+'\n', encoding='utf-8')
    print('MODNet verified:', SIZE, SHA256)

if __name__ == '__main__':
    main()
