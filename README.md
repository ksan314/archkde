# Description

This is a bash script that installs Arch Linux in UEFI mode with KDE Plasma.
The installation includes printing capabilities, bluetooth, and automatic recommended system maintenance. 

---

### Details

  - Dual booting on the same disk is not supported. The installation will remove all date on the disk selected by the user. It will include a 1GB FAT32 efi boot partition, and a btrfs root partition that takes up the rest of the disk that conforms to the snapper suggested filesystem layout from the arch wiki
  - To scroll up and down during installation, press "Ctrl+b" then "[", then you can use the arrow or page up/down keys. To exit scrolling mode, press "q"
  - Cancel the installation at any time with "Ctrl+c"

---

# Instructions

After booting into arch linux from a live medium in UEFI mode, run the install script with the following commands...
  1. `tmux`
  2. if you need to connect to wifi, run...
      - `iwctl`
      - `device list`
      - `station [device_name] scan`
      - `station [device_name] get-networks`
      - `station [device_name] conenct [network_name]`
  3. `pacman -Sy git` 
  4. `git clone https://github.com/ksanf3/archkde`
  5. `cd archkde`
  6. `chmod +x ./install.sh`
  7. `./install.sh`
      - Read the input prompts carefully. This will install arch linux, along with KDE desktop environment. You need to reboot when done.
  8. If you chose to include the repo owner's custom configurations, there should be a file on the desktop, read it before continuing.
  9. After the script is done and you reboot run the config script with the following commands to finish configuring the system...
      - `su`
      - `chmod +x archkde/config.sh`
      - `archkde/config.sh`
