# -*- coding: utf-8 -*-
"""App同款检测算法离线重放（健哥磨牙+打鼾测试录音）——逐帧复现RMS/低频占比/门槛判断"""
import av
import numpy as np

PATH = r"E:\AI-Projects\个人成长\10-项目\孵化区\随身助手\语音\feishu_file_20261105-022333_桃源路48号 44.m4a"

container = av.open(PATH)
resampler = av.AudioResampler(format='fltp', layout='mono', rate=48000)
chunks = []
for frame in container.decode(audio=0):
    for rf in resampler.resample(frame):
        chunks.append(rf.to_ndarray())
container.close()
audio = np.concatenate(chunks, axis=1)[0].astype(np.float32)
sr = 48000
print(f"总长 {len(audio)/sr:.1f}s  采样率{sr}")

# App同款：4096帧一块，RMS + 1024点DFT低频占比（前6bin≈281Hz）
FRAME = 4096
N = 1024
rows = []
for off in range(0, len(audio) - FRAME, FRAME):
    block = audio[off:off + FRAME]
    rms = float(np.sqrt(np.mean(block ** 2)))
    if rms <= 0.0002:
        rows.append((off / sr, rms, 0.5))
        continue
    seg = block[:N]
    spec = np.fft.rfft(seg * np.hanning(N))
    mag = np.abs(spec) ** 2
    total = mag[1:].sum()
    low = mag[1:7].sum()
    low_ratio = float(low / total) if total > 0 else 0.5
    rows.append((off / sr, rms, low_ratio))

# 汇总：全帧RMS分布 + 各档位下会触发的帧
rms_arr = np.array([r[1] for r in rows])
print(f"\n帧数 {len(rows)}  每帧≈{FRAME/sr*1000:.0f}ms")
print(f"RMS分布: 底噪10%分位={np.percentile(rms_arr,10):.4f}  50%={np.percentile(rms_arr,50):.4f}  90%={np.percentile(rms_arr,90):.4f}  最大={rms_arr.max():.4f}")

for name, floor in [("高档0.020", 0.020), ("中档0.030", 0.030), ("低档封顶0.022", 0.022)]:
    hits = [(t, r, lr) for t, r, lr in rows if r > floor]
    print(f"\n== {name} 门槛：过线帧 {len(hits)}/{len(rows)} ==")
    if hits:
        # 模拟事件闭合（静1.6s关）：输出事件段
        evs = []
        st = None; last = None
        for t, r, lr in hits:
            if st is None: st = t
            if last is not None and t - last > 1.6 + FRAME/sr:
                evs.append((st, last)); st = t
            last = t
        if st is not None: evs.append((st, last))
        for st, en in evs:
            dur = en - st + FRAME/sr
            fr = [x for x in rows if st <= x[0] <= en]
            avg_low = float(np.mean([x[2] for x in fr]))
            kind = "打鼾" if (avg_low > 0.62 and 0.6 <= dur <= 20) else "磨牙"
            print(f"  事件 @{st:6.1f}s  时长{dur:4.1f}s  低频占比{avg_low:.2f} → {kind}")

# 明细：RMS>0.015的帧逐条（看模拟声的真实电平）
print("\n== RMS>0.015 的帧明细（前40条）==")
for t, r, lr in [x for x in rows if x[1] > 0.015][:40]:
    print(f"  {t:6.1f}s  RMS={r:.4f}  低频={lr:.2f}")
