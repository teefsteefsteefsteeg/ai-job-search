#!/usr/bin/env python3
"""Generate a still image through OpenRouter (image-output models) on a chroma key,
ready for `sprite-gen cutout --key magenta`.

Usage:
  OPENROUTER_API_KEY=... python openrouter_gen.py --prompt-file p.txt --out out.png \
      [--model google/gemini-3-pro-image-preview] [--ref ref.png]
"""
import argparse, base64, json, os, sys, urllib.request

API = "https://openrouter.ai/api/v1/chat/completions"


def data_url(path):
    with open(path, "rb") as f:
        raw = f.read()
    mime = "image/jpeg" if raw[:2] == b"\xff\xd8" else "image/png"
    return "data:%s;base64,%s" % (mime, base64.b64encode(raw).decode())


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--prompt-file", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--model", default="google/gemini-3-pro-image-preview")
    ap.add_argument("--ref", action="append", default=[])
    ap.add_argument("--aspect", help="e.g. 2:3, 1:1, 16:9 (Gemini image models)")
    a = ap.parse_args()

    prompt = open(a.prompt_file, encoding="utf-8").read()
    content = [{"type": "text", "text": prompt}]
    content += [{"type": "image_url", "image_url": {"url": data_url(r)}} for r in a.ref]
    body = {"model": a.model, "modalities": ["image", "text"],
            "messages": [{"role": "user", "content": content}]}
    if a.aspect:
        body["image_config"] = {"aspect_ratio": a.aspect}
    req = urllib.request.Request(API, data=json.dumps(body).encode(), headers={
        "Authorization": "Bearer " + os.environ["OPENROUTER_API_KEY"],
        "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=300) as r:
        resp = json.load(r)
    msg = resp["choices"][0]["message"]
    images = msg.get("images") or []
    if not images:
        sys.exit("no image returned: " + json.dumps(resp)[:800])
    url = images[0]["image_url"]["url"]
    raw = base64.b64decode(url.split(",", 1)[1])
    try:  # models may return JPEG; normalise to a real PNG for the cutout step
        import io
        from PIL import Image
        Image.open(io.BytesIO(raw)).convert("RGB").save(a.out, "PNG")
    except ImportError:
        open(a.out, "wb").write(raw)
    print(a.out, "| cost:", resp.get("usage", {}).get("cost"))


if __name__ == "__main__":
    main()
