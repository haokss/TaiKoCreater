#!/usr/bin/env python3
"""
librosa BPM 检测脚本
用法: python bpm_detect.py <音频文件路径>
输出: BPM:<value>  (如 BPM:150.5)
"""
import sys


def detect_bpm(filepath: str) -> float:
    import librosa

    # 加载音频，22050Hz 单声道足够 BPM 检测
    y, sr = librosa.load(filepath, sr=22050, mono=True)
    if len(y) < sr:  # 少于 1 秒
        return 0.0

    # 使用 librosa 的节拍跟踪
    tempo, beats = librosa.beat.beat_track(y=y, sr=sr)

    # tempo 可能是 numpy float64 或数组，转为 Python float
    if hasattr(tempo, "__len__"):
        tempo = float(tempo[0])
    else:
        tempo = float(tempo)

    if tempo <= 0:
        return 0.0

    return round(tempo, 1)


def main():
    if len(sys.argv) < 2:
        print("ERROR:用法: python bpm_detect.py <音频文件路径>", file=sys.stderr)
        sys.exit(1)

    filepath = sys.argv[1]
    bpm = detect_bpm(filepath)
    print(f"BPM:{bpm}")


if __name__ == "__main__":
    main()