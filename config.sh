#!/bin/bash
# this script sets user specific configurations, configures packages and their services, then reboots (run as root)










# check root status
###################

currentUser=$(whoami)
if [ "$currentUser" != root ]
then
    echo -e "\nYou must be logged in as root to run this script\n"
    exit
elif [ "$currentUser" == root ]
then
    sleep 1
fi










# automatically get system information
######################################

# get username
userName=$(users | awk '{print $1}')


# get root partition
rootPartition=$(fdisk -l | grep -i "linux root" | awk '{print $1}')


# get root subvolume id
rootSubvolumeID=$(btrfs subvolume list / | grep -i "@$" | awk '{print $2}')


# get swap size in MB, equal to 25% of ram, and convert to integer
ramSize=$(free -m | grep -i mem | awk '{print $2}')
swapSize=$(echo -e ""$ramSize" * 0.25" | bc)
swapsizeInteger=${swapSize%.*}


# get custom config
customConfig=$(ls /home/"$userName" | grep -io personal)
if [ "$customConfig" == personal ]
then
    customConfig=true
else
    customConfig=false
fi










# configure snapshots
#####################

printf "\e[1;32m\nConfiguring snapshots\n\e[0m"
sleep 2


# configure snapper
umount /.snapshots
rm -r /.snapshots
snapper -c root create-config /
snapper -c home create-config /home
btrfs subvolume delete /.snapshots
mkdir /.snapshots
mount -a
chmod 750 /.snapshots
# set root subvolume as default subvolume
btrfs subvolume set-default "$rootSubvolumeID" /
# give wheel group access to /.snapshots directory
chmod a+rx /.snapshots
chown :wheel /.snapshots
# configure snapper configs for root and home subvolumes
sed -i 's/ALLOW_GROUPS=""/ALLOW_GROUPS="wheel"/' /etc/snapper/configs/root
sed -i 's/ALLOW_GROUPS=""/ALLOW_GROUPS="wheel"/' /etc/snapper/configs/home
# may also need to change "limits for timeline cleanup" (see snapper arch wiki page for reccomendation)
# enable automatic timeline snapshots and automatic cleanup based on /etc/snapper/configs
systemctl enable snapper-timeline.timer
systemctl enable snapper-cleanup.timer


# configure grub-btrfs
# updates grub snapshots menu when new snapshots are created
systemctl enable --now grub-btrfs.path
# may need to edit /etc/default/grub-btrfs/config


# configure snap-pac
# edit the file /etc/snap-pac.ini
# see snap-pac man page


# create a snapshot before running the rest of config.sh
snapper -c root create -d "***Before config.sh***"
snapper -c home/"$userName" create -d "***Before config.sh***"


# backup boot partition on pacman transactions
# see "snapshots and /boot parition" section on "system backup" arch wiki page
mkdir /etc/pacman.d/hooks
cp /home/"$userName"/arch/files/95-bootbackup.hook /etc/pacman.d/hooks










# configure system
##################

printf "\e[1;32m\nConfiguring system\n\e[0m"
sleep 2


# configure zram
zramd start -f 0.25 -m "$swapsizeInteger"
systemctl enable zramd


# configure paccache
systemctl enable paccache.timer


# enable man-db.timer
systemctl enable man-db.timer


# enable fstrim
systemctl enable fstrim.timer


# enable bluetooth
systemctl enable bluetooth.service
sed -i 's/#AutoEnable=false/AutoEnable=false/' /etc/bluetooth/main.conf


# configure cups
systemctl enable --now avahi-daemon.service
sed -i 's/mymachines/mymachines mdns_minimal [NOTFOUND=return]/' /etc/nsswitch.conf
systemctl enable cups.socket


# configure plocate
systemctl enable plocate-updatedb.timer
echo -e "\n#plocate" >> /home/"$userName"/.bashrc
echo -e "alias locate='plocate'" >> /home/"$userName"/.bashrc










# set custom configurations
###########################

if [ "$customConfig" == true ]
then

# configure bash
#
echo -e "\n# colored bash prompt" >> /home/"$userName"/.bashrc
echo 'export PS1="\[\e[34m\][\[\e[m\]\[\e[32m\]\u\[\e[m\]\[\e[34m\]@\[\e[m\]\[\e[32m\]\h\[\e[m\] \[\e[31m\]\W\[\e[m\]\[\e[34m\]]\[\e[m\]\[\e[31m\]\\$\[\e[m\] "' >> /home/"$userName"/.bashrc
#
echo -e "\n# enables color" >> /home/"$userName"/.bashrc
echo -e "alias diff='diff --color=auto'" >> /home/"$userName"/.bashrc
echo -e "alias grep='grep --color=auto'" >> /home/"$userName"/.bashrc
echo -e "alias ip='ip -color=auto'" >> /home/"$userName"/.bashrc
echo -e "alias ls='ls --color=auto'" >> /home/"$userName"/.bashrc
echo -e "alias pactree='pactree --color'" >> /home/"$userName"/.bashrc
echo -e "alias sudo='sudo '" >> /home/"$userName"/.bashrc
echo -e "alias info='pinfo'" >> /home/"$userName"/.bashrc
echo "export LESS_TERMCAP_md=$'\e[1;32m'" >> /home/"$userName"/.bashrc
echo "export LESS_TERMCAP_me=$'\e[0m'" >> /home/"$userName"/.bashrc
echo "export LESS_TERMCAP_us=$'\e[1;4;34m'" >> /home/"$userName"/.bashrc
echo "export LESS_TERMCAP_ue=$'\e[0m'" >> /home/"$userName"/.bashrc
echo "export LESS_TERMCAP_so=$'\e[01;31m'" >> /home/"$userName"/.bashrc
echo "export LESS_TERMCAP_se=$'\e[0m'" >> /home/"$userName"/.bashrc
#
echo -e "\n# enables cd auto-correct" >> /home/"$userName"/.bashrc
echo -e "shopt -s cdspell" >> /home/"$userName"/.bashrc
#
echo -e "\n# rewrap text on window resize" >> /home/"$userName"/.bashrc
echo -e "shopt -s checkwinsize" >> /home/"$userName"/.bashrc
#
echo -e "#clears screen after logging out" >> /home/"$userName"/.bash_logout
echo -e "clear" >> /home/"$userName"/.bash_logout
echo -e "reset" >> /home/"$userName"/.bash_logout


# configure pacman
sed -i 's/#Color/Color\nILoveCandy/' /etc/pacman.conf


# configure paru
sed -i 's/#BottomUp/BottomUp/' /etc/paru.conf


# configure pinfo
sed -i 's/COL_MENU           = COLOR_BLUE   ,  COLOR_DEFAULT,  BOLD   ,  NO_BLINK/COL_MENU           = COLOR_GREEN  ,  COLOR_DEFAULT,  BOLD   ,  NO_BLINK/' /etc/pinforc
sed -i 's/COL_NOTE           = COLOR_GREEN  ,  COLOR_DEFAULT,  BOLD   ,  NO_BLINK/COL_NOTE           = COLOR_BLUE   ,  COLOR_DEFAULT,  BOLD   ,  NO_BLINK/' /etc/pinforc
sed -i 's/COL_TOPLINE        = COLOR_YELLOW ,  COLOR_BLUE   ,  BOLD   ,  NO_BLINK/COL_TOPLINE        = COLOR_BLACK  ,  COLOR_GREEN  ,  BOLD   ,  NO_BLINK/' /etc/pinforc
sed -i 's/COL_BOTTOMLINE     = COLOR_YELLOW ,  COLOR_BLUE   ,  BOLD   ,  NO_BLINK/COL_BOTTOMLINE     = COLOR_BLACK  ,  COLOR_GREEN  ,  BOLD   ,  NO_BLINK/' /etc/pinforc
sed -i 's/COL_URL            = COLOR_MAGENTA,  COLOR_DEFAULT,  BOLD   ,  NO_BLINK/COL_URL            = COLOR_BLUE   ,  COLOR_DEFAULT,  BOLD   ,  NO_BLINK/' /etc/pinforc


# configure bat
su -c "bat --generate-config-file" "$userName"
echo -e "--theme=\"ansi\"" >> /home/"$userName"/.config/bat/config


# configure jackett
systemctl enable jackett


# disable power saving mode for sound card
#sed -i 's/load-module module-suspend-on-idle/#load-module module-suspend-on-idle/' /etc/pulse/default.pa


# configure RKHunter (rootkit hunter)
rkhunter --propupd


# configure clamav (antivirus)
freshclam
systemctl enable clamav-freshclam
systemctl enable clamav-daemon
sudo -Su clamav /usr/bin/fangfrisch --conf /etc/fangfrisch/fangfrisch.conf initdb
systemctl enable fangfrisch.timer


# configure virtual machine manager (libvirt)
systemctl enable libvirtd.service


# configure dolphin
su -c "mkdir -p /home/"$userName"/.local/share/kxmlgui5/dolphin" "$userName"
su -c "cp /home/"$userName"/personal/plasma/dolphinui.rc /home/"$userName"/.local/share/kxmlgui5/dolphin" "$userName"
su -c "touch /home/"$userName"/.config/dolphinrc" "$userName"
echo -e "[General]\nRememberOpenedTabs=false" >> /home/"$userName"/.config/dolphinrc
su -c "mkdir -p /home/"$userName"/.local/share/dolphin/view_properties/global" "$userName"
su -c "touch /home/"$userName"/.local/share/dolphin/view_properties/global/.directory" "$userName"
echo -e "[Settings]\nHiddenFilesShown=true" >> /home/"$userName"/.local/share/dolphin/view_properties/global/.directory
su -c "touch /home/"$userName"/.config/ktrashrc" "$userName"
echo -e "[/home/$userName/.local/share/Trash]\nDays=14\nLimitReachedAction=0\nPercent=10\nUseSizeLimit=true\nUseTimeLimit=true" >> /home/"$userName"/.config/ktrashrc


# configure kde plasma
# config files
cp /home/"$userName"/personal/plasma/wallpaper.jpg /usr/share/wallpapers
su -c "cp /home/"$userName"/personal/plasma/mimeapps.list /home/"$userName"/.config" "$userName"
su -c "cp /home/"$userName"/personal/plasma/plasmanotifyrc /home/"$userName"/.config" "$userName"
su -c "cp /home/"$userName"/personal/plasma/plasma-org.kde.plasma.desktop-appletsrc /home/"$userName"/.config" "$userName"
sed -i 's/\[General\]/\[General\]\nBrowserApplication=chromium.desktop\nTerminalApplication=guake\nTerminalService=guake.desktop/' /home/"$userName"/.config/kdeglobals
#
# theme
sed -i 's/Adwaita/Breeze/' /usr/share/gtk-3.0/settings.ini
echo -e "gtk-application-prefer-dark-theme = true" >> /usr/share/gtk-3.0/settings.ini
sed -i 's/Adwaita/Breeze/' /usr/share/gtk-4.0/settings.ini
echo -e "gsettings set org.gnome.desktop.interface color-scheme prefer-dark" >> /usr/share/gtk-4.0/settings.ini
su -c "plasma-apply-lookandfeel --apply org.kde.breezedark.desktop" "$userName"
sed -i 's/\[General\]/\[General\]\nAccentColor=61,212,37/' /home/"$userName"/.config/kdeglobals
#
# wallpaper
# desktop wallpaper
su -c "touch /home/"$userName"/.config/plasmarc" "$userName"
echo -e "[Wallpapers]\nusersWallpapers=/usr/share/wallpapers/wallpaper.jpg" > /home/"$userName"/.config/plasmarc
# lock screen wallpaper
echo -e "\n[Greeter][Wallpaper][org.kde.image][General]\nImage=/usr/share/wallpapers/wallpaper.jpg" >> /home/"$userName"/.config/kscreenlockerrc
# sddm wallpaper
echo -e "[General]\nbackground=/usr/share/wallpapers/wallpaper.jpg" > /usr/share/sddm/themes/breeze/theme.conf.user
#
# colors based on wallpaper with pywal
su -c "wal -i /usr/share/wallpapers/wallpaper.jpg" "$userName"
echo -e "\n# Enables pywal theme on reboot" >> /home/"$userName"/.bashrc
echo -e "(cat ~/.cache/wal/sequences &)" >> /home/"$userName"/.bashrc
# colors are saved in /home/cache/wal/colors.yml
#
# indexer
echo -e "only basic indexing=true" >> /home/"$userName"/.config/baloofilerc
#
# autostart apps
#su -c "mkdir -p /home/"$userName"/.config/autostart" "$userName"
#su -c "cp /usr/share/applications/guake.desktop /home/"$userName"/.config/autostart" "$userName"
#chown -R "$userName":users /home/"$userName"/.config/autostart/guake.desktop


# save config files to desktop
su -c "cp /home/"$userName"/personal/plasma/guake.config /home/"$userName"/Desktop" "$userName"
su -c "cp /home/"$userName"/personal/plasma/qbittorrent.txt /home/"$userName"/Desktop" "$userName"
su -c "cp /home/"$userName"/personal/plasma/system_monitor.page /home/"$userName"/Desktop" "$userName"


# remove custom config files
rm -rf /home/"$userName"/personal
rm -rf /home/"$userName"/Desktop/packages.txt

fi










# remove files, and reboot
##########################

# remove no longer needed files
rm -rf /home/"$userName"/arch


# create a snapshot
snapper -c root create -d "***After config.sh***"
snapper -c home create -d "***After config.sh***"


# reboot
printf "\e[1;32m\nConfig complete. Enter \"reboot\" to reboot the system\n\e[0m"
