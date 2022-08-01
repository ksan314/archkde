# Description

This is a bash script that installs Arch Linux in UEFI mode with KDE Plasma.
The installation includes a swap file that is equal to the size of installed ram, printing capabilities, bluetooth, and automatic recommended system maintenance. 

---

### Details

  - Dual booting on the same disk is not supported. The installation will wipe the entire disk selected by the user. It will include a 1GB FAT32 efi boot partition, and an ext4 root partition that uses the rest of the disk
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
  4. `git clone https://github.com/ksanf3/arch`
  5. `cd arch`
  6. `chmod +x ./install`
  7. `./install`
      - Read the input prompts carefully. This will install arch linux, then reboot 
automatically into KDE Plasma desktop environment.
  8. If you chose to include the repo owner's custom configurations, there should be a file on the desktop, read it before continuing.
  9. Run the config script with the following commands to finish configuring the system...
      - `su`
      - `chmod +x arch/config`
      - `arch/config`
