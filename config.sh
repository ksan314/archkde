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


# get root subvolume id
rootSubvolumeID=$(btrfs subvolume list / | grep -i "@$" | awk '{print $2}')


# get zram size in MB, equal to half the size of ram, and convert to integer
ramSize=$(free -m | grep -i mem | awk '{print $2}')
swapSize=$(echo -e "$ramSize * 0.5" | bc)
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


# configure snapper (see snapper page on arch wiki)
# delete /.snapshots directory since snapper will automatically create a /.snapshots subvolume when creating a root config
umount /.snapshots
rm -r /.snapshots
# create snapper configs
snapper -c root create-config /
snapper -c home create-config /home  # maybe i need to delete the /home/.snapshots subvolume and mkdir /home/.snapshots ??
# delete subvolume automatically created by snapper
btrfs subvolume delete /.snapshots
# re-create snapshots directory and mount based on fstab file
mkdir /.snapshots
mount -a
chmod 750 /.snapshots
# set root subvolume as default subvolume so we can boot from snapshots of root subvolume
btrfs subvolume set-default "$rootSubvolumeID" /
# give wheel group access to /.snapshots directory
chmod g+rx /.snapshots
chown -R :wheel /.snapshots         # maybe remove the -R
# give wheel group access to /home/.snapshots directory
chmod g+rx /home/.snapshots
chown -R :wheel /home/.snapshots    # maybe remove the -R
# configure snapper config for root subvolume
sed -i 's/ALLOW_GROUPS=""/ALLOW_GROUPS="wheel"/' /etc/snapper/configs/root
sed -i 's/ALLOW_GROUPS=""/ALLOW_GROUPS="wheel"/' /etc/snapper/configs/home
sed -i 's/HOURLY="[0-9]*"/HOURLY="5"/' /etc/snapper/configs/root
sed -i 's/DAILY="[0-9]*"/DAILY="5"/' /etc/snapper/configs/root
sed -i 's/WEEKLY="[0-9]*"/WEEKLY="5"/' /etc/snapper/configs/root
sed -i 's/MONTHLY="[0-9]*"/MONTHLY="5"/' /etc/snapper/configs/root
sed -i 's/YEARLY="[0-9]*"/YEARLY="5"/' /etc/snapper/configs/root
# configure snapper config for home subvolume
sed -i 's/HOURLY="[0-9]*"/HOURLY="5"/' /etc/snapper/configs/home
sed -i 's/DAILY="[0-9]*"/DAILY="5"/' /etc/snapper/configs/home
sed -i 's/WEEKLY="[0-9]*"/WEEKLY="5"/' /etc/snapper/configs/home
sed -i 's/MONTHLY="[0-9]*"/MONTHLY="5"/' /etc/snapper/configs/home
sed -i 's/YEARLY="[0-9]*"/YEARLY="5"/' /etc/snapper/configs/home
# enable automatic timeline snapshots and automatic cleanup based on /etc/snapper/configs
systemctl enable snapper-timeline.timer
systemctl enable snapper-cleanup.timer


# configure grub-btrfs (updates grub snapshots menu when new snapshots are created)
systemctl enable --now grub-btrfs.path
grub-mkconfig -o /boot/grub/grub.cfg
# may need to edit /etc/default/grub-btrfs/config (edit to require password)


# configure snap-pac for home subvolume (see snap-pac man page)
echo -e "[home]" >> /etc/snap-pac.ini
echo -e "snapshot = True" >> /etc/snap-pac.ini


# backup boot partition on kernel updates (see "snapshots and /boot parition" section on "system backup" arch wiki page)
mkdir /etc/pacman.d/hooks
cp /home/"$userName"/arch/files/95-bootbackup.hook /etc/pacman.d/hooks


# manually create snapshots before running the rest of config.sh
snapper -c root create -d "***before config.sh***"
snapper -c home create -d "***before config.sh***"










# configure system
##################

printf "\e[1;32m\nConfiguring system\n\e[0m"
sleep 2


###################################################
# configure btrfs (see "btrfs" arch wiki page)


# configure zram
sed -i 's/FRACTION=[0-9,\.]*/FRACTION=0.5/' /etc/default/zramd
sed -i "s/MAX_SIZE=[0-9,\.]*/MAX_SIZE=$swapsizeInteger/" /etc/default/zramd
systemctl enable zramd


# configure paccache
systemctl enable paccache.timer


# enable man-db.timer
systemctl enable man-db.timer


# enable disk trim
systemctl enable fstrim.timer


# enable bluetooth
systemctl enable bluetooth.service
sed -i 's/#AutoEnable=false/AutoEnable=false/' /etc/bluetooth/main.conf


# configure printing
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
export MANPAGER="less -R --use-color -Dd+r -Du+b"
#echo "export LESS_TERMCAP_md=$'\e[1;32m'" >> /home/"$userName"/.bashrc
#echo "export LESS_TERMCAP_me=$'\e[0m'" >> /home/"$userName"/.bashrc
#echo "export LESS_TERMCAP_us=$'\e[1;4;34m'" >> /home/"$userName"/.bashrc
#echo "export LESS_TERMCAP_ue=$'\e[0m'" >> /home/"$userName"/.bashrc
#echo "export LESS_TERMCAP_so=$'\e[01;31m'" >> /home/"$userName"/.bashrc
#echo "export LESS_TERMCAP_se=$'\e[0m'" >> /home/"$userName"/.bashrc
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
su -c "mkdir -p /home/$userName/.local/share/kxmlgui5/dolphin" "$userName"
su -c "cp /home/$userName/personal/plasma/dolphinui.rc /home/$userName/.local/share/kxmlgui5/dolphin" "$userName"
su -c "touch /home/$userName/.config/dolphinrc" "$userName"
echo -e "[General]\nRememberOpenedTabs=false" >> /home/"$userName"/.config/dolphinrc
su -c "mkdir -p /home/$userName/.local/share/dolphin/view_properties/global" "$userName"
su -c "touch /home/$userName/.local/share/dolphin/view_properties/global/.directory" "$userName"
echo -e "[Settings]\nHiddenFilesShown=true" >> /home/"$userName"/.local/share/dolphin/view_properties/global/.directory
su -c "touch /home/$userName/.config/ktrashrc" "$userName"
echo -e "[/home/$userName/.local/share/Trash]\nDays=14\nLimitReachedAction=0\nPercent=10\nUseSizeLimit=true\nUseTimeLimit=true" >> /home/"$userName"/.config/ktrashrc


# configure kde plasma
# config files
cp /home/"$userName"/personal/plasma/wallpaper.jpg /usr/share/wallpapers
su -c "cp /home/$userName/personal/plasma/mimeapps.list /home/$userName/.config" "$userName"
su -c "cp /home/$userName/personal/plasma/plasmanotifyrc /home/$userName/.config" "$userName"
su -c "cp /home/$userName/personal/plasma/plasma-org.kde.plasma.desktop-appletsrc /home/$userName/.config" "$userName"
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
su -c "touch /home/$userName/.config/plasmarc" "$userName"
echo -e "[Wallpapers]\nusersWallpapers=/usr/share/wallpapers/wallpaper.jpg" > /home/"$userName"/.config/plasmarc
# lock screen wallpaper
echo -e "\n[Greeter][Wallpaper][org.kde.image][General]\nImage=/usr/share/wallpapers/wallpaper.jpg" >> /home/"$userName"/.config/kscreenlockerrc
# sddm wallpaper
echo -e "[General]\nbackground=/usr/share/wallpapers/wallpaper.jpg" > /usr/share/sddm/themes/breeze/theme.conf.user
#
# colors based on wallpaper with pywal
# check if python-pywal is installed
pythonpywalExists=$(pacman -Qqs python-pywal)
if [ "$pythonpywalExists" == python-pywal ]
then
    su -c "wal -i /usr/share/wallpapers/wallpaper.jpg" "$userName"
    echo -e "\n# Enables pywal theme on reboot" >> /home/"$userName"/.bashrc
    echo -e "(cat ~/.cache/wal/sequences &)" >> /home/"$userName"/.bashrc
    # colors are saved in /home/cache/wal/colors.yml
fi
#
# indexer
echo -e "only basic indexing=true" >> /home/"$userName"/.config/baloofilerc
#
# autostart apps
#su -c "mkdir -p /home/$userName/.config/autostart" "$userName"
#su -c "cp /usr/share/applications/guake.desktop /home/"$userName"/.config/autostart" "$userName"
#chown -R "$userName":users /home/"$userName"/.config/autostart/guake.desktop


# save config files to desktop
su -c "cp /home/$userName/personal/plasma/guake.config /home/$userName/Desktop" "$userName"
su -c "cp /home/$userName/personal/plasma/qbittorrent.txt /home/$userName/Desktop" "$userName"
su -c "cp /home/$userName/personal/plasma/system_monitor.page /home/$userName/Desktop" "$userName"


# remove custom config files
rm -rf /home/"$userName"/personal
rm -rf /home/"$userName"/Desktop/packages.txt

fi










# remove files, and reboot
##########################

# remove no longer needed files
rm -rf /home/"$userName"/arch


# create a snapshot
snapper -c root create -d "***after config.sh***"
snapper -c home create -d "***after config.sh***"


# reboot
printf "\e[1;32m\nConfig complete. Enter \"reboot\" to reboot the system\n\e[0m"
