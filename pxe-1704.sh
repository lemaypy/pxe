#!/bin/bash

#install pxe server on ubuntu 17.04

function getIp() {
    echo $(hostname -I | awk '{ print $1 }')
}
function getSubIp() {
    firstthree=`echo $(getIp) | sed -e 's/\.[^.]*\$//'`
    echo $firstthree
}
function get_iso_file() {
    isofile=$1
    echo "execute scp command--> scp ${ssh_iso_addr}:${ssh_iso_sources}/${isofile} /data/iso/"
    scp ${ssh_iso_addr}:${ssh_iso_sources}/${isofile} /data/iso/
}
function get_iso_sources() {
    read -p "enter ssh iso sources server (example: user@192.168.0.xx): " ssh_iso_addr
    read -p "enter iso folder : " ssh_iso_sources
}
function updateOS() {
    echo "..............updateOS.......................... begin"
    sudo apt update
    sudo apt upgrade -y
    echo "..............updateOS.......................... end"
}
function installPackages() {
    echo "..............installPackages.......................... begin"
    sudo apt install -y dnsmasq pxelinux syslinux-common
    echo "..............installPackages.......................... end"
}
function create_tftp() {
    echo "..............create_tftp.......................... begin"
    create_tftp_dirs
    create_bootloader
    echo "..............create_tftp.......................... end"
}
function create_tftp_dirs() {
    echo "..............create_tftp_dirs.......................... begin"
    sudo mkdir -p /data
    sudo chown $USER:$USER /data
#    mkdir -p /data/tftpboot/i386/memtest
    sudo mkdir -p /data/iso
    sudo mkdir -p /data/tftpboot/pxelinux.cfg
    echo "..............create_tftp_dirs.......................... end"
}
function create_bootloader() {
    echo "..............create_bootloader.......................... begin"
    sudo ln -s /usr/lib/PXELINUX/pxelinux.0 /data/tftpboot/
    sudo ln -s /usr/lib/syslinux/modules/bios/vesamenu.c32 /data/tftpboot/
    sudo ln -s /usr/lib/syslinux/modules/bios/ldlinux.c32 /data/tftpboot/
    sudo ln -s /usr/lib/syslinux/modules/bios/libcom32.c32 /data/tftpboot/
    sudo ln -s /usr/lib/syslinux/modules/bios/libutil.c32 /data/tftpboot/
    echo "..............create_bootloader.......................... end"
}
function create_nfs_server() {
    echo "..............create_nfs_server.......................... begin"
    sudo apt install -y nfs-kernel-server
    sudo echo "/data/install "$(getSubIp)".0/24(ro,async,no_root_squash,no_subtree_check)" >> /etc/exports
    sudo exportfs -a
    echo "..............create_nfs_server.......................... end"
}
function config_dnsmasq() {
    echo "..............config_dnsmasq.......................... begin"
    sudo cp /etc/dnsmasq.conf /etc/dnsmasq.conf.bak
    sudo rm /etc/dnsmasq.conf

    sudo echo "# Configuration file for dnsmasq." > /etc/dnsmasq.conf
    sudo echo "port=0" >> /etc/dnsmasq.conf
    sudo echo "log-dhcp" >> /etc/dnsmasq.conf
    sudo echo "dhcp-range="$(getSubIp)".0,proxy" >> /etc/dnsmasq.conf
    sudo echo "dhcp-boot=pxelinux.0" >> /etc/dnsmasq.conf
    sudo echo "dhcp-no-override" >> /etc/dnsmasq.conf
    sudo echo "pxe-prompt="Booting Network Client", 1" >> /etc/dnsmasq.conf
    sudo echo "pxe-service=x86PC,\"Network Boot\",pxelinux" >> /etc/dnsmasq.conf
    sudo echo "pxe-service=X86-64_EFI, \"Boot UEFI PXE-64\", syslinux" >> /etc/dnsmasq.conf
    sudo echo "enable-tftp" >> /etc/dnsmasq.conf
    sudo echo "tftp-root=/data/tftpboot" >> /etc/dnsmasq.conf
    #quick hack to make sure our local dns on the server doesn't try to use its own dnsmasq
    sudo echo "DNSMASQ_EXCEPT=lo" >> /etc/default/dnsmasq
    echo "..............config_dnsmasq.......................... end"
}

function create_pxe_config_file() {
    echo "..............create_pxe_config_file.......................... begin"
    touch /data/tftpboot/pxelinux.cfg/default
    echo "# pxelinux.cfg/default." > /data/tftpboot/pxelinux.cfg/default
    echo "UI vesamenu.c32" >> /data/tftpboot/pxelinux.cfg/default
    echo "PROMPT 0" >> /data/tftpboot/pxelinux.cfg/default
    echo "MENU TITLE PY PXE Linux Bootloader" >> /data/tftpboot/pxelinux.cfg/default
    echo "INCLUDE /menu/common.cfg" >> /data/tftpboot/pxelinux.cfg/default
    echo "LABEL System Tools" >> /data/tftpboot/pxelinux.cfg/default
    echo "    MENU LABEL System Tools ->" >> /data/tftpboot/pxelinux.cfg/default
    echo "    CONFIG /menu/system.cfg" >> /data/tftpboot/pxelinux.cfg/default
    echo "LABEL Ubuntu Distributions" >> /data/tftpboot/pxelinux.cfg/default
    echo "    MENU LABEL Ubuntu Distributions ->" >> /data/tftpboot/pxelinux.cfg/default
    echo "    CONFIG /menu/ubuntu.cfg" >> /data/tftpboot/pxelinux.cfg/default
    echo "..............create_pxe_config_file.......................... end"
}
function create_main_menu() {
    echo "..............create_main_menu.......................... begin"
    mkdir -p /data/tftpboot/menu
    touch /data/tftpboot/menu/common.cfg
    #get the menu background
    wget https://i2.wp.com/www.vandewerken.com.au/blog/wp-content/uploads/2017/06/pxelinux-menu-background.png
    mv pxelinux-menu-background.png /data/tftpboot/menu/menu.png
    echo "# Menu common parts:" > /data/tftpboot/menu/common.cfg
    echo "MENU BACKGROUND /menu/menu.png" >> /data/tftpboot/menu/common.cfg
    echo "MENU TABMSG  http://www.vandewerken.com.au/blog/" >> /data/tftpboot/menu/common.cfg
    echo "MENU WIDTH 72" >> /data/tftpboot/menu/common.cfg
    echo "MENU MARGIN 10" >> /data/tftpboot/menu/common.cfg
    echo "MENU VSHIFT 3" >> /data/tftpboot/menu/common.cfg
    echo "MENU HSHIFT 6" >> /data/tftpboot/menu/common.cfg
    echo "MENU ROWS 15" >> /data/tftpboot/menu/common.cfg
    echo "MENU TABMSGROW 20" >> /data/tftpboot/menu/common.cfg
    echo "MENU TIMEOUTROW 22" >> /data/tftpboot/menu/common.cfg
    echo "menu color title 1;36;44 #66A0FF #00000000 none" >> /data/tftpboot/menu/common.cfg
    echo "menu color hotsel 30;47 #C00000 #DDDDDDDD" >> /data/tftpboot/menu/common.cfg
    echo "menu color sel 30;47 #000000 #FFFFFFFF" >> /data/tftpboot/menu/common.cfg
    echo "menu color border 30;44    #D00000 #00000000 std" >> /data/tftpboot/menu/common.cfg
    echo "menu color scrollbar 30;44 #DDDDDDDD #00000000 none" >> /data/tftpboot/menu/common.cfg
    echo "# end include" >> /data/tftpboot/menu/common.cfg
    echo "..............create_main_menu.......................... end"
}
function create_system_submenu() {
    echo "..............create_system_submenu.......................... begin"
    touch /data/tftpboot/menu/system.cfg
    echo "# /menu/system.cfg" > /data/tftpboot/menu/system.cfg
    echo "UI vesamenu.c32" >> /data/tftpboot/menu/system.cfg
    echo "PROMPT 0" >> /data/tftpboot/menu/system.cfg
    echo "MENU TITLE PY PXE Linux Bootloader" >> /data/tftpboot/menu/system.cfg
    echo "INCLUDE /menu/common.cfg" >> /data/tftpboot/menu/system.cfg
    echo "LABEL <-- Back to Main Menu" >> /data/tftpboot/menu/system.cfg
    echo "    CONFIG /pxelinux.cfg/default" >> /data/tftpboot/menu/system.cfg
    echo "    MENU SEPARATOR" >> /data/tftpboot/menu/system.cfg
}
function create_ubuntu_submenu() {
    echo "..............create_ubuntu_submenu.......................... begin"
    touch /data/tftpboot/menu/ubuntu.cfg
    echo "# ubuntu server tftpboot menu" > /data/tftpboot/menu/ubuntu.cfg
    echo "UI vesamenu.c32" >> /data/tftpboot/menu/ubuntu.cfg
    echo "MENU TITLE Ubuntu Distributions" >> /data/tftpboot/menu/ubuntu.cfg
    echo "INCLUDE /menu/common.cfg" >> /data/tftpboot/menu/ubuntu.cfg
    echo "LABEL <-- Back to Main Menu" >> /data/tftpboot/menu/ubuntu.cfg
    echo "  CONFIG /pxelinux.cfg/default" >> /data/tftpboot/menu/ubuntu.cfg
    echo "  MENU SEPARATOR" >> /data/tftpboot/menu/ubuntu.cfg
}


function add_ubuntu_distro() {
    flavor=$1
    dist=$2
    arch=$3
    type=$4
    iso=$5

    
    sudo mkdir -p /data/tftpboot/$flavor/$dist/$arch
    sudo mkdir -p /data/install/$flavor/$dist/$arch
    add_distro_to_ubuntu_menu $flavor $dist $arch $type
    install_ubuntu_distro $flavor $dist $arch $type $iso
}

function add_distro_to_ubuntu_menu() {
    flavor=$1
    dist=$2
    arch=$3
    type=$4

    #echo "append server receives ${flavor}-${dist}-${type}-${arch}"
    echo "#start ${flavor}-${dist}-${type}-${arch}" >> /data/tftpboot/menu/ubuntu.cfg
    echo "LABEL ${flavor}-${dist}-${type}-${arch}" >> /data/tftpboot/menu/ubuntu.cfg
    echo "  MENU LABEL ${flavor}-${dist}-${type}-${arch}" >> /data/tftpboot/menu/ubuntu.cfg
    echo "  KERNEL ${flavor}/${dist}/${arch}/vmlinuz" >> /data/tftpboot/menu/ubuntu.cfg
    if [ "${type}" = "desktop" ]; then
      echo "  APPEND boot=casper netboot=nfs nfsroot="$(getIp)":/data/install/${flavor}/${dist}/${arch} initrd=${flavor}/${dist}/${arch}/initrd.lz" >> /data/tftpboot/menu/ubuntu.cfg
    else
      echo "  APPEND boot=casper netboot=nfs nfsroot="$(getIp)":/data/install/${flavor}/${dist}/${arch} initrd=${flavor}/${dist}/${arch}/initrd.gz" >> /data/tftpboot/menu/ubuntu.cfg
    fi
    echo "  TEXT HELP" >> /data/tftpboot/menu/ubuntu.cfg
    echo "    Netboot ${flavor} ${type} ${dist} ${arch} DVD" >> /data/tftpboot/menu/ubuntu.cfg
    echo "  ENDTEXT" >> /data/tftpboot/menu/ubuntu.cfg
    echo "#end ${flavor}-${dist}-${type}-${arch}" >> /data/tftpboot/menu/ubuntu.cfg

}
function install_ubuntu_distro() {
    flavor=$1
    dist=$2
    arch=$3
    type=$4
    iso=$5

    sudo mount -o loop /data/iso/${iso} /mnt/loop
    if [ "${type}" = "desktop" ]; then
        sudo cp /mnt/loop/casper/vmlinuz* /data/tftpboot/${flavor}/${dist}/${arch}/vmlinuz
        sudo cp /mnt/loop/casper/initrd.lz /data/tftpboot/${flavor}/${dist}/${arch}
    else
        sudo cp /mnt/loop/install/vmlinuz /data/tftpboot/${flavor}/${dist}/${arch}
        sudo cp /mnt/loop/install/netboot/ubuntu-installer/${arch}/initrd.gz /data/tftpboot/${flavor}/${dist}/${arch}
    fi
    cp -R /mnt/loop/* /data/install/${flavor}/${dist}/${arch}
    cp -R /mnt/loop/.disk /data/install/${flavor}/${dist}/${arch}
    sudo umount /mnt/loop
    sleep 3
}

function add_memtest86() {
    mkdir -p /data/tftpboot/i386/memtest
    scp /data/iso/memtest86+-5.01.bin /data/tftpboot/i386/memtest/memtest86+-5.01
    echo "LABEL memtest86" >> /data/tftpboot/menu/system.cfg
    echo "    menu label memtest86+-5.01" >> /data/tftpboot/menu/system.cfg
    echo "    menu indent 1" >> /data/tftpboot/menu/system.cfg
    echo "    kernel /i386/memtest/memtest86+-5.01" >> /data/tftpboot/menu/system.cfg
}

function add_rescuecd_distro() {
    echo "LABEL rescueCD64" >> /data/tftpboot/menu/system.cfg
    echo "    menu label rescueCD-5.1---64bits" >> /data/tftpboot/menu/system.cfg
    echo "    menu indent 1" >> /data/tftpboot/menu/system.cfg
    echo "    kernel /i386/sysrescuecd/rescue64" >> /data/tftpboot/menu/system.cfg
    echo "append initrd=i386/sysrescuecd/initram.igz nfsboot=${getIp}:/data/install/systemrescuecd" >> /data/tftpboot/menu/system.cfg
    echo "LABEL rescueCD32" >> /data/tftpboot/menu/system.cfg
    echo "    menu label rescueCD-5.1---32bits" >> /data/tftpboot/menu/system.cfg
    echo "    menu indent 1" >> /data/tftpboot/menu/system.cfg
    echo "    kernel /i386/sysrescuecd/rescue32" >> /data/tftpboot/menu/system.cfg
    echo "append initrd=i386/sysrescuecd/initram.igz nfsboot=${getIp}:/data/install/systemrescuecd" >> /data/tftpboot/menu/system.cfg
    sudo mount -o loop /data/iso/systemrescuecd-x86-5.1.0.iso /mnt/loop
    sudo mkdir -p /data/install/systemrescuecd
    sudo cp /mnt/loop/sysrcd.dat /data/install/systemrescuecd
    sudo cp /mnt/loop/sysrcd.md5 /data/install/systemrescuecd
    sudo mkdir -p /data/tftpboot/i386/sysrescuecd
    sudo cp /mnt/loop/isolinux/rescue32 /data/tftpboot/i386/sysrescuecd
    sudo cp /mnt/loop/isolinux/rescue64 /data/tftpboot/i386/sysrescuecd
    sudo cp /mnt/loop/isolinux/initram.igz /data/tftpboot/i386/sysrescuecd
    sudo umount /mnt/loop
    sleep 3
}
function dynamic_ubuntu_dialog() {
    declare -A distro_info

    get_iso_sources
    get_distro_info

    # open fd
    exec 3>&1

    VALUES=$(dialog --ok-label "Add image" \
	        --backtitle "Add ubuntu distro" \
	        --title "Distro infos" \
	        --form "Adjust to fit your needs" \
            15 50 0 \
	        "iso:"      1 1	"${distro_info["iso"]}" 	1 10 60 0 \
	        "flavor:"   2 1	"${distro_info["flavor"]}" 	2 10 10 0 \
	        "dist:"     3 1	"${distro_info["dist"]}"  	3 10 10 0 \
	        "arch:"     4 1	"${distro_info["arch"]}"  	4 10 10 0 \
	        "type:"     5 1	"${distro_info["type"]}" 	5 10 10 0 \
            2>&1 1>&3)
    # close fd
    exec 3>&-

    # display values just entered
    #echo "$VALUES"
    add_ubuntu_distro ${VALUES[1]} ${VALUES[2]} ${VALUES[3]} ${VALUES[4]} ${VALUES[0]} 
}

function get_distro_info(){
    i=1
    declare -a filelist

    for file in $(ssh $ssh_iso_addr "ls ${ssh_iso_sources}")
    do  
        filelist[${#filelist[@]}+1]=$(echo "$file"); 
        lines="$lines $i $file off "
        ((++i))
    done

   # open fd
    exec 3>&1
    n=$(dialog --backtitle "Choose image file" --radiolist "image files" 0 0 $i $lines 2>&1 1>&3)
    # close fd
    exec 3>&-

    local iso=(${filelist[$n]})
    local arr=(${iso//-/ })
    local tosplitarch=${arr[3]}
    local arrarch=(${tosplitarch//./ })

    distro_info["iso"]=${filelist[$n]}
    distro_info["flavor"]=${arr[0]}
    distro_info["dist"]=${arr[1]}
    distro_info["type"]=${arr[2]}
    distro_info["arch"]=${arrarch[0]}
}


function installPXE() {
    count=99
    while :
    do
        if (($count == 0)); then
         #echo ".............................................updateOS"
          updateOS
          read -rsp $'Press any key to continue...\n' -n1 key
          ((count++))
        elif (($count == 1)); then
          #echo ".............................................installPackages"
          installPackages
          read -rsp $'Press any key to continue...\n' -n1 key
          ((count++))
        elif (($count == 2)); then
          #echo ".............................................create_tftp"
          create_tftp      
          read -rsp $'Press any key to continue...\n' -n1 key
          ((count++))
        elif (($count == 3)); then
          #echo ".............................................create_nfs_server"
          create_nfs_server
          read -rsp $'Press any key to continue...\n' -n1 key
          ((count++))
        elif (($count == 4)); then
          #echo ".............................................config_dnsmasq"
          config_dnsmasq
          read -rsp $'Press any key to continue...\n' -n1 key
          ((count++))
        elif (($count == 5)); then
          #echo ".............................................create_pxe_config_file"
          create_pxe_config_file
          read -rsp $'Press any key to continue...\n' -n1 key
          ((count++))
        elif (($count == 6)); then
          #echo ".............................................create_main_menu"
          create_main_menu
          read -rsp $'Press any key to continue...\n' -n1 key
          ((count++))
        elif (($count == 7)); then
         #echo ".............................................create_system_submenu"
          create_system_submenu
          read -rsp $'Press any key to continue...\n' -n1 key
          ((count++))
        elif (($count == 8)); then
         #echo ".............................................create_ubuntu_submenu"
          create_ubuntu_submenu
          read -rsp $'Press any key to continue...\n' -n1 key
          ((count++))
        elif (($count == 9)); then
            break;
        fi

    done
}
ssh_iso_addr=""
ssh_iso_sources=""

while :
do
    cmd=(dialog --separate-output --checklist "Select options:" 18 56 10)
    options=(1 "Install PXE" off
             2 "Add image memtest86" off
             3 "Add image systemrescue CD" off
             4 "Add ubuntu distro" on
             5 "<-- Exit" off)
    choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
    clear
    for choice in $choices
    do
        case $choice in
            1)
                echo "Install PXE"
                installPXE
                ;;
            2)
                echo "Add memtest86"
                add_memtest86
                ;;
            3)
                echo "Add systemrescue CD"
                add_rescuecd_distro
                ;;
            4)
                echo "Add ubuntu distro"
                dynamic_ubuntu_dialog
                ;;
            5)
                echo "Exit"
                break 2
                ;;
        esac
    done
done
echo ".............................................exit !!"















