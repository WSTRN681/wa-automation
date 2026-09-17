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
LOG_FILE="$HOME/.wa_history.log"
CONFIG_FILE="$HOME/.wa_config.txt"

touch "$JOB_FILE" "$LOG_FILE" "$CONFIG_FILE"

# Baca/Set Default Pengaturan Notifikasi HP
if ! grep -q "NOTIF_STATUS=" "$CONFIG_FILE"; then
    echo "NOTIF_STATUS=ON" > "$CONFIG_FILE"
fi
NOTIF_STATUS=$(grep "NOTIF_STATUS=" "$CONFIG_FILE" | cut -d'=' -f2)

# Auto-check izin storage HP & Kunci CPU Termux
if [ ! -d "$HOME/storage" ]; then
    echo -e "${YELLOW}[!] Menghubungkan izin penyimpanan HP ke Termux...${NC}"
    termux-setup-storage
    sleep 2
fi

termux-wake-lock 2>/dev/null

send_notification() {
    local title="$1"
    local message="$2"
    if [ "$NOTIF_STATUS" == "ON" ]; then
        if command -v termux-notification >/dev/null 2>&1; then
            termux-notification --title "$title" --content "$message" --priority high
        fi
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

parse_spintext() {
    local text="$1"
    local idx="$2"
    while [[ "$text" =~ \{([^}]+)\} ]]; do
        local options_str="${BASH_REMATCH[1]}"
        IFS='|' read -ra opts <<< "$options_str"
        local total_opts=${#opts[@]}
        local chosen_idx
        if [[ "$idx" =~ ^[0-9]+$ ]]; then
            chosen_idx=$(( (idx - 1) % total_opts ))
        else
            chosen_idx=$(( RANDOM % total_opts ))
        fi
        local chosen="${opts[$chosen_idx]}"
        text="${text/\{$options_str\}/$chosen}"
    done
    echo "$text"
}

log_action() {
    local status="$1"
    local target="$2"
    local info="$3"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] | Status: $status | Ke: $target | Info: $info" >> "$LOG_FILE"
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
        echo -e "${YELLOW}[!] Tidak ada proses/jadwal aktif di background.${NC}"
        return
    fi

    echo ""
    echo -e "${CYAN}==========================================================${NC}"
    echo -e "${WHITE}           DAFTAR PROSES / JADWAL BACKGROUND AKTIF        ${NC}"
    echo -e "${CYAN}==========================================================${NC}"
    
    local count=1
    declare -a map_pid
    declare -a map_no
    declare -a map_jam

    while IFS='|' read -r pid no jam pesan; do
        echo -e "  ${GREEN}[$count]${NC} Info: ${YELLOW}$jam${NC} | Ke: ${CYAN}$no${NC} | Pesan/Media: \"$pesan\""
        map_pid[$count]=$pid
        map_no[$count]=$no
        map_jam[$count]=$jam
        ((count++))
    done < "$JOB_FILE"

    echo -e "${CYAN}==========================================================${NC}"
    read -p " >> Pilih nomor proses yang ingin DIBATALKAN/HENTIKAN (0 untuk batal): " pilih_batal

    if [[ "$pilih_batal" =~ ^[0-9]+$ ]] && [ "$pilih_batal" -ge 1 ] && [ "$pilih_batal" -lt "$count" ]; then
        target_pid=${map_pid[$pilih_batal]}
        target_no=${map_no[$pilih_batal]}
        target_jam=${map_jam[$pilih_batal]}

        kill -9 "$target_pid" 2>/dev/null
        clean_jobs
        log_action "DIBATALKAN" "$target_no" "Proses $target_jam dihentikan user"
        echo -e "${RED}[OK] Proses $target_jam ke $target_no BERHASIL DIHENTIKAN!${NC}"
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
    log_action "SUKSES" "$no" "Media: $file"
    send_notification "WA Automation" "Media ($ext) terkirim ke $no!"
}

pengaturan_sistem() {
    echo ""
    echo -e "${YELLOW}--- [ PENGATURAN NOTIFIKASI & AUTO-CLEANUP ] ---${NC}"
    echo -e "Status Notifikasi HP Saat Ini: ${CYAN}$NOTIF_STATUS${NC}"
    echo "1. Ubah Status Notifikasi HP (ON / OFF)"
    echo "2. Jalankan Auto-Cleanup (Pembersih Cache & Log)"
    read -p "Pilih opsi [1-2]: " sub_p

    if [ "$sub_p" == "1" ]; then
        if [ "$NOTIF_STATUS" == "ON" ]; then
            NOTIF_STATUS="OFF"
        else
            NOTIF_STATUS="ON"
        fi
        echo "NOTIF_STATUS=$NOTIF_STATUS" > "$CONFIG_FILE"
        echo -e "${GREEN}[OK] Status Notifikasi HP diubah menjadi: $NOTIF_STATUS${NC}"
    elif [ "$sub_p" == "2" ]; then
        echo -e "${BLUE}[*] Membersihkan cache dan file sementara...${NC}"
        > "$LOG_FILE"
        clean_jobs
        rm -rf $HOME/.cache/* 2>/dev/null
        echo -e "${GREEN}[OK] Termux kinclong! Cache dan log berhasil dibersihkan.${NC}"
    fi
}

while true; do
    clear
    echo -e "${CYAN}==========================================================${NC}"
    echo -e "${WHITE}                 TOOL WA AUTOMATION (CLI)                 ${NC}"
    echo -e "${YELLOW}              Termux Edition v2.0 | WSTRN681              ${NC}"
    echo -e "${CYAN}==========================================================${NC}"
    echo ""
    echo -e "  ${GREEN}[1]${NC} Kirim Pesan Teks (Spintext Supported)"
    echo -e "  ${GREEN}[2]${NC} Kirim Media (Foto, Video, MP3, Dokumen)"
    echo -e "  ${GREEN}[3]${NC} Kirim Broadcast (File txt / Random Delay Anti-Spam)"
    echo ""
    echo -e "  ${GREEN}[4]${NC} Kirim Pesan Berulang (Looping Background / Timer Detik)"
    echo -e "  ${GREEN}[5]${NC} Kirim Pesan Terjadwal (Jam & Tanggal Realtime)"
    echo ""
    echo -e "  ${GREEN}[6]${NC} Lihat & Bersihkan Log Riwayat Pengiriman"
    echo -e "  ${GREEN}[7]${NC} Cek Status Login WA"
    echo -e "  ${GREEN}[8]${NC} Pengaturan Notifikasi HP & Auto-Cleanup"
    echo -e "  ${GREEN}[0]${NC} Keluar"
    echo ""
    echo -e "${CYAN}==========================================================${NC}"
    read -p " >> Pilih menu [0-8]: " menu

    case $menu in
        1)
            echo ""
            echo -e "${YELLOW}--- [ KIRIM PESAN TEKS ] ---${NC}"
            echo "1. Kirim 1 Chat"
            echo "2. Kirim Banyak Chat Sekaligus"
            read -p "Pilih opsi [1-2]: " sub1

            if [ "$sub1" == "1" ]; then
                read -p "Masukkan nomor HP (contoh 08123456789): " input_no
                read -p "Masukkan isi pesan (dukung spintext {Halo|Pagi}): " raw_pesan
                no=$(format_nomor "$input_no")
                pesan=$(parse_spintext "$raw_pesan")
                
                echo -e "${BLUE}[*] Mengirim pesan ke $no...${NC}"
                npx mudslide send "$no" "$pesan"
                log_action "SUKSES" "$no" "Teks: $pesan"
                send_notification "WA Automation" "Pesan terkirim ke $no!"
            elif [ "$sub1" == "2" ]; then
                read -p "Berapa banyak chat yang ingin dikirim? " total
                for ((i=1; i<=total; i++)); do
                    echo -e "${CYAN}--- Chat Ke-$i ---${NC}"
                    read -p "Masukkan nomor HP (contoh 08123456789): " input_no
                    read -p "Masukkan isi pesan: " raw_pesan
                    no=$(format_nomor "$input_no")
                    pesan=$(parse_spintext "$raw_pesan" "$i")
                    
                    echo -e "${BLUE}[*] Mengirim chat ke-$i ke $no...${NC}"
                    npx mudslide send "$no" "$pesan"
                    log_action "SUKSES" "$no" "Teks: $pesan"
                    send_notification "WA Automation" "Pesan ke-$i terkirim ke $no!"
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
                read -p "Masukkan nomor HP: " input_no
                read -p "Lokasi file (contoh: /sdcard/Download/musik.mp3): " file
                read -p "Masukkan caption (hanya untuk gambar/kosongkan): " raw_caption
                no=$(format_nomor "$input_no")
                caption=$(parse_spintext "$raw_caption")
                
                kirim_media_action "$no" "$file" "$caption"

            elif [ "$sub2" == "2" ]; then
                read -p "Masukkan nomor HP: " input_no
                read -p "Lokasi file (contoh: /sdcard/Download/musik.mp3): " file
                read -p "Masukkan caption (hanya untuk gambar/kosongkan): " raw_caption
                read -p "Masukkan jam kirim (Format HH:MM atau YYYY-MM-DD HH:MM): " jam_target
                no=$(format_nomor "$input_no")
                caption=$(parse_spintext "$raw_caption")

                if [[ "$jam_target" =~ ^[0-9]{2}:[0-9]{2}$ ]]; then
                    target_epoch=$(date -d "$jam_target" +%s 2>/dev/null)
                    current_epoch=$(date +%s)
                    if [ $target_epoch -le $current_epoch ]; then
                        target_epoch=$(date -d "tomorrow $jam_target" +%s)
                    fi
                else
                    target_epoch=$(date -d "$jam_target" +%s 2>/dev/null)
                fi

                current_epoch=$(date +%s)
                sisa_detik=$((target_epoch - current_epoch))

                (
                    sleep $sisa_detik
                    kirim_media_action "$no" "$file" "$caption" >/dev/null 2>&1
                ) >/dev/null 2>&1 &
                bg_pid=$!
                disown $bg_pid 2>/dev/null
                echo "$bg_pid|$no|$jam_target|File: $file" >> "$JOB_FILE"

                echo -e "${GREEN}[OK] Jadwal file tersimpan! Terkirim waktu $jam_target ke $no.${NC}"
                echo -e "${CYAN}[>] Berjalan mandiri di background!${NC}"
            fi
            ;;
        3)
            echo ""
            echo -e "${YELLOW}--- [ KIRIM BROADCAST ] ---${NC}"
            echo "1. Broadcast Manual (Pisah Spasi)"
            echo "2. Broadcast dari File Teks (nomor.txt)"
            read -p "Pilih opsi [1-2]: " sub3

            if [ "$sub3" == "1" ]; then
                read -p "Masukkan daftar nomor HP (pisahkan dengan spasi): " daftar_no
            elif [ "$sub3" == "2" ]; then
                read -p "Masukkan lokasi file daftar nomor (contoh /sdcard/Download/nomor.txt): " file_no
                if [ -f "$file_no" ]; then
                    daftar_no=$(cat "$file_no")
                else
                    echo -e "${RED}[!] File $file_no tidak ditemukan!${NC}"
                    daftar_no=""
                fi
            fi

            if [ -n "$daftar_no" ]; then
                read -p "Masukkan isi pesan (dukung spintext {Halo|Pagi}): " raw_pesan
                read -p "Mode Spintext [1] Urut | [2] Acak: " mode_spin
                read -p "Jeda acak minimal (detik, contoh 3): " min_jeda
                read -p "Jeda acak maksimal (detik, contoh 8): " max_jeda
                
                min_jeda=${min_jeda:-3}
                max_jeda=${max_jeda:-8}
                bc_count=1

                for input_no in $daftar_no; do
                    no=$(format_nomor "$input_no")
                    if [ "$mode_spin" == "1" ]; then
                        pesan=$(parse_spintext "$raw_pesan" "$bc_count")
                    else
                        pesan=$(parse_spintext "$raw_pesan")
                    fi

                    echo -e "${BLUE}[*] Mengirim ke $no...${NC}"
                    npx mudslide send "$no" "$pesan"
                    log_action "BROADCAST" "$no" "Teks: $pesan"

                    rand_delay=$(( min_jeda + RANDOM % (max_jeda - min_jeda + 1) ))
                    echo -e "${YELLOW}[~] Menunggu jeda acak $rand_delay detik...${NC}"
                    ((bc_count++))
                    sleep $rand_delay
                done
                send_notification "WA Automation" "Broadcast selesai dikirim!"
            fi
            ;;
        4)
            echo ""
            echo -e "${YELLOW}--- [ KIRIM PESAN BERULANG (TIMER DETIK) ] ---${NC}"
            read -p "Masukkan nomor HP: " input_no
            read -p "Masukkan isi pesan (contoh: {Woi|Oyyyyy|Halo}): " raw_pesan
            read -p "Mode Spintext: [1] Urut Berurutan | [2] Acak Random: " mode_loop
            read -p "Jeda pengiriman (dalam detik, contoh 5): " jeda
            read -p "Berapa kali dikirim (ketik 0 untuk ngulang terus tanpa batas): " jumlah
            echo ""
            echo "Pilih Mode Jalankan:"
            echo "1. Jalankan di Layar (Foreground)"
            echo "2. Jalankan Mandiri di Background (Bisa Bebarengan & Ditinggal)"
            read -p "Pilih mode [1-2]: " run_mode

            no=$(format_nomor "$input_no")
            jeda=${jeda:-3}
            jumlah=${jumlah:-1}

            if [ "$run_mode" == "2" ]; then
                (
                    loop_cnt=1
                    while true; do
                        if [ "$jumlah" -gt 0 ] && [ "$loop_cnt" -gt "$jumlah" ]; then
                            break
                        fi

                        if [ "$mode_loop" == "1" ]; then
                            pesan=$(parse_spintext "$raw_pesan" "$loop_cnt")
                        else
                            pesan=$(parse_spintext "$raw_pesan")
                        fi

                        npx mudslide send "$no" "$pesan" >/dev/null 2>&1
                        log_action "LOOP_BG" "$no" "Pesan ke-$loop_cnt: $pesan"
                        
                        ((loop_cnt++))
                        sleep $jeda
                    done
                    send_notification "WA Automation" "Looping $no selesai!"
                ) >/dev/null 2>&1 &
                
                bg_pid=$!
                disown $bg_pid 2>/dev/null
                
                label_limit="$jumlah x"
                if [ "$jumlah" -eq 0 ]; then
                    label_limit="Looping Terus"
                fi
                echo "$bg_pid|$no|Jeda ${jeda}s ($label_limit)|$raw_pesan" >> "$JOB_FILE"

                echo -e "${GREEN}[OK] Looping background berhasil dijalankan! (PID: $bg_pid)${NC}"
                echo -e "${CYAN}[>] Berjalan mandiri di background! Kamu bisa buat spammer lain lagi atau keluar.${NC}"
            else
                loop_cnt=1
                while true; do
                    if [ "$jumlah" -gt 0 ] && [ "$loop_cnt" -gt "$jumlah" ]; then
                        break
                    fi

                    if [ "$mode_loop" == "1" ]; then
                        pesan=$(parse_spintext "$raw_pesan" "$loop_cnt")
                    else
                        pesan=$(parse_spintext "$raw_pesan")
                    fi

                    echo -e "${BLUE}[$loop_cnt] Mengirim ke $no: \"$pesan\"${NC}"
                    npx mudslide send "$no" "$pesan"
                    log_action "LOOP" "$no" "Pesan ke-$loop_cnt: $pesan"
                    
                    ((loop_cnt++))
                    sleep $jeda
                done
                send_notification "WA Automation" "Pesan berulang selesai terkirim!"
            fi
            ;;
        5)
            echo ""
            echo -e "${YELLOW}--- [ KIRIM PESAN TERJADWAL ] ---${NC}"
            echo "1. Kirim 1 Chat Terjadwal"
            echo "2. Kirim Banyak Chat Terjadwal Sekaligus"
            echo "3. Lihat & Hentikan Proses Background (Semua Menu)"
            read -p "Pilih opsi [1-3]: " sub5

            if [ "$sub5" == "1" ]; then
                read -p "Masukkan nomor HP: " input_no
                read -p "Masukkan isi pesan: " raw_pesan
                read -p "Masukkan jadwal (Format HH:MM atau YYYY-MM-DD HH:MM): " jam_target
                no=$(format_nomor "$input_no")
                pesan=$(parse_spintext "$raw_pesan")

                if [[ "$jam_target" =~ ^[0-9]{2}:[0-9]{2}$ ]]; then
                    target_epoch=$(date -d "$jam_target" +%s 2>/dev/null)
                    current_epoch=$(date +%s)
                    if [ $target_epoch -le $current_epoch ]; then
                        target_epoch=$(date -d "tomorrow $jam_target" +%s)
                    fi
                else
                    target_epoch=$(date -d "$jam_target" +%s 2>/dev/null)
                fi

                current_epoch=$(date +%s)
                sisa_detik=$((target_epoch - current_epoch))

                (
                    sleep $sisa_detik
                    npx mudslide send "$no" "$pesan" >/dev/null 2>&1
                    send_notification "WA Automation" "Jadwal terkirim ke $no!"
                ) >/dev/null 2>&1 &
                bg_pid=$!
                disown $bg_pid 2>/dev/null
                echo "$bg_pid|$no|$jam_target|$pesan" >> "$JOB_FILE"

                echo -e "${GREEN}[OK] Jadwal tersimpan! Pesan untuk $no akan terkirim waktu $jam_target.${NC}"
                echo -e "${CYAN}[>] Berjalan mandiri di background!${NC}"

            elif [ "$sub5" == "2" ]; then
                read -p "Berapa banyak jadwal chat yang ingin dibuat? " total_jadwal
                for ((i=1; i<=total_jadwal; i++)); do
                    echo ""
                    echo -e "${CYAN}--- Setup Jadwal Ke-$i ---${NC}"
                    read -p "Masukkan nomor HP: " input_no
                    read -p "Masukkan isi pesan: " raw_pesan
                    read -p "Masukkan jadwal (Format HH:MM atau YYYY-MM-DD HH:MM): " jam_target
                    no=$(format_nomor "$input_no")
                    pesan=$(parse_spintext "$raw_pesan" "$i")

                    if [[ "$jam_target" =~ ^[0-9]{2}:[0-9]{2}$ ]]; then
                        target_epoch=$(date -d "$jam_target" +%s 2>/dev/null)
                        current_epoch=$(date +%s)
                        if [ $target_epoch -le $current_epoch ]; then
                            target_epoch=$(date -d "tomorrow $jam_target" +%s)
                        fi
                    else
                        target_epoch=$(date -d "$jam_target" +%s 2>/dev/null)
                    fi

                    current_epoch=$(date +%s)
                    sisa_detik=$((target_epoch - current_epoch))

                    (
                        sleep $sisa_detik
                        npx mudslide send "$no" "$pesan" >/dev/null 2>&1
                        send_notification "WA Automation" "Jadwal terkirim ke $no!"
                    ) >/dev/null 2>&1 &
                    bg_pid=$!
                    disown $bg_pid 2>/dev/null
                    echo "$bg_pid|$no|$jam_target|$pesan" >> "$JOB_FILE"

                    echo -e "${GREEN}[OK] [Jadwal $i] Dikirim waktu $jam_target ke $no.${NC}"
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
            echo -e "${YELLOW}--- [ LOG RIWAYAT PENGIRIMAN ] ---${NC}"
            echo "1. Lihat Log Riwayat Pengiriman"
            echo "2. Bersihkan Log Riwayat"
            read -p "Pilih opsi [1-2]: " sub6

            if [ "$sub6" == "1" ]; then
                echo -e "${CYAN}=== RIWAYAT LOG PENGIRIMAN ===${NC}"
                if [ -s "$LOG_FILE" ]; then
                    tail -n 20 "$LOG_FILE"
                else
                    echo -e "${YELLOW}[!] Belum ada log riwayat.${NC}"
                fi
            elif [ "$sub6" == "2" ]; then
                > "$LOG_FILE"
                echo -e "${GREEN}[OK] Log riwayat berhasil dibersihkan!${NC}"
            fi
            ;;
        7)
            echo ""
            echo -e "${YELLOW}--- [ CEK STATUS LOGIN WA ] ---${NC}"
            npx mudslide me
            ;;
        8)
            pengaturan_sistem
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
