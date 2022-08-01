#!/bin/bash
# this script will configure the system and install KDE Plasma










# chroot confirmation
#####################

printf "\e[1;32m\nChrooted into new environment and running chroot script\n\e[0m"
sleep 2










# import user inputs and system information
###########################################

read -r hostName userName userPassword rootPassword dualBoot timeZone reflectorCode diskName diskShred customConfig archURL nvme processorVendor cpuThreads graphicsVendor < /confidentials
# needs to be the exact same list of variables as in the install script










# configure pacman and reflector, and install all needed packages
#################################################################

# configure reflector
pacman -S --needed --noconfirm reflector
echo -e "--country "$reflectorCode"" >> /etc/xdg/reflector/reflector.conf
systemctl enable --now reflector.service


# configure pacman
sed -i 's/#\[multilib\]/\[multilib\]/;/\[multilib\]/{n;s/#Include /Include /}' /etc/pacman.conf
pacman -Syu --noconfirm
pacman -S --needed --asdeps --noconfirm pacman-contrib pacutils


# install essential packages
printf "\e[1;32m\nInstalling essential packages\n\e[0m"
sleep 2
pacman -S --needed base-devel bat btrfs-progs coreutils exfat-utils findutils git grub hwinfo ifuse libimobiledevice lshw man-db man-pages nano networkmanager nmap noto-fonts noto-fonts-emoji npm ntfs-3g pinfo plocate python-pip rsync shellcheck snap-pac snapper sudo texinfo tldr ufw unzip vim zip zoxide


# install kde plasma
printf "\e[1;32m\nInstalling KDE Plasma\n\e[0m"
sleep 2
pacman -S --needed kde-graphics kde-system kde-utilities plasma sddm xorg


# install printing packages
printf "\e[1;32m\nInstalling printing packages\n\e[0m"
sleep 2
pacman -S --needed print-manager


# install graphics drivers
if [ "$graphicsVendor" != null ]
then
    printf "\e[1;32m\nInstalling graphics drivers\n\e[0m"
    sleep 2
fi
if [ "$graphicsVendor" == amd ]
then
    pacman -S --needed mesa lib32-mesa lib32-vulkan-radeon libva-mesa-driver lib32-libva-mesa-driver mesa-vdpau lib32-mesa-vdpau vulkan-radeon xf86-video-amdgpu
fi
if [ "$graphicsVendor" == intel ]
then
    pacman -S --needed xf86-video-intel mesa lib32-mesa vulkan-intel
fi
if [ "$graphicsVendor" == nvidia ]
then
    pacman -S --needed nvidia nvidia-settings nvidia-utils lib32-nvidia-utils
fi


# install dependencies
printf "\e[1;32m\nInstalling dependencies\n\e[0m"
sleep 2

# grub
pacman -S --needed --asdeps efibootmgr grub-btrfs os-prober
# set as dependencies
package=grub
dependsOn=("efibootmgr" "grub-btrfs" "os-prober")
package=$(ls /var/lib/pacman/local | grep -i "$package")
for n in "${dependsOn[@]}";
do
    needed=$(grep -io "$n" /var/lib/pacman/local/"$package"/desc)
    if [ -z "$needed" ]
    then
        sed -i "s/%DEPENDS%/%DEPENDS%\n""$n""/g" /var/lib/pacman/local/"$package"/desc
    fi
done


# printing
pacman -S --needed --asdeps avahi cups cups-pdf nss-mdns system-config-printer usbutils
# set as dependencies
package=print-manager
dependsOn=("avahi" "cups" "cups-pdf" "nss-mdns" "system-config-printer" "usbutils")
package=$(ls /var/lib/pacman/local | grep -i "$package")
for n in "${dependsOn[@]}";
do
    needed=$(grep -io "$n" /var/lib/pacman/local/"$package"/desc)
    if [ -z "$needed" ]
    then
        sed -i "s/%DEPENDS%/%DEPENDS%\n""$n""/g" /var/lib/pacman/local/"$package"/desc
    fi
done










# configure the system
######################

printf "\e[1;32m\nConfiguring the system\n\e[0m"
sleep 2


# set the time and language
ln -sf /usr/share/zoneinfo/"$timeZone" /etc/localtime
hwclock --systohc
sed -i 's/#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >> /etc/locale.conf


# set the hostname
echo -e "$hostName" >> /etc/hostname


# configure the network
echo -e "127.0.0.1   localhost" >> /etc/hosts
echo -e "::1         localhost" >> /etc/hosts
echo -e "127.0.1.1   $hostName" >> /etc/hosts


# configure root user
echo -e "$rootPassword\n$rootPassword" | passwd root
# echo -e "root ALL=(ALL:ALL) ALL" >> /etc/sudoers


# configure user
useradd -m -g users -G wheel -s /bin/bash "$userName"
echo -e "$userPassword\n$userPassword" | passwd "$userName"
echo -e "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers


# enable microcode updates
pacman -S --needed --noconfirm "$processorVendor"-ucode


# configure mkinitcpio.conf
sed -i 's/MODULES=()/MODULES=(btrfs)/' /etc/mkinitcpio.conf
# put btrfs into modules instead of hooks due to a bug that is documented on the arch wiki btrfs page. Also see the mkinitcpio arch wiki page for configuring mkinitcpio file
mkinitcpio -p linux


# configure grub
sed -i 's/GRUB_TIMEOUT=5/GRUB_TIMEOUT=3/' /etc/default/grub
if [ "$dualBoot" == Y ] || [ "$dualBoot" == y ] || [ "$dualBoot" == yes ] || [ "$dualBoot" == YES ] || [ "$dualBoot" == Yes ]
then
  sed -i 's/#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
fi
grub-mkconfig -o /boot/grub/grub.cfg


# enable and speed up package builds
if [ "$cpuThreads" != null ]
then
    sed -i "s/#MAKEFLAGS=\"-j[0-9]*\"/MAKEFLAGS=\"-j"$cpuThreads"\"/g" /etc/makepkg.conf
fi










# enable network manager and ssdm to boot into KDE Plasma
#########################################################

printf "\e[1;32m\nEnabling KDE Plasma\n\e[0m"
sleep 2


# enable network manager
systemctl enable NetworkManager


# enable sddm
systemctl enable sddm










# import files
##############

printf "\e[1;32m\nImporting files\n\e[0m"
sleep 2


# import custom config files
if [ "$customConfig" == true ]
then
    mkdir /home/"$userName"/Desktop
    chown -R "$userName":users /home/"$userName"/Desktop
    git clone https://github.com/ksan314/personal /home/"$userName"/personal
    chown -R "$userName":users /home/"$userName"/personal
    cp /home/"$userName"/personal/arch/packages.txt /home/"$userName"/Desktop
fi


# save arch repo
git clone "$archURL" /home/"$userName"/arch
chown -R "$userName":users /home/"$userName"/arch










# exit the chroot environment (does this automatically when script ends)
########################################################################
printf "\e[1;32m\nExiting the chroot environment\n\e[0m"
sleep 2

