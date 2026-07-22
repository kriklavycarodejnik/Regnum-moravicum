#!/usr/bin/env python3
"""G4 batch: emblems, map markers, battle silhouettes, event plates, extended icons."""
import os, json, time, random, urllib.request, io
from pathlib import Path
from datetime import datetime, timezone
from PIL import Image
import fal_client

ROOT = Path("/Users/home/projects/regnum-moravicum-official")
RAW = ROOT / "tools/art/raw/g4_batch"
RAW.mkdir(parents=True, exist_ok=True)

STYLE_A = (
    "Historical comic illustrated chronicle of early medieval Central Europe, "
    "refined ink linework with soft painted shading, parchment texture, "
    "muted earthy royal palette (anchors: #8B1E2D crimson, #C9A227 gold, "
    "#E8DCC4 parchment, #2A1F14 oak, #2F4A28 forest, #3A6B7A danube, #6B6560 stone), "
    "Great Moravia / early 10th-century, weathered textures, strong silhouettes, "
    "cinematic non-photoreal, no cel-shading, no modern UI"
)
NEG_A = (
    "low-poly, cartoon, anime, neon, dragons elves glowing magic, full plate armor, "
    "late gothic, photorealism, plastic gloss, watermark, text artifacts, blurry"
)
STYLE_B = (
    "strategy game readable silhouette, slight-iso or top-down friendly marker, "
    "Regnum Moravicum palette, early 10th century, clear shape at small size, "
    "no photoreal clutter, no modern UI"
)
STYLE_C = (
    "Single heraldic UI icon, fine manuscript linework, clean silhouette, "
    "even diffused light, no strong drop shadow, reads clearly at 24px, "
    "iron-grey #4A4E52 linework, parchment #E8DCC4 fill, optional oxblood/gold accent, "
    "centered generous padding, flat solid parchment background #E8DCC4"
)
NEG_C = "busy scene, photoreal, gradient mess, heavy drop shadow, text, watermark, 3d render"

JOBS = []

emblems = {
    "franks": "Carolingian imperial eagle or frankish cross emblem seal, royal blue and gold, round seal on parchment",
    "bavaria": "Bavarian early medieval ducal emblem, subtle lozenge hint not modern flag, oak and gold seal",
    "hungary": "Magyar steppe tribal emblem, horse and sun-arch motifs, steppe brown #A67C52 and gold, round seal",
    "poland": "Early Piast-style white eagle prototype emblem, simple heraldic bird, crimson and silver-grey seal",
    "bohemia": "Bohemian early medieval lion-like emblem simplified, crimson and gold round seal",
    "byzantium": "Byzantine patriarchal cross and imperial eagle hybrid emblem, gold and purple-crimson seal",
}
for fid, subj in emblems.items():
    JOBS.append({
        "id": f"emblem_{fid}",
        "layer": "A",
        "out": f"icons/factions/{fid}_emblem_v1.png",
        "size": "square_hd",
        "wh": (1024, 1024),
        "prompt": f"{STYLE_A}. Heraldic faction emblem seal: {subj}. Centered emblem only, circular medallion, no text.",
        "negative": NEG_A + ", map, landscape, person face",
        "icon": False,
    })

markers = {
    "marker_settlement_small": "tiny village of 3 wooden houses icon marker top-down readable",
    "marker_settlement_medium": "small town with palisade and church rotunda icon marker",
    "marker_settlement_large": "major fortified settlement with towers icon marker",
    "marker_fort": "wooden-stone hillfort keep icon marker, strong silhouette",
    "marker_army_dot": "simple army banner pin unit stack marker, round shield and spear silhouette",
}
for mid, subj in markers.items():
    JOBS.append({
        "id": mid,
        "layer": "B",
        "out": f"map/{mid}_v1.png",
        "size": "square_hd",
        "wh": (512, 512),
        "prompt": f"{STYLE_B}. Game map marker icon: {subj}. Isolated centered, flat parchment ground, high contrast silhouette.",
        "negative": NEG_A + ", full battle scene, UI panels",
        "icon": False,
    })

silhouettes = {
    "sil_infantry": "early medieval Slavic infantry with round shield and spear, side profile silhouette",
    "sil_archer": "early medieval archer with bow, side profile silhouette",
    "sil_cavalry": "early medieval heavy cavalry rider, side profile silhouette",
    "sil_shieldwall": "three infantry overlapping round shields forming shieldwall silhouette",
    "sil_magyar_horse": "Magyar light horse archer silhouette, composite bow, steppe rider",
    "sil_commander": "princely commander with banner and helmet crest silhouette",
}
for sid, subj in silhouettes.items():
    JOBS.append({
        "id": sid,
        "layer": "B",
        "out": f"battle/{sid}_v1.png",
        "size": "landscape_4_3",
        "wh": (768, 512),
        "prompt": f"{STYLE_B}. Clean battle unit plate: {subj}. Dark oak silhouette on parchment, no background clutter, game asset.",
        "negative": NEG_A + ", crowd battle, blood gore closeup, text",
        "icon": False,
    })

events = {
    "event_papal_legation": "Papal legates in Rome-leaning robes arrive at Moravian wooden court with sealed letter, torchlight",
    "event_byzantine_marriage": "Byzantine envoys offer marriage alliance at Great Moravia court, gold and silk gifts, early 10th century stylized",
    "event_bogata_conspiracy": "Noble conspiracy at night in longhouse, whispered oath, daggers sheathed, tense chronicle scene",
    "event_council_of_zhupans": "Council of zhupans around oak table in Moravian court, maps and cups, debate",
    "event_border_raid": "Dawn border raid smoke over palisade village, riders leaving, crisis mood not triumphant",
    "event_harvest_tithe": "Autumn harvest and church tithe gathering, grain sacks, priests and peasants, peaceful chronicle",
}
for eid, subj in events.items():
    JOBS.append({
        "id": eid,
        "layer": "A",
        "out": f"events/{eid}_v1.png",
        "size": "landscape_16_9",
        "wh": (1344, 768),
        "prompt": f"{STYLE_A}. Narrative event illustration: {subj}. Wide cinematic frame, one clear focal moment.",
        "negative": NEG_A,
        "icon": False,
    })

icons = {
    "icon_gift": "open gift chest with gold coins, heraldic UI icon",
    "icon_threat": "clenched fist over broken olive branch, heraldic UI icon",
    "icon_treaty": "two hands clasping over sealed scroll, heraldic UI icon",
    "icon_trade": "balance scale with grain and coin, heraldic UI icon",
    "icon_nap": "crossed swords lowered with olive, heraldic UI icon",
    "icon_military_pact": "two shields overlapping, heraldic UI icon",
    "icon_move": "marching boot prints and arrow, heraldic UI icon",
    "icon_split": "one banner dividing into two, heraldic UI icon",
    "icon_merge": "two banners joining into one, heraldic UI icon",
    "icon_upgrade": "hammer and anvil with upward chevron, heraldic UI icon",
    "icon_save": "wax seal on book, heraldic UI icon",
    "icon_load": "open book with bookmark, heraldic UI icon",
    "icon_next_month": "crescent moon and sun cycle arrow, heraldic UI icon",
    "icon_bell": "small bronze handbell, heraldic UI icon",
    "icon_victory": "laurel and crown simple, heraldic UI icon",
    "icon_defeat": "broken spear and fallen helm, heraldic UI icon",
}
for iid, subj in icons.items():
    JOBS.append({
        "id": iid,
        "layer": "C",
        "out": f"icons/ui/{iid}_1024.png",
        "size": "square_hd",
        "wh": (1024, 1024),
        "prompt": f"{STYLE_C}. {subj}.",
        "negative": NEG_C,
        "icon": True,
    })


def download(url: str, path: Path) -> bytes:
    path.parent.mkdir(parents=True, exist_ok=True)
    req = urllib.request.Request(url, headers={"User-Agent": "regnum-art-batch/1.0"})
    with urllib.request.urlopen(req, timeout=180) as r:
        data = r.read()
    path.write_bytes(data)
    return data


def main() -> None:
    print(f"JOBS: {len(JOBS)}", flush=True)
    if not os.environ.get("FAL_KEY"):
        raise SystemExit("FAL_KEY missing")
    meta = {
        "batch": "G4_missing_sets",
        "created": datetime.now(timezone.utc).isoformat(),
        "assets": [],
    }
    ok = 0
    errors = []
    for i, job in enumerate(JOBS):
        seed = random.randint(1, 2**32 - 1)
        print(f"[{i+1}/{len(JOBS)}] {job['id']} seed={seed}", flush=True)
        try:
            args = {
                "prompt": job["prompt"],
                "image_size": job["size"],
                "num_images": 1,
                "enable_safety_checker": False,
                "seed": seed,
                "output_format": "png",
                "safety_tolerance": "5",
            }
            result = fal_client.subscribe("fal-ai/flux-pro/v1.1", arguments=args)
            url = None
            if isinstance(result, dict):
                imgs = result.get("images") or result.get("image")
                if isinstance(imgs, list) and imgs:
                    url = imgs[0].get("url") if isinstance(imgs[0], dict) else imgs[0]
                elif isinstance(imgs, dict):
                    url = imgs.get("url")
            if not url:
                raise RuntimeError(f"no url: {str(result)[:200]}")
            raw_path = RAW / f"{job['id']}_raw.png"
            data = download(url, raw_path)
            out_path = ROOT / "godot" / "assets" / job["out"]
            out_path.parent.mkdir(parents=True, exist_ok=True)
            im = Image.open(io.BytesIO(data)).convert("RGB")
            tw, th = job["wh"]
            if job.get("icon"):
                im1024 = im.resize((1024, 1024), Image.Resampling.LANCZOS)
                im1024.save(out_path, "PNG")
                base = out_path.name.replace("_1024.png", "")
                ui_dir = out_path.parent
                im1024.resize((256, 256), Image.Resampling.LANCZOS).save(ui_dir / f"{base}_256.png", "PNG")
                im1024.resize((64, 64), Image.Resampling.LANCZOS).save(ui_dir / f"{base}_64.png", "PNG")
            else:
                if abs(im.size[0] - tw) > 64 or abs(im.size[1] - th) > 64:
                    im = im.resize((tw, th), Image.Resampling.LANCZOS)
                im.save(out_path, "PNG")
            meta["assets"].append({
                "id": job["id"],
                "path": str(out_path.relative_to(ROOT)),
                "seed": seed,
                "url": url,
                "layer": job["layer"],
                "ok": True,
            })
            ok += 1
            print(f"  OK -> {out_path.relative_to(ROOT)} ({out_path.stat().st_size} b)", flush=True)
        except Exception as e:
            errors.append({"id": job["id"], "error": str(e)})
            meta["assets"].append({"id": job["id"], "ok": False, "error": str(e), "seed": seed})
            print(f"  FAIL {e}", flush=True)
        time.sleep(0.35)
    meta["ok_count"] = ok
    meta["errors"] = errors
    (RAW / "batch_g4_meta.json").write_text(json.dumps(meta, indent=2, ensure_ascii=False))
    print("DONE", ok, "/", len(JOBS), "errors", len(errors), flush=True)
    if errors:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
