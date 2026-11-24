notify-send "Starting wallpaper daemon"
yin & disown
notify-send "Trying to restore previous wallpaper"
sleep 2s 
yinctl --restore
