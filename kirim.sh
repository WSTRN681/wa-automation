#!/bin/bash

# Kode Warna ANSI
CYAN='\033[1;36m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
BLUE='\033[1;34m'
WHITE='\033[1;37m'
NC='\033[0m'

JOB_FILE="$HOME/.wa_jobs.txt"
LOG_FILE="$HOME/.wa_history.log"
CONFIG_FILE="$HOME/.wa_config.txt"

touch "$JOB_FILE" "$LOG_FILE" "$CONFIG_FILE"

if ! grep -q "NOTIF_STATUS=" "$CONFIG_FILE"; then
    echo "NOTIF_STATUS=ON" > "$CONFIG_FILE"
fi
NOTIF_STATUS=$(grep "NOTIF_STATUS=" "$CONFIG_FILE" | cut -d'=' -f2)

termux-wake-lock 2>/dev/null

send_notification() {
    if [ "$NOTIF_STATUS" == "ON" ] && command -v termux-notification >/dev/null 2>&1; then
        termux-notification --title "$1" --content "$2" --priority high
    fi
}

format_nomor() {
    local num="$1"
    if [[ $num == 0* ]]; then
        echo "62${num#0}"
    else
        echo "$num"
    fi
}

log_action() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] | Status: $1 | Ke: $2 | Info: $3" >> "$LOG_FILE"
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
        echo -e "${YELLOW}[!] Tidak ada proses aktif di background.${NC}"
        return
    fi
    echo ""
    echo -e "${CYAN}--- DAFTAR PROSES BACKGROUND AKTIF ---${NC}"
    local count=1
    declare -a map_pid
    while IFS='|' read -r pid no jam pesan; do
        echo -e "  ${GREEN}[$count]${NC} Info: ${YELLOW}$jam${NC} | Ke: ${CYAN}$no${NC} | Pesan: \"$pesan\""
        map_pid[$count]=$pid
        ((count++))
    done < "$JOB_FILE"
    read -p " >> Pilih nomor yang mau dihentikan (0 batal, A hentikan semua): " opt
    if [ "$opt" == "A" ] || [ "$opt" == "a" ]; then
        pkill -f "npx mudslide" 2>/dev/null
        > "$JOB_FILE"
        echo -e "${RED}[OK] Semua proses dihentikan!${NC}"
    elif [[ "$opt" =~ ^[0-9]+$ ]] && [ "$opt" -ge 1 ] && [ "$opt" -lt "$count" ]; then
        kill -9 "${map_pid[$opt]}" 2>/dev/null
        clean_jobs
        echo -e "${GREEN}[OK] Proses dihentikan!${NC}"
    fi
}

while true; do
    clear
    echo -e "${CYAN}==========================================================${NC}"
    echo -e "${WHITE}                 TOOL WA AUTOMATION (CLI)                 ${NC}"
    echo -e "${YELLOW}              Termux Edition v2.0 | WSTRN681              ${NC}"
    echo -e "${CYAN}==========================================================${NC}"
    echo ""
    echo -e "  ${GREEN}[1]${NC} Kirim Pesan Teks"
    echo -e "  ${GREEN}[2]${NC} Kirim Media (Foto, Video, MP3, Dokumen)"
    echo -e "  ${GREEN}[3]${NC} Kirim Broadcast (Spasi / File txt)"
    echo -e "  ${GREEN}[4]${NC} Kirim Pesan Berulang (Looping Background / Timer Detik)"
    echo -e "  ${GREEN}[5]${NC} Kirim Pesan Terjadwal (Jam Realtime)"
    echo -e "  ${GREEN}[6]${NC} Lihat & Hentikan Proses Background"
    echo -e "  ${GREEN}[7]${NC} Cek Status Login WA & Log"
    echo -e "  ${GREEN}[0]${NC} Keluar"
    echo ""
    echo -e "${CYAN}==========================================================${NC}"
    read -p " >> Pilih menu [0-7]: " menu

    case $menu in
        1)
            echo ""
            read -p "Masukkan nomor HP: " input_no
            read -p "Masukkan isi pesan: " pesan
            no=$(format_nomor "$input_no")
            echo -e "${BLUE}[*] Mengirim ke $no...${NC}"
            npx mudslide send "$no" "$pesan"
            log_action "SUKSES" "$no" "$pesan"
            send_notification "WA Automation" "Pesan terkirim ke $no"
            ;;
        2)
            echo ""
            read -p "Masukkan nomor HP: " input_no
            read -p "Lokasi file (contoh /sdcard/foto.jpg): " file
            read -p "Caption (opsional): " caption
            no=$(format_nomor "$input_no")
            echo -e "${BLUE}[*] Mengirim file ke $no...${NC}"
            ext="${file##*.}"
            ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
            case "$ext" in
                jpg|jpeg|png|webp|gif)
                    [ -z "$caption" ] && npx mudslide send-image "$no" "$file" || npx mudslide send-image --caption "$caption" "$no" "$file"
                    ;;
                mp4|mkv|avi|mov)
                    npx mudslide send-file --type video "$no" "$file"
                    ;;
                mp3|wav|m4a|ogg)
                    npx mudslide send-file --type audio "$no" "$file"
                    ;;
                *)
                    npx mudslide send-file "$no" "$file"
                    ;;
            esac
            log_action "MEDIA" "$no" "$file"
            ;;
        3)
            echo ""
            echo "1. Input Manual (Pisah Spasi) | 2. Dari File (nomor.txt)"
            read -p "Pilih [1-2]: " sub3
            if [ "$sub3" == "2" ]; then
                read -p "Lokasi file nomor.txt: " file_no
                daftar_no=$(cat "$file_no" 2>/dev/null)
            else
                read -p "Masukkan daftar nomor: " daftar_no
            fi
            if [ -n "$daftar_no" ]; then
                read -p "Masukkan isi pesan: " pesan
                read -p "Jeda acak (detik, default 3-7): " delay_in
                min_d=${delay_in:-3}
                max_d=$((min_d + 4))
                for in_no in $daftar_no; do
                    no=$(format_nomor "$in_no")
                    echo -e "${BLUE}[*] Kirim ke $no...${NC}"
                    npx mudslide send "$no" "$pesan"
                    log_action "BROADCAST" "$no" "$pesan"
                    sleep $(( min_d + RANDOM % (max_d - min_d + 1) ))
                done
            fi
            ;;
        4)
            echo ""
            read -p "Masukkan nomor HP: " input_no
            read -p "Masukkan isi pesan: " pesan
            read -p "Jeda pengiriman (detik, default 3): " jeda
            read -p "Berapa kali kirim (0 = ngulang terus, default 0): " jumlah
            no=$(format_nomor "$input_no")
            jeda=${jeda:-3}
            jumlah=${jumlah:-0}

            (
                loop_cnt=1
                while true; do
                    if [ "$jumlah" -gt 0 ] && [ "$loop_cnt" -gt "$jumlah" ]; then break; fi
                    npx mudslide send "$no" "$pesan" >/dev/null 2>&1
                    log_action "LOOP_BG" "$no" "Pesan ke-$loop_cnt: $pesan"
                    ((loop_cnt++))
                    sleep $jeda
                done
            ) >/dev/null 2>&1 &
            bg_pid=$!
            disown $bg_pid 2>/dev/null
            echo "$bg_pid|$no|Loop ${jeda}s ($jumlah x)|$pesan" >> "$JOB_FILE"
            echo -e "${GREEN}[OK] Berjalan di Background! (PID: $bg_pid)${NC}"
            ;;
        5)
            echo ""
            read -p "Masukkan nomor HP: " input_no
            read -p "Masukkan isi pesan: " pesan
            read -p "Waktu (HH:MM atau YYYY-MM-DD HH:MM): " jam_target
            no=$(format_nomor "$input_no")
            
            target_epoch=$(date -d "$jam_target" +%s 2>/dev/null)
            current_epoch=$(date +%s)
            if [ $target_epoch -le $current_epoch ]; then
                target_epoch=$(date -d "tomorrow $jam_target" +%s)
            fi
            sisa_detik=$((target_epoch - current_epoch))
            (
                sleep $sisa_detik
                npx mudslide send "$no" "$pesan" >/dev/null 2>&1
                log_action "JADWAL" "$no" "$pesan"
            ) >/dev/null 2>&1 &
            bg_pid=$!
            disown $bg_pid 2>/dev/null
            echo "$bg_pid|$no|$jam_target|$pesan" >> "$JOB_FILE"
            echo -e "${GREEN}[OK] Jadwal tersimpan untuk jam $jam_target!${NC}"
            ;;
        6)
            batalkan_jadwal
            ;;
        7)
            echo ""
            npx mudslide me
            echo ""
            echo -e "${CYAN}=== 10 LOG PENGIRIMAN TERAKHIR ===${NC}"
            tail -n 10 "$LOG_FILE"
            ;;
        0)
            exit 0
            ;;
    esac
    echo ""
    read -p "Tekan Enter untuk kembali ke menu..."
done
