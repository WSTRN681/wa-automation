#!/bin/bash

# Kode Warna ANSI (100% Didukung Termux)
CYAN='\033[1;36m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
BLUE='\033[1;34m'
PURPLE='\033[1;35m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

clear

# Fungsi perbaikan nomor (Hanya hapus angka 0 depan)
format_nomor() {
    local num="$1"
    if [[ $num == 0* ]]; then
        echo "62${num#0}"
    else
        echo "$num"
    fi
}

while true; do
    echo -e "${CYAN}==========================================================${NC}"
    echo -e "${WHITE}                 TOOL WA AUTOMATION (CLI)                 ${NC}"
    echo -e "${YELLOW}              Termux Edition v2.0 | WSTRN681              ${NC}"
    echo -e "${CYAN}==========================================================${NC}"
    echo ""
    echo -e "  ${GREEN}[1]${NC} Kirim Pesan Teks (Singel / Multi Chat)"
    echo -e "  ${GREEN}[2]${NC} Kirim Gambar / Foto (+ Caption)"
    echo -e "  ${GREEN}[3]${NC} Kirim Pesan Broadcast (Banyak Nomor)"
    echo ""
    echo -e "  ${GREEN}[4]${NC} Kirim Pesan Berulang (Looping)"
    echo -e "  ${GREEN}[5]${NC} Kirim Pesan Terjadwal (Jam Realtime)"
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
            echo -e "${YELLOW}--- [ KIRIM GAMBAR / FOTO ] ---${NC}"
            read -p "Masukkan no telepon: " no
            read -p "Lokasi foto (contoh: /sdcard/Download/foto.jpg): " foto
            read -p "Masukkan caption foto: " caption
            no=$(format_nomor "$no")
            
            echo -e "${BLUE}[*] Mengirim gambar ke $no...${NC}"
            if [ -z "$caption" ]; then
                npx mudslide send-image "$no" "$foto"
            else
                npx mudslide send-image "$no" "$foto" --caption "$caption"
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
            read -p "Pilih opsi [1-2]: " sub5

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
                ) &

                echo -e "${GREEN}[OK] Jadwal tersimpan! Pesan untuk $no akan terkirim jam $jam_target (dalam $sisa_detik detik).${NC}"
                echo -e "${CYAN}[>] Berjalan di background! Kamu bisa langsung pakai Termux lagi.${NC}"

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
                    ) &

                    echo -e "${GREEN}[OK] [Jadwal $i] Dikirim jam $jam_target ke $no (Latar belakang aktif!).${NC}"
                done
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
    clear
done
