import os
from pathlib import Path
from PIL import Image

def process_all_in_categories(
    base_dir: str,
    fps: int = 12,
    target_width: int = 854,
    target_height: int = 480,
    quality: int = 80
):
    """
    D:/xampp/htdocs/Player/MyAnimation 以下の Category 01~07 配下にある画像をすべて自動探索し、
    8桁ルール（デフォルト12fps）のWebPへ一括変換する。
    """
    fps_map = {
        8:  {"id": "7", "max_frames": 480},
        12: {"id": "B", "max_frames": 720},
        16: {"id": "F", "max_frames": 960},
        24: {"id": "0", "max_frames": 1440}
    }
    
    if fps not in fps_map:
        raise ValueError(f"未対応のfpsです: {fps}")

    fps_id = fps_map[fps]["id"]
    max_frames_per_min = fps_map[fps]["max_frames"]
    
    root_path = Path(base_dir)
    valid_exts = {'.png', '.jpg', '.jpeg', '.webp', '.bmp'}

    # Category 01 ~ 07 フォルダを対象にする
    for cat_num in range(1, 8):
        cat_dir = root_path / f"Category {cat_num:02d}"
        cat_dir.mkdir(parents=True, exist_ok=True)

        # Category配下を再帰的に全探索
        for current_dir, _, files in os.walk(cat_dir):
            current_path = Path(current_dir)
            
            # 出力用フォルダ（output_chunks）自体は処理対象から除外
            if "output_chunks" in current_path.parts:
                continue

            # 画像ファイルを抽出・順序維持のためソート
            img_files = sorted([
                current_path / f for f in files 
                if Path(f).suffix.lower() in valid_exts
            ])

            if not img_files:
                continue

            # 画像が見つかった階層に『output_chunks』フォルダを作成して出力
            out_dir = current_path / "output_chunks"
            out_dir.mkdir(exist_ok=True)

            print(f"[{cat_dir.name} -> {current_path.relative_to(cat_dir)}] 変換開始: {len(img_files)}枚")

            for index, file_path in enumerate(img_files):
                current_minute = index // max_frames_per_min
                frame_in_minute = index % max_frames_per_min
                
                if current_minute > 299:
                    print(f"  警報: 300分制限を超えたため {file_path.name} 以降をスキップ")
                    break

                # 8桁数字ルールの適用（12fps: 先頭 'B'）
                new_filename = f"{fps_id}{current_minute:03d}{frame_in_minute:04d}.webp"
                dest_file = out_dir / new_filename

                if dest_file.exists():
                    continue

                try:
                    with Image.open(file_path) as img:
                        img = img.convert("RGB")
                        img_resized = img.resize((target_width, target_height), Image.Resampling.LANCZOS)
                        img_resized.save(dest_file, "WEBP", quality=quality)
                except Exception as e:
                    print(f"  エラー: {file_path.name} の変換失敗 - {e}")

    print("\nCategory内のすべての画像変換処理が完了しました。")

# ==========================================
# 実行部
# ==========================================
if __name__ == "__main__":
    # 指定のパス（Dドライブ + Playerフォルダ内）に変更
    MY_ANIMATION_DIR = "D:/xampp/htdocs/Player/MyAnimation"
    
    process_all_in_categories(MY_ANIMATION_DIR, fps=12)
