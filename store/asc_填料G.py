# -*- coding: utf-8 -*-
"""GrindSnore ASC 上架填料（照 HyperLog 模板；跑前置条件：英文版 build 已传 ASC）"""
import time, json, base64, sys, hashlib, urllib.request
import os

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

KEY_ID = "L3UHT69Y77"
ISSUER_ID = "98812827-46d0-4c8f-9b91-35d4f783e6df"
P8_PATH = r"E:\AI-Projects\个人成长\50-Skills\密钥\苹果\AuthKey_L3UHT69Y77.p8"
APP_ID = "6829993769"   # GrindSnore
VER = "0.1.0"
STORE = r"E:\AI-Projects\个人成长\10-项目\SaaS项目\grindsnore-ios\store"
PRIVACY_URL = "https://postwriter.cn/seo/grindsnore-privacy.html"

def b64url(data):
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()

from cryptography.hazmat.primitives.serialization import load_pem_private_key
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives import hashes

key = load_pem_private_key(open(P8_PATH, "rb").read(), password=None)
h = b64url(json.dumps({"alg": "ES256", "kid": KEY_ID, "typ": "JWT"}).encode())
p = b64url(json.dumps({"iss": ISSUER_ID, "iat": int(time.time()), "exp": int(time.time()) + 1200, "aud": "appstoreconnect-v1"}).encode())
sig = key.sign(f"{h}.{p}".encode(), ec.ECDSA(hashes.SHA256()))
def raw(s):
    i = 2
    if s[1] & 0x80: i += s[1] & 0x7f
    def ri():
        nonlocal i
        i += 1; ln = s[i]; i += 1
        if ln & 0x80:
            n = ln & 0x7f; ln = 0
            for _ in range(n): ln = (ln << 8) | s[i]; i += 1
        v = int.from_bytes(s[i:i+ln], "big"); i += ln; return v.to_bytes(32, "big")
    return ri() + ri()
jwt = f"{h}.{p}.{b64url(raw(sig))}"

def asc(url, data=None, method=None, headers=None):
    body = json.dumps(data).encode() if data else None
    all_headers = {"Authorization": f"Bearer {jwt}", "Content-Type": "application/json"}
    if headers: all_headers.update(headers)
    req = urllib.request.Request(url, data=body, headers=all_headers, method=method or ("POST" if data else "GET"))
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                return resp.status, json.loads(resp.read() or b"{}")
        except urllib.error.HTTPError as e:
            return e.code, json.loads(e.read() or b"{}")
        except Exception as ex:
            if attempt == 3: return -1, {"err": str(ex)}
            time.sleep(3)

EN_DESC = """Do you grind your teeth or snore at night? Find out.

GrindSnore listens while you sleep — entirely on your phone — and shows you a simple morning report: how many grind and snore events, when they happened, and how intense they were.

• Overnight recording with on-device detection: snore vs. grind, counted as it happens
• Morning report: counts, time bands, intensity — plus how your jaw feels
• Triggers: log coffee, alcohol or stress and see what your patterns look like
• Listen back: every detected event saves a short clip (on your phone only) so you can hear it yourself
• Corrections: if a sound was mislabeled, fix it or delete it — your corrections make the app smarter
• Trends over 7 nights; share a text report with your doctor or dentist
• Sensitivity levels for quiet or noisy rooms

PRIVATE BY DESIGN
No account. No cloud. No ads. No analytics. Audio is analyzed on your phone and clips never leave your device.

NOT A MEDICAL DEVICE
GrindSnore records sounds and shows patterns. It does not diagnose, treat, or prevent any condition. For concerns about snoring or teeth grinding (bruxism), consult your doctor or dentist."""

LOCALES = {
    "en-US": {"subtitle": "Snore & grind night recorder",
              "keywords": "bruxism,snore,teeth grinding,sleep recorder,grind tracker,snoring app,night recorder,jaw",
              "description": EN_DESC},
    "ja": {"subtitle": "いびき・歯ぎしり記録アプリ",
           "keywords": "歯ぎしり,いびき,睡眠,歯軋り,ナイトレコーダー,顎",
           "description": "夜、歯ぎしりやいびきをかいていませんか？GrindSnore が眠っている間に聞き取り（すべて端末内で処理）、朝のシンプルなレポートでお知らせします：歯ぎしりといびきの回数、起こった時間帯、強さ。朝の気分や顎の状態、コーヒー・お酒・ストレスなどの诱因も記録して自分のパターンを発見。検出されたイベントは短いクリップとして端末にのみ保存されるので、自分の耳で確認し、誤検出は修正・削除できます。7日間のトレンド、医師や歯科医へのレポート共有も。アカウント不要・クラウドなし・音声は端末から出ません。医療機器ではありません。"},
    "de-DE": {"subtitle": "Schnarchen & Zähneknirschen",
           "keywords": "Zähneknirschen,Schnarchen,Schlaf Recorder,Kiefer,nacht aufnahme",
           "description": "Knirschst oder schnarchst du nachts? Finde es heraus. GrindSnore hört mit, während du schläfst — komplett auf deinem Telefon — und zeigt dir am Morgen einen einfachen Bericht: wie viele Knirsch- und Schnarch-Ereignisse, wann sie auftraten und wie stark sie waren. Auslöser wie Kaffee, Alkohol oder Stress protokollieren und Muster erkennen. Jedes erkannte Ereignis wird als kurzer Clip (nur auf deinem Gerät) gespeichert — höre es selbst an und korrigiere Fehlalarme. 7-Nächte-Trend, Bericht für Zahnarzt oder Arzt teilbar. Kein Konto, keine Cloud, keine Werbung. Kein Medizinprodukt."},
    "fr-FR": {"subtitle": "Ronflements et bruxisme",
           "keywords": "bruxisme,ronflement,sommeil,enregistrement nuit,mâchoire",
           "description": "Grincez-vous des dents ou ronflez-vous la nuit ? Découvrez-le. GrindSnore écoute pendant votre sommeil — entièrement sur votre téléphone — et vous montre un rapport matinal simple : nombre d'épisodes de grincement et de ronflement, moments de la nuit, intensité. Notez café, alcool ou stress et découvrez vos déclencheurs. Chaque événement détecté est sauvegardé en clip court (sur votre téléphone uniquement) — écoutez-le vous-même et corrigez les erreurs. Tendance sur 7 nuits, rapport partageable avec votre médecin ou dentiste. Sans compte, sans cloud, sans pub. Pas un dispositif médical."},
    "es-ES": {"subtitle": "Ronquidos y bruxismo",
           "keywords": "bruxismo,ronquido,dormir,registrador noche,mandíbula",
           "description": "¿Rechinas los dientes o roncas por la noche? Descúbrelo. GrindSnore escucha mientras duermes — todo en tu teléfono — y te muestra un informe matinal simple: cuántos episodios de rechinamiento y ronquido, cuándo ocurrieron y su intensidad. Registra café, alcohol o estrés y descubre tus desencadenantes. Cada evento detectado guarda un clip corto (solo en tu teléfono) — escúchalo tú mismo y corrige los errores. Tendencia de 7 noches, informe para tu médico o dentista. Sin cuenta, sin nube, sin anuncios. No es un dispositivo médico."},
}

# 1. 版本（新 App 自带 PREPARE 版本，改 versionString）
st, r = asc(f"https://api.appstoreconnect.apple.com/v1/apps/{APP_ID}/appStoreVersions?filter[platform]=IOS&limit=5")
vers = r.get("data", [])
if not vers:
    print("[1] 无版本（异常）"); sys.exit(1)
ver_id = vers[0]["id"]
if vers[0]["attributes"].get("versionString") != VER:
    st, r = asc(f"https://api.appstoreconnect.apple.com/v1/appStoreVersions/{ver_id}",
                {"data": {"type": "appStoreVersions", "id": ver_id, "attributes": {"versionString": VER}}}, method="PATCH")
print(f"[1] 版本 {VER} id={ver_id}")

# 2. App 信息层（语言注册+副标题+隐私URL）
st, r = asc(f"https://api.appstoreconnect.apple.com/v1/apps/{APP_ID}?include=appInfos")
app_info_id = None
for inc in r.get("included", []):
    if inc["type"] == "appInfos":
        app_info_id = inc["id"]; break
st, r = asc(f"https://api.appstoreconnect.apple.com/v1/appInfos/{app_info_id}/appInfoLocalizations")
info_existing = {l["attributes"]["locale"]: l["id"] for l in r.get("data", [])}
for locale, info in LOCALES.items():
    attrs = {"name": "GrindSnore", "subtitle": info["subtitle"], "privacyPolicyUrl": PRIVACY_URL}
    if locale in info_existing:
        st, rr = asc(f"https://api.appstoreconnect.apple.com/v1/appInfoLocalizations/{info_existing[locale]}",
                     {"data": {"type": "appInfoLocalizations", "id": info_existing[locale], "attributes": attrs}}, method="PATCH")
    else:
        st, rr = asc("https://api.appstoreconnect.apple.com/v1/appInfoLocalizations", {"data": {
            "type": "appInfoLocalizations", "attributes": {"locale": locale, **attrs},
            "relationships": {"appInfo": {"data": {"type": "appInfos", "id": app_info_id}}}}})
    print(f"[2] App信息 {locale}: {'OK' if st in (200, 201) else f'{st} ' + json.dumps(rr)[:200]}")

# 3. 版本文案（description/keywords/supportUrl）
st, r = asc(f"https://api.appstoreconnect.apple.com/v1/appStoreVersions/{ver_id}/appStoreVersionLocalizations")
existing = {l["attributes"]["locale"]: l["id"] for l in r.get("data", [])}
en_loc = None
for locale, info in LOCALES.items():
    payload = {"type": "appStoreVersionLocalizations", "attributes": {
        "locale": locale, "keywords": info["keywords"], "description": info["description"],
        "supportUrl": "https://postwriter.cn"}}
    if locale in existing:
        patch_attrs = {k: v for k, v in payload["attributes"].items() if k != "locale"}
        if locale == "en-US": en_loc = existing[locale]
        st, rr = asc(f"https://api.appstoreconnect.apple.com/v1/appStoreVersionLocalizations/{existing[locale]}",
                     {"data": {"type": "appStoreVersionLocalizations", "id": existing[locale], "attributes": patch_attrs}}, method="PATCH")
    else:
        payload["relationships"] = {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": ver_id}}}
        st, rr = asc("https://api.appstoreconnect.apple.com/v1/appStoreVersionLocalizations", {"data": payload})
        if locale == "en-US" and st in (200, 201): en_loc = rr["data"]["id"]
    print(f"[3] 版本文案 {locale}: {'OK' if st in (200, 201) else f'{st} ' + json.dumps(rr)[:200]}")

# 4. 截图上传
if not en_loc:
    st, r = asc(f"https://api.appstoreconnect.apple.com/v1/appStoreVersions/{ver_id}/appStoreVersionLocalizations")
    for l in r.get("data", []):
        if l["attributes"]["locale"] == "en-US": en_loc = l["id"]
st, r = asc(f"https://api.appstoreconnect.apple.com/v1/appStoreVersionLocalizations/{en_loc}/appScreenshotSets")
set_id = None
for s in r.get("data", []):
    if s["attributes"].get("screenshotDisplayType") == "APP_IPHONE_67":
        set_id = s["id"]; break
if not set_id:
    st, r = asc("https://api.appstoreconnect.apple.com/v1/appScreenshotSets", {"data": {
        "type": "appScreenshotSets", "attributes": {"screenshotDisplayType": "APP_IPHONE_67"},
        "relationships": {"appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": en_loc}}}}})
    if st in (200, 201): set_id = r["data"][0]["id"]
print(f"[4] 截图集 {set_id}")
for i in range(1, 4):
    path = os.path.join(STORE, f"shot{i}.png")
    data = open(path, "rb").read()
    md5 = base64.b64encode(hashlib.md5(data).digest()).decode()
    st, r = asc("https://api.appstoreconnect.apple.com/v1/appScreenshots", {
        "data": {"type": "appScreenshots", "attributes": {"fileName": f"shot{i}.png", "fileSize": len(data)},
                 "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": set_id}}}}})
    if st not in (200, 201):
        print(f"  shot{i} reserve FAIL {st}"); continue
    upload = r["data"]["attributes"]["uploadOperations"][0]
    headers = {hh["name"]: hh["value"] for hh in upload.get("requestHeaders", [])}
    req = urllib.request.Request(upload["url"], data=data, headers=headers, method=upload["method"])
    try:
        with urllib.request.urlopen(req, timeout=180) as resp:
            up_ok = resp.status in (200, 201)
    except Exception:
        up_ok = False
    if up_ok:
        st2, r2 = asc(f"https://api.appstoreconnect.apple.com/v1/appScreenshots/{r['data']['id']}",
                      {"data": {"type": "appScreenshots", "id": r["data"]["id"],
                                "attributes": {"uploaded": True, "sourceFileChecksum": md5}}}, method="PATCH")
        print(f"  shot{i}: {'OK' if st2 in (200, 201) else 'confirm FAIL'}")
    time.sleep(2)

print("[5] 完成——网页剩：年龄分级(全否)/版权2026 He Weijian/分类 Health & Fitness/受监管医疗设备=否/隐私=不收集/价格免费/选build/审核联系人")
