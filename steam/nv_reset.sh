#!/bin/bash

# Introductory message using dialog
dialog --title "Warning" --msgbox "This is will delete data in the following folders to reset the Nvidia container driver install:\n\n1. ~/.local/share/Conty\n2. ~/pro/steam/home\n\n" 15 60

# Confirmation dialog
if dialog --title "Confirm" --yesno "Do you want to proceed and delete the folders? Type 'yes' to continue." 10 60; then
    rm -rf ~/pro/steam/home
    rm -rf ~/.local/share/Conty
    clear
    echo "Folders deleted."
    echo ""
    echo "" 
    echo "Attempting to start Steam.."
    /userdata/roms/conty/"Steam Big Picture Mode.sh"
else
    echo "Operation canceled. No folders were deleted."
fi