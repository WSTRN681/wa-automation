#!/bin/bash

# Kode Warna ANSI
CYAN='\033[1;36m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
BLUE='\033[1;34m'
PURPLE='\033[1;35m'
WHITE='\033[1;37m'
NC='\033[0m'

JOB_FILE="$HOME/.wa_jobs.txt"
touch "$JOB_FILE"

# Auto-check izin storage HP & Kunci CPU Termux
if [ ! -d "$HOME/storage" ]; then
    echo -e "${YELLOW}[!] Menghubungkan izin penyimpanan HP ke Termux...${NC}"
    termux-setup-storage
    sleep 2
fi

termux-wake-lock 2>/dev/null

format_nomor() {
    local num="$1"
    if [[ $num == 0* ]]; then
        echo "62${num#0}"
    else
        echo "$num"
    fi
}

clean_jobs() {
    if [ -f "$JOB_FILE" ]; then
        local tmp_file="$HOME/.wa_jobs.tmp"
        > "$tmp_file"
        while IFS='|' read -r pid no jam pesan; do
            if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                echo "$pid|$no|$jam|$pesan" >> "$tmp_file"
            fi
        done < "$JOB_FILE"
        mv "$tmp_file" "$JOB_FILE"
    fi
}

batalkan_jadwal() {
    clean_jobs
    if [ ! -s "$JOB_FILE" ]; then
        echo -e "${YELLOW}[!] Tidak ada jadwal pesan aktif saat ini.${NC}"
        return
    fi

    echo ""
    echo -e "${CYAN}==========================================================${NC}"
    echo -e "${WHITE}               DAFTAR JADWAL PESAN AKTIF                  ${NC}"
    echo -e "${CYAN}==========================================================${NC}"
    
    local count=1
    declare -a map_pid
    declare -a map_no
    declare -a map_jam

    while IFS='|' read -r pid no jam pesan; do
        echo -e "  ${GREEN}[$count]${NC} Jam: ${YELLOW}$jam${NC} | Ke: ${CYAN}$no${NC} | Pesan/Media: \"$pesan\""
        map_pid[$count]=$pid
        map_no[$count]=$no
        map_jam[$count]=$jam
        ((count++))
    done < "$JOB_FILE"

    echo -e "${CYAN}==========================================================${NC}"
    read -p " >> Pilih nomor chat yang ingin DIBATALKAN (0 untuk batal): " pilih_batal

    if [[ "$pilih_batal" =~ ^[0-9]+$ ]] && [ "$pilih_batal" -ge 1 ] && [ "$pilih_batal" -lt "$count" ]; then
        target_pid=${map_pid[$pilih_batal]}
        target_no=${map_no[$pilih_batal]}
        target_jam=${map_jam[$pilih_batal]}

        kill "$target_pid" 2>/dev/null
        clean_jobs
        echo -e "${RED}[OK] Jadwal jam $target_jam ke $target_no BERHASIL DIBATALKAN!${NC}"
    else
        echo -e "${YELLOW}[*] Pembatalan dilewati.${NC}"
    fi
}

kirim_media_action() {
    local no="$1"
    local file="$2"
    local caption="$3"

    ext="${file##*.}"
    ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')

    case "$ext" in
        jpg|jpeg|png|webp|gif)
            echo -e "${BLUE}[*] Mengirim FOTO ke $no...${NC}"
            if [ -z "$caption" ]; then
                npx mudslide send-image "$no" "$file"
            else
                npx mudslide send-image --caption "$caption" "$no" "$file"
            fi
            ;;
        mp4|mkv|avi|mov)
            echo -e "${BLUE}[*] Mengirim VIDEO ke $no...${NC}"
            npx mudslide send-file --type video "$no" "$file"
            ;;
        mp3|wav|m4a|ogg|flac|aac)
            echo -e "${BLUE}[*] Mengirim AUDIO / MUSIK ke $no...${NC}"
            npx mudslide send-file --type audio "$no" "$file"
            ;;
        *)
            echo -e "${BLUE}[*] Mengirim FILE / DOKUMEN ke $no...${NC}"
            npx mudslide send-file "$no" "$file"
            ;;
    esac
}

while true; do
    clear # LAYAR OTOMATIS BERSIH SETIAP BALIK KE MENU UTAMA
    echo -e "${CYAN}==========================================================${NC}"
    echo -e "${WHITE}                 TOOL WA AUTOMATION (CLI)                 ${NC}"
    echo -e "${YELLOW}              Termux Edition v2.0 | WSTRN681              ${NC}"
    echo -e "${CYAN}==========================================================${NC}"
    echo ""
    echo -e "  ${GREEN}[1]${NC} Kirim Pesan Teks (Singel / Multi Chat)"
    echo -e "  ${GREEN}[2]${NC} Kirim Media (Foto, Video, MP3, Dokumen)"
    echo -e "  ${GREEN}[3]${NC} Kirim Pesan Broadcast (Banyak Nomor)"
    echo ""
    echo -e "  ${GREEN}[4]${NC} Kirim Pesan Berulang (Looping)"
    echo -e "  ${GREEN}[5]${NC} Kirim Pesan Terjadwal & Kelola Jadwal"
    echo ""
    echo -e "  ${GREEN}[6]${NC} Cek Status Login WhatsApp"
    echo -e "  ${GREEN}[0]${NC} Keluar"
    echo ""
    echo -e "${CYAN}==========================================================${NC}"
    read -p " >> Pilih menu [0-6]: " menu

    case $menu in
        1)
            echo ""
            echo -e "${YELLOW}--- [ KIRIM PESAN TEKS ] ---${NC}"
            echo "1. Kirim 1 Chat"
            echo "2. Kirim Banyak Chat Sekaligus"
            read -p "Pilih opsi [1-2]: " sub1

            if [ "$sub1" == "1" ]; then
                read -p "Masukkan no telepon: " no
                read -p "Masukkan isi pesan: " pesan
                no=$(format_nomor "$no")
                
                echo -e "${BLUE}[*] Mengirim pesan ke $no...${NC}"
                npx mudslide send "$no" "$pesan"
            elif [ "$sub1" == "2" ]; then
                read -p "Berapa banyak chat yang ingin dikirim? " total
                for ((i=1; i<=total; i++)); do
                    echo -e "${CYAN}--- Chat Ke-$i ---${NC}"
                    read -p "Masukkan no telepon: " no
                    read -p "Masukkan isi pesan: " pesan
                    no=$(format_nomor "$no")
                    
                    echo -e "${BLUE}[*] Mengirim chat ke-$i ke $no...${NC}"
                    npx mudslide send "$no" "$pesan"
                    sleep 2
                done
            fi
            ;;
        2)
            echo ""
            echo -e "${YELLOW}--- [ KIRIM MEDIA / FILE ] ---${NC}"
            echo "1. Kirim Media Langsung"
            echo "2. Kirim Media Terjadwal (Jam Realtime)"
            read -p "Pilih opsi [1-2]: " sub2

            if [ "$sub2" == "1" ]; then
                read -p "Masukkan no telepon: " no
                read -p "Lokasi file (contoh: /sdcard/Download/musik.mp3): " file
                read -p "Masukkan caption (hanya untuk gambar/kosongkan): " caption
                no=$(format_nomor "$no")
                
                kirim_media_action "$no" "$file" "$caption"

            elif [ "$sub2" == "2" ]; then
                read -p "Masukkan no telepon: " no
                read -p "Lokasi file (contoh: /sdcard/Download/musik.mp3): " file
                read -p "Masukkan caption (hanya untuk gambar/kosongkan): " caption
                read -p "Masukkan jam kirim (Format HH:MM, contoh 14:30): " jam_target
                no=$(format_nomor "$no")

                target_epoch=$(date -d "$jam_target" +%s 2>/dev/null)
                current_epoch=$(date +%s)

                if [ $target_epoch -le $current_epoch ]; then
                    target_epoch=$(date -d "tomorrow $jam_target" +%s)
                    echo -e "${YELLOW}[!] Jam $jam_target hari ini sudah lewat, otomatis di-set untuk BESOK.${NC}"
                fi

                sisa_detik=$((target_epoch - current_epoch))

                (
                    sleep $sisa_detik
                    kirim_media_action "$no" "$file" "$caption" >/dev/null 2>&1
                ) >/dev/null 2>&1 &
                bg_pid=$!
                disown $bg_pid 2>/dev/null
                echo "$bg_pid|$no|$jam_target|File: $file" >> "$JOB_FILE"

                echo -e "${GREEN}[OK] Jadwal file tersimpan! Terkirim jam $jam_target ke $no.${NC}"
                echo -e "${CYAN}[>] Berjalan mandiri di background!${NC}"
            fi
            ;;
        3)
            echo ""
            echo -e "${YELLOW}--- [ KIRIM BROADCAST ] ---${NC}"
            read -p "Masukkan daftar nomor (pisahkan dengan spasi): " daftar_no
            read -p "Masukkan isi pesan: " pesan
            read -p "Jeda antar nomor (detik): " jeda
            
            for no in $daftar_no; do
                no=$(format_nomor "$no")
                echo -e "${BLUE}[*] Mengirim ke $no...${NC}"
                npx mudslide send "$no" "$pesan"
                sleep ${jeda:-2}
            done
            ;;
        4)
            echo ""
            echo -e "${YELLOW}--- [ KIRIM PESAN BERULANG ] ---${NC}"
            read -p "Masukkan no telepon: " no
            read -p "Masukkan isi pesan: " pesan
            read -p "Berapa kali dikirim: " jumlah
            read -p "Jeda antar pesan (detik): " jeda
            no=$(format_nomor "$no")
            
            for ((i=1; i<=jumlah; i++)); do
                echo -e "${BLUE}[$i/$jumlah] Mengirim ke $no...${NC}"
                npx mudslide send "$no" "$pesan"
                sleep ${jeda:-2}
            done
            ;;
        5)
            echo ""
            echo -e "${YELLOW}--- [ KIRIM PESAN TERJADWAL ] ---${NC}"
            echo "1. Kirim 1 Chat Terjadwal"
            echo "2. Kirim Banyak Chat Terjadwal Sekaligus"
            echo "3. Lihat & Batalkan Jadwal Aktif"
            read -p "Pilih opsi [1-3]: " sub5

            if [ "$sub5" == "1" ]; then
                read -p "Masukkan no telepon: " no
                read -p "Masukkan isi pesan: " pesan
                read -p "Masukkan jam kirim (Format HH:MM, contoh 14:30): " jam_target
                no=$(format_nomor "$no")

                target_epoch=$(date -d "$jam_target" +%s 2>/dev/null)
                current_epoch=$(date +%s)

                if [ $target_epoch -le $current_epoch ]; then
                    target_epoch=$(date -d "tomorrow $jam_target" +%s)
                    echo -e "${YELLOW}[!] Jam $jam_target hari ini sudah lewat, otomatis di-set untuk BESOK.${NC}"
                fi

                sisa_detik=$((target_epoch - current_epoch))

                (
                    sleep $sisa_detik
                    npx mudslide send "$no" "$pesan" >/dev/null 2>&1
                ) >/dev/null 2>&1 &
                bg_pid=$!
                disown $bg_pid 2>/dev/null
                echo "$bg_pid|$no|$jam_target|$pesan" >> "$JOB_FILE"

                echo -e "${GREEN}[OK] Jadwal tersimpan! Pesan untuk $no akan terkirim jam $jam_target.${NC}"
                echo -e "${CYAN}[>] Berjalan mandiri di background!${NC}"

            elif [ "$sub5" == "2" ]; then
                read -p "Berapa banyak jadwal chat yang ingin dibuat? " total_jadwal
                for ((i=1; i<=total_jadwal; i++)); do
                    echo ""
                    echo -e "${CYAN}--- Setup Jadwal Ke-$i ---${NC}"
                    read -p "Masukkan no telepon: " no
                    read -p "Masukkan isi pesan: " pesan
                    read -p "Masukkan jam kirim (Format HH:MM, contoh 14:30): " jam_target
                    no=$(format_nomor "$no")

                    target_epoch=$(date -d "$jam_target" +%s 2>/dev/null)
                    current_epoch=$(date +%s)

                    if [ $target_epoch -le $current_epoch ]; then
                        target_epoch=$(date -d "tomorrow $jam_target" +%s)
                        echo -e "${YELLOW}[!] Jam $jam_target hari ini sudah lewat, otomatis di-set untuk BESOK.${NC}"
                    fi

                    sisa_detik=$((target_epoch - current_epoch))

                    (
                        sleep $sisa_detik
                        npx mudslide send "$no" "$pesan" >/dev/null 2>&1
                    ) >/dev/null 2>&1 &
                    bg_pid=$!
                    disown $bg_pid 2>/dev/null
                    echo "$bg_pid|$no|$jam_target|$pesan" >> "$JOB_FILE"

                    echo -e "${GREEN}[OK] [Jadwal $i] Dikirim jam $jam_target ke $no.${NC}"
                done
            elif [ "$sub5" == "3" ]; then
                batalkan_jadwal
            fi

            if [ "$sub5" == "1" ] || [ "$sub5" == "2" ]; then
                echo ""
                read -p "Tekan [Enter] untuk kembali, atau ketik [b] untuk batalkan jadwal: " opt_post
                if [ "$opt_post" == "b" ] || [ "$opt_post" == "B" ]; then
                    batalkan_jadwal
                    echo ""
                    read -p "Tekan Enter untuk kembali ke menu..."
                fi
                continue
            fi
            ;;
        6)
            echo ""
            echo -e "${YELLOW}--- [ CEK STATUS LOGIN WA ] ---${NC}"
            npx mudslide me
            ;;
        0)
            echo -e "${GREEN}Keluar dari program. Sampai jumpa!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}[!] Pilihan tidak valid!${NC}"
            ;;
    esac

    echo ""
    read -p "Tekan Enter untuk kembali ke menu..."
done
