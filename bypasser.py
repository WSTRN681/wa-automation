from curl_cffi import requests
from bs4 import BeautifulSoup
import re

def bypass_link(target_url):
    session = requests.Session(impersonate="chrome120")
    
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.5",
    }

    try:
        response = session.get(target_url, headers=headers, allow_redirects=True, timeout=15)
        
        if response.url != target_url:
            return response.url

        soup = BeautifulSoup(response.text, "html.parser")
        
        for link in soup.find_all("a", href=True):
            href = link["href"]
            if href.startswith("http") and target_url not in href:
                return href

        urls_in_script = re.findall(r'https?://[^\s\'"]+', response.text)
        for url in urls_in_script:
            if "destination" in url or "target" in url or "out" in url:
                return url

        return "Link tidak ditemukan di dalam struktur halaman."

    except Exception as e:
        return f"Gagal memproses: {e}"

if __name__ == "__main__":
    link_tes = input("Masukkan link iklan: ")
    hasil = bypass_link(link_tes)
    print(f"\nHasil Bypass:\n{hasil}")
