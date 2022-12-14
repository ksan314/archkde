#!/bin/bash
# this script gets user input, automatically gets system information, checks to see if system is ready for install, creates a 1GB FAT32 efi boot partition, creates a btrfs root partition that takes up the rest of the disk that conforms to the snapper suggested filesystem layout from the arch wiki, installs linux, then chroots into system and runs chroot script










# get user input
################

# get hostname
while true
do
read -rp $'\n'"Enter a new name for this device: " hostName
    if [ -z "$hostName" ]
    then
        echo -e "\nYou must enter a name for this device\n"
    else
        read -rp $'\n'"Are you sure you want to use the name \"$hostName\" for this device? [Y/n] " hostnameConfirm
        hostnameConfirm=${hostnameConfirm:-Y}
        case $hostnameConfirm in
            [yY][eE][sS]|[yY]) break;;
            [nN][oO]|[nN]);;
            *);;
        esac
        REPLY=
    fi
done


# get username
while true
do
read -rp $'\n'"Enter new username: " userName
    if [ -z "$userName" ]
    then
        echo -e "\nYou must enter a username\n"
    else
        read -rp $'\n'"Are you sure you want to use the username \"$userName\"? [Y/n] " usernameConfirm
        usernameConfirm=${usernameConfirm:-Y}
        case $usernameConfirm in
            [yY][eE][sS]|[yY]) break;;
            [nN][oO]|[nN]);;
            *);;
        esac
        REPLY=
    fi
done


# get user password
while true
do
read -srp $'\n'"Enter new password for $userName: " userPassword1
read -srp $'\n'"Confirm new password for $userName: " userPassword2
    if [ "$userPassword1" != "$userPassword2" ]
    then
        echo -e "\nPasswords do not match, try again\n"
    elif [ -z "$userPassword1" ] || [ -z "$userPassword2" ]
    then
        echo -e "\nPassword cannot be blank, try again\n"
    else
        userPassword=$userPassword1
        break
    fi
done


# get root password
while true
do
read -srp $'\n'"Enter new root password: " rootPassword1
read -srp $'\n'"Confirm new root password: " rootPassword2
    if [ "$rootPassword1" != "$rootPassword2" ]
    then
        echo -e "\nPasswords do not match, try again\n"

    elif [ -z "$rootPassword1" ] || [ -z "$rootPassword2" ]
    then
        echo -e "\nPassword cannot be blank, try again\n"

    else
        rootPassword=$rootPassword1
        break
    fi
done


# get timezone
mapfile -t timeZones < <(timedatectl list-timezones)
PS3="Enter the number for your current timezone: "
select timeZone in "${timeZones[@]}"
do
    if (( REPLY > 0 && REPLY <= "${#timeZones[@]}" ))
    then
        read -rp $'\n'"Are you sure you want to select the timezone \"$timeZone\"? [Y/n] " zoneConfirm
        zoneConfirm=${zoneConfirm:-Y}
            case $zoneConfirm in
                [yY][eE][sS]|[yY]) break;;
                [nN][oO]|[nN]);;
                *);;
            esac
            REPLY=
    else
        echo -e "\nInvalid option. Try another one\n"
        sleep 2
        REPLY=
    fi
done


# get reflector country
mapfile -t reflectorCountries < <(reflector --list-countries)
PS3="Enter the number for the country you want to download packages from: "
select reflectorCountry in "${reflectorCountries[@]}"
do
    if (( REPLY > 0 && REPLY <= "${#reflectorCountries[@]}" ))
    then
        read -rp $'\n'"Are you sure you want to select the country \"$reflectorCountry\"? [Y/n] " reflectorConfirm
        reflectorConfirm=${reflectorConfirm:-Y}
            case $reflectorConfirm in
                [yY][eE][sS]|[yY]) break;;
                [nN][oO]|[nN]);;
                *);;
            esac
            REPLY=
    else
        echo -e "\nInvalid option. Try another one\n"
        sleep 2
        REPLY=
    fi
done
reflectorCode=$(echo -e "$reflectorCountry" | grep -o '[A-Z][A-Z]')


# get disk name
mapfile -t availableDisks < <(lsblk -o PATH,SIZE,TYPE,MODEL,PTTYPE | grep -i disk)
PS3="Enter the number for the disk you want to use: "
select selectedDisk in "${availableDisks[@]}"
do
  if (( REPLY > 0 && REPLY <= "${#availableDisks[@]}" ))
  then
    read -rp $'\n'"Are you sure you want to use the disk $selectedDisk? [Y/n] " diskConfirm
    diskConfirm=${diskConfirm:-Y}
            case $diskConfirm in
                [yY][eE][sS]|[yY]) break;;
                [nN][oO]|[nN]);;
                *);;
            esac
            REPLY=
  else
    echo -e "\nInvalid option. Try another one\n"
    sleep 2
    REPLY=
  fi
done
diskName=$(lsblk -o PATH,SIZE,TYPE,MODEL,PTTYPE | grep -i "$selectedDisk" | awk '{print $1}')


# get disk shred
while true
do
read -rp $'\n'"Would you like to erase all data on the disk $diskName? [y/N] " diskShred
    diskShred=${diskShred:-N}
    if [ "$diskShred" == Y ] || [ "$diskShred" == y ] || [ "$diskShred" == yes ] || [ "$diskShred" == YES ] || [ "$diskShred" == Yes ]
    then
        diskShred=true
        read -rp $'\n'"Are you sure you DO want to erase all data on the disk $diskName? [Y/n] " diskshredConfirm
        diskshredConfirm=${diskshredConfirm:-Y}
        case $diskshredConfirm in
            [yY][eE][sS]|[yY]) break;;
            [nN][oO]|[nN]);;
            *);;
        esac
        REPLY=
    else
        diskShred=false
        read -rp $'\n'"Are you sure you DO NOT want to erase all data on the disk $diskName? [Y/n] " diskshredConfirm
        diskshredConfirm=${diskshredConfirm:-Y}
        case $diskshredConfirm in
            [yY][eE][sS]|[yY]) break;;
            [nN][oO]|[nN]);;
            *);;
        esac
        REPLY=
    fi
done


# should the system check for other operating systems?
while true
do
read -rp $'\n'"Would you like the bootloader to check for other operating systems? [Y/n] " dualBoot
    dualBoot=${dualBoot:-Y}
if [ "$dualBoot" == Y ] || [ "$dualBoot" == y ] || [ "$dualBoot" == yes ] || [ "$dualBoot" == YES ] || [ "$dualBoot" == Yes ]
then
    read -rp $'\n'"Are you sure you want the bootloader to check for other operating systems? [Y/n] " dualbootConfirm
        dualbootConfirm=${dualbootConfirm:-Y}
        case $dualbootConfirm in
            [yY][eE][sS]|[yY]) break;;
            [nN][oO]|[nN]);;
            *);;
        esac
        REPLY=
else
   read -rp $'\n'"Are you sure you DO NOT want the bootloader to check for other operating systems? [Y/n] " dualbootConfirm
        dualbootConfirm=${dualbootConfirm:-Y}
        case $dualbootConfirm in
            [yY][eE][sS]|[yY]) break;;
            [nN][oO]|[nN]);;
            *);;
        esac
        REPLY=
fi
done


# get custom config
while true
do
read -rp $'\n'"Would you like to include the repo owner's custom configurations? (Includes colored output for various bash commands, anti-malware scanners, virtual machine config, and plasma config) [Y/n] " customConfig
    customConfig=${customConfig:-Y}
    if [ "$customConfig" == Y ] || [ "$customConfig" == y ] || [ "$customConfig" == yes ] || [ "$customConfig" == YES ] || [ "$customConfig" == Yes ]
    then
        customConfig=true
        read -rp $'\n'"Are you sure you DO want to include the repo owner's custom configurations? [Y/n] " customconfigConfirm
        customconfigConfirm=${customconfigConfirm:-Y}
        case $customconfigConfirm in
            [yY][eE][sS]|[yY]) break;;
            [nN][oO]|[nN]);;
            *);;
        esac
        REPLY=
    else
        customConfig=false
        read -rp $'\n'"Are you sure you DO NOT want to use the repo owner's custom configurations? [Y/n] " customconfigConfirm
        customconfigConfirm=${customconfigConfirm:-Y}
        case $customconfigConfirm in
            [yY][eE][sS]|[yY]) break;;
            [nN][oO]|[nN]);;
            *);;
        esac
        REPLY=
    fi
done


# user input ended
printf "\e[1;32m\nNo more user input needed\n\e[0m"
sleep 2










# install packages needed for installation
##########################################

printf "\e[1;32m\nInstalling packages needed for installation\n\e[0m"
sleep 2

pacman -S archlinux-keyring ca-certificates
pacman -S --needed hwinfo lshw










# automatically get system information
######################################

# get arch url
archURL=$(grep -i url /root/archkde/.git/config | awk '{print $3}')


# check if disk an nvme?
nvme=$(echo -e "$diskName" | grep -io nvme)
if [ -z $nvme ]
then
    nvme=false
else
    nvme=true
fi


# get processor vendor
processorVendor=$(hwinfo --cpu | grep -i vendor | grep -io 'amd\|intel' | awk '{print tolower($0)}' | head -n 1)


# get number of cpu threads for building packages
cpuThreads=$(hwinfo --cpu | grep -i 'Units' | awk '{print $2}' | head -n 1)
if [ -z "$cpuThreads" ]
then
    cpuThreads=null
fi


# get graphics vendor
graphicsVendor=$(hwinfo --gfxcard | grep -i vendor | grep -io 'amd\|ati\|intel\|nvidia' | awk '{print tolower($0)}' | head -n 1)
if [ "$graphicsVendor" == ati ]
then
    graphicsVendor=amd
fi
if [ -z "$graphicsVendor" ]
then
    graphicsVendor=null
fi










# save inputs that will be needed for chroot script in a file that will be sourced later
########################################################################################

echo -e "$hostName $userName $userPassword $rootPassword $timeZone $reflectorCode $diskName $diskShred $dualBoot $customConfig $archURL $nvme $processorVendor $cpuThreads $graphicsVendor" > ./confidentials










# verify the system is ready for install
########################################

printf "\e[1;32m\nVerifying the system is ready for arch installation\n\e[0m"
sleep 2


# verify that the system is booted in UEFI mode
ls /sys/firmware/efi/efivars


# verify that the internet is working
ping -c 5 archlinux.org










# configure storage
###################

printf "\e[1;32m\nConfiguring storage\n\e[0m"
sleep 2

# unmount any partitions mounted to /mnt
umount -R /mnt


# shred disk
if [ "$diskShred" == true ]
then
    shred -v --random-source=/dev/zero -n1 "$diskName"
fi


# create partitions
echo -e "g\n n\n \n \n +1G\n y\n t\n 1\n n\n \n \n \n y\n t\n \n 23\n w\n" | fdisk "$diskName"

#g\n    create new GPT partition table

# create efi partition
#n\n    create new partition
#\n     set default partition number
#\n     set default first sector
#+1G\n  select last sector such that the new partition is 1GB in size
#y\n    accept prompt if given
#t\n    change partition type
#1\n    set partition type to efi

# create root partition
#n\n    create new partition
#\n     set default partition number
#\n     set default first sector
#\n     set default last sector
#y\n    accept prompt if given
#t\n    change partition type
#\n     select default partition
#23\n   set partition type to Linux root (x86-64)

# write changes and exit
#w\n    write changes to disk and exit


# create filesystems
if [ "$nvme" == true ]
then
  yes | mkfs.fat -F32 "$diskName"p1
  yes | mkfs.btrfs "$diskName"p2 
fi
if [ "$nvme" == false ]
then
  yes | mkfs.fat -F32 "$diskName"1
  yes | mkfs.btrfs "$diskName"2
fi


# mount and configure filesystems
if [ "$nvme" == true ]
then
  mount "$diskName"p2 /mnt
  btrfs subvolume create /mnt/@
  btrfs subvolume create /mnt/@home
  btrfs subvolume create /mnt/@snapshots
  btrfs subvolume create /mnt/@var_log
  umount /mnt
  mount -o noatime,compress=zstd,space_cache=v2,subvol=@ "$diskName"p2 /mnt
  mkdir /mnt/boot
  mkdir /mnt/home
  mkdir /mnt/.snapshots
  mkdir -p /mnt/var/log
  mount -o noatime,compress=zstd,space_cache=v2,subvol=@home "$diskName"p2 /mnt/home
  mount -o noatime,compress=zstd,space_cache=v2,subvol=@snapshots "$diskName"p2 /mnt/.snapshots
  mount -o noatime,compress=zstd,space_cache=v2,subvol=@var_log "$diskName"p2 /mnt/var/log
  mount "$diskName"p1 /mnt/boot
fi
if [ "$nvme" == false ]
then
  mount "$diskName"2 /mnt
  btrfs subvolume create /mnt/@
  btrfs subvolume create /mnt/@home
  btrfs subvolume create /mnt/@snapshots
  btrfs subvolume create /mnt/@var_log
  umount /mnt
  mount -o noatime,compress=zstd,space_cache=v2,subvol=@ "$diskName"2 /mnt
  mkdir /mnt/boot
  mkdir /mnt/home
  mkdir /mnt/.snapshots
  mkdir -p /mnt/var/log
  mount -o noatime,compress=zstd,space_cache=v2,subvol=@home "$diskName"2 /mnt/home
  mount -o noatime,compress=zstd,space_cache=v2,subvol=@snapshots "$diskName"2 /mnt/.snapshots
  mount -o noatime,compress=zstd,space_cache=v2,subvol=@var_log "$diskName"2 /mnt/var/log
  mount "$diskName"1 /mnt/boot
fi










# update the system clock
#########################

printf "\e[1;32m\nUpdating Clock\n\e[0m"
sleep 2
timedatectl set-ntp true










# install linux packages
########################

printf "\e[1;32m\nInstalling linux packages\n\e[0m"
sleep 2
pacstrap /mnt base linux linux-firmware










# generate an fstab file
########################

printf "\n\e[1;32mGenerating fstab file\n\e[0m"
sleep 2
genfstab -U /mnt >> /mnt/etc/fstab










# prepeare to change root into the new system and run chroot script
###################################################################

printf "\e[1;32m\nChrooting into new environment and running chroot script\n\e[0m"
sleep 2


# copy the confidentials file to destination system's root partition so that chroot script can access the file from inside of chroot
cp ./confidentials /mnt


# copy the chroot script to destination system's root partition
cp ./chroot.sh /mnt


# change file permission of chroot script to make it executable
chmod +x /mnt/chroot.sh


# change root into the new environment and run chroot script
arch-chroot /mnt /chroot.sh










# finish installation
#####################

printf "\e[1;32m\nFinishing installation\n\e[0m"
sleep 2


# delete variables and chroot.sh
rm /mnt/confidentials
rm /mnt/chroot.sh


# unmount all partitions
umount -R /mnt


# reboot the system
printf "\e[1;32m\nInstallation Complete. Enter \"reboot\" to reboot the system\n\e[0m"
