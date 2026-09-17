#!/bin/bash

# Fungsi untuk membersihkan layar
clear

while true; do
    echo "=========================================="
    echo "       TOOL WA AUTOMATION (TERMUX)       "
    echo "=========================================="
    echo "1. Kirim Pesan Teks Biasa"
    echo "2. Kirim Gambar / Foto"
    echo "3. Kirim ke Banyak Nomor (Pisah Spasi)"
    echo "4. Kirim Pesan Berulang (Multi-Send / Loop)"
    echo "5. Kirim Pesan Terjadwal (Jam Realtime)"
    echo "6. Cek Status Login WA"
    echo "0. Keluar"
    echo "=========================================="
    read -p "Pilih menu [0-6]: " menu

    case $menu in
        1)
            echo "--- KIRIM PESAN TEKS ---"
            read -p "Masukkan no telepon: " no
            read -p "Masukkan isi pesan: " pesan
            
            # Format 08 -> 628
            [[ $no == 08* ]] && no="62${no#08}"
            
            echo "Mengirim pesan ke $no..."
            npx mudslide send "$no" "$pesan"
            ;;
        2)
            echo "--- KIRIM GAMBAR / FOTO ---"
            read -p "Masukkan no telepon: " no
            read -p "Lokasi foto (contoh: /sdcard/Download/foto.jpg): " foto
            read -p "Masukkan caption foto: " caption
            
            [[ $no == 08* ]] && no="62${no#08}"
            
            echo "Mengirim gambar ke $no..."
            if [ -z "$caption" ]; then
                npx mudslide send-image "$no" "$foto"
            else
                npx mudslide send-image "$no" "$foto" --caption "$caption"
            fi
            ;;
        3)
            echo "--- KIRIM KE BANYAK NOMOR ---"
            read -p "Masukkan daftar nomor (pisahkan dengan spasi): " daftar_no
            read -p "Masukkan isi pesan: " pesan
            read -p "Jeda antar nomor (detik): " jeda
            
            for no in $daftar_no; do
                [[ $no == 08* ]] && no="62${no#08}"
                echo "Mengirim ke $no..."
                npx mudslide send "$no" "$pesan"
                sleep ${jeda:-2}
            done
            ;;
        4)
            echo "--- KIRIM PESAN BERULANG (LOOP) ---"
            read -p "Masukkan no telepon: " no
            read -p "Masukkan isi pesan: " pesan
            read -p "Berapa kali dikirim: " jumlah
            read -p "Jeda antar pesan (detik): " jeda
            
            [[ $no == 08* ]] && no="62${no#08}"
            
            for ((i=1; i<=jumlah; i++)); do
                echo "[$i/$jumlah] Mengirim ke $no..."
                npx mudslide send "$no" "$pesan"
                sleep ${jeda:-2}
            done
            ;;
        5)
            echo "--- KIRIM PESAN TERJADWAL (JAM REALTIME) ---"
            read -p "Masukkan no telepon: " no
            read -p "Masukkan isi pesan: " pesan
            read -p "Masukkan jam kirim (Format HH:MM, contoh 14:30): " jam_target

            [[ $no == 08* ]] && no="62${no#08}"

            # Hitung selisih waktu
            target_epoch=$(date -d "$jam_target" +%s 2>/dev/null)
            current_epoch=$(date +%s)

            if [ $target_epoch -le $current_epoch ]; then
                target_epoch=$(date -d "tomorrow $jam_target" +%s)
                echo "⏱️ Jam $jam_target hari ini sudah lewat, otomatis di-set untuk BESOK jam $jam_target."
            fi

            sisa_detik=$((target_epoch - current_epoch))

            echo "⏳ Menunggu... Pesan akan dikirim otomatis dalam $sisa_detik detik (Jam $jam_target)."
            echo "⚠️ Jangan tutup Termux!"
            
            sleep $sisa_detik

            echo "🚀 Mengirim pesan ke $no..."
            npx mudslide send "$no" "$pesan"
            ;;
        6)
            echo "--- CEK STATUS LOGIN WA ---"
            npx mudslide me
            ;;
        0)
            echo "Keluar dari program. Sampai jumpa!"
            exit 0
            ;;
        *)
            echo "Pilihan tidak valid!"
            ;;
    esac

    echo ""
    read -p "Tekan Enter untuk kembali ke menu..."
    clear
done

