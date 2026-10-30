import os
import sys
import urllib.request
import time

URL = "https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf"
DEST_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "models")
os.makedirs(DEST_DIR, exist_ok=True)
DEST_PATH = os.path.join(DEST_DIR, "qwen2.5-0.5b-instruct-q4_k_m.gguf")
PART_PATH = DEST_PATH + ".part"

def download_with_resume(url, dest_path, part_path, max_retries=10):
    for attempt in range(1, max_retries + 1):
        try:
            downloaded = os.path.getsize(part_path) if os.path.exists(part_path) else 0
            headers = {"User-Agent": "Mozilla/5.0"}
            if downloaded > 0:
                headers["Range"] = f"bytes={downloaded}-"
                print(f"[Attempt {attempt}] Resuming from {downloaded / (1024 * 1024):.1f} MB...")
            else:
                print(f"[Attempt {attempt}] Starting download...")

            req = urllib.request.Request(url, headers=headers)
            response = urllib.request.urlopen(req, timeout=30)
            
            content_range = response.headers.get("Content-Range")
            if content_range:
                # e.g., bytes 83886080-491410143/491410144
                total_size = int(content_range.split("/")[-1])
            else:
                total_size = int(response.headers.get("Content-Length", 0)) + downloaded

            print(f"Total size: {total_size / (1024 * 1024):.1f} MB")

            block_size = 1024 * 1024 # 1 MB
            start_time = time.time()
            last_log_time = 0

            mode = "ab" if downloaded > 0 else "wb"
            with open(part_path, mode) as f:
                while True:
                    buffer = response.read(block_size)
                    if not buffer:
                        break
                    downloaded += len(buffer)
                    f.write(buffer)
                    now = time.time()
                    if now - last_log_time >= 3:
                        pct = (downloaded / total_size) * 100 if total_size > 0 else 0
                        elapsed = now - start_time
                        speed = (downloaded / (1024 * 1024)) / (elapsed + 0.001)
                        print(f"Downloaded: {downloaded / (1024 * 1024):.1f} / {total_size / (1024 * 1024):.1f} MB ({pct:.1f}%) @ {speed:.2f} MB/s", flush=True)
                        last_log_time = now

            if os.path.getsize(part_path) >= total_size:
                if os.path.exists(dest_path):
                    os.remove(dest_path)
                os.rename(part_path, dest_path)
                print(f"\nDownload complete! Successfully verified and saved to:\n{dest_path}")
                return True
        except Exception as e:
            print(f"\nWarning: Interrupted ({e}). Retrying in 3 seconds... (attempt {attempt}/{max_retries})")
            time.sleep(3)

    return False

if __name__ == "__main__":
    success = download_with_resume(URL, DEST_PATH, PART_PATH)
    if not success:
        sys.exit(1)
