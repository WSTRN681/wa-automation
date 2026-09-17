#!/bin/bash

# Fungsi otomatis ubah 08xx jadi 628xx
format_nomor() {
    local num="$1"
    if [[ $num == 08* ]]; then
        echo "628${num:2}"
    else
        echo "$num"
    fi
}

clear
echo "========================================"
echo "    TOOL WA AUTOMATION (TERMUX)       "
echo "========================================"
echo "1. Kirim Pesan Teks Biasa"
echo "2. Kirim Gambar / Foto"
echo "3. Kirim ke Banyak Nomor (Pisah Spasi)"
echo "4. Kirim Pesan Berulang (Multi-Send / Loop)"
echo "5. Kirim Pesan Terjadwal (Timer)"
echo "6. Cek Status Login WA"
echo "0. Keluar"
echo "========================================"
read -p "Pilih menu [0-6]: " PILIHAN

case $PILIHAN in
  1)
    read -p "Masukkan no telepon: " INPUT_NOMOR
    NOMOR=$(format_nomor "$INPUT_NOMOR")
    read -p "Masukkan pesan: " PESAN
    echo -e "\nMengirim ke $NOMOR..."
    npx mudslide send "$NOMOR" "$PESAN"
    ;;
  2)
    read -p "Masukkan no telepon: " INPUT_NOMOR
    NOMOR=$(format_nomor "$INPUT_NOMOR")
    read -p "Lokasi foto (contoh: /sdcard/Download/foto.jpg): " FOTO
    read -p "Masukkan caption foto: " CAPTION
    echo -e "\nMengirim gambar ke $NOMOR..."
    npx mudslide send-image "$NOMOR" "$FOTO" --caption "$CAPTION"
    ;;
  3)
    read -p "Masukkan nomor-nomor (pisah spasi): " DAFTAR_NOMOR
    read -p "Masukkan pesan: " PESAN
    echo -e "\nMemulai pengiriman..."
    for NUM in $DAFTAR_NOMOR; do
      NOMOR=$(format_nomor "$NUM")
      echo "Mengirim ke $NOMOR..."
      npx mudslide send "$NOMOR" "$PESAN"
      sleep 3 # Jeda 3 detik antar nomor
    done
    echo "Pengiriman selesai!"
    ;;
  4)
    read -p "Masukkan no telepon: " INPUT_NOMOR
    NOMOR=$(format_nomor "$INPUT_NOMOR")
    read -p "Masukkan pesan: " PESAN
    read -p "Berapa kali mau dikirim?: " JUMLAH
    read -p "Jeda antar pesan (detik, rekomendasi minimal 3): " JEDA
    JEDA=${JEDA:-3}
    echo -e "\nMemulai pesan berulang ke $NOMOR ($JUMLAH kali, jeda ${JEDA}s)..."
    for ((i=1; i<=JUMLAH; i++)); do
      echo "[$i/$JUMLAH] Mengirim ke $NOMOR..."
      npx mudslide send "$NOMOR" "$PESAN"
      if [ $i -lt $JUMLAH ]; then
        sleep $JEDA
      fi
    done
    echo "Pengiriman berulang selesai!"
    ;;
  5)
    read -p "Masukkan no telepon: " INPUT_NOMOR
    NOMOR=$(format_nomor "$INPUT_NOMOR")
    read -p "Masukkan pesan: " PESAN
    read -p "Kirim berapa detik dari sekarang? (misal 60): " DELAY
    echo "Menunggu $DELAY detik..."
    sleep $DELAY
    npx mudslide send "$NOMOR" "$PESAN"
    ;;
  6)
    npx mudslide me
    ;;
  0)
    exit 0
    ;;
  *)
    echo "Pilihan tidak valid!"
    ;;
esac
