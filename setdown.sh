#!/bin/bash

# This script helps with cleaning up my MacBook. It automatically backs up needed
# files to my SSH server (aliased as "serv") and removes anything private before
# reimaging.

# This script should be run as root.

# Backup files over SSH, then remove, given paths
function burm {
    (scp -r $@ serv:dump-$(hostname)/; rm -rf $@) &
}

if [ "$TERM" = "screen" ] && [ $(id -u) = 0 ]; then
    echo "Running as root in screen or tmux. Will continue."
else
    echo "Please run as root in screen or tmux."
    exit 1
fi

user=$(stat -f "%Su" /dev/console)
src=~$user/src

echo "Burn beginning in 5 seconds..."
sleep 5s

echo "Removing this script from user's account before we start..."
rm -rf ~$user/setdown* /var/root/setdown* &

echo "Removing all dotfiles/folders in root dir, some of which maybe shouldn't be there..."
rm -rf /var/root/.*

echo "Getting user's ssh config so this all works more smoothly..."
cp -r ~$user/.ssh /var/root/.ssh

echo "Removing user's SSH known_hosts..."
rm ~$user/.ssh/known_hosts*

echo "Making dump dir on server..."
ssh serv -o StrictHostKeyChecking=no -t "mkdir -p ~/dump-$(hostname)"

echo "Turning off SSHD for all users..."
dscl . change /Groups/com.apple.access_ssh-disabled RecordName com.apple.access_ssh-disabled com.apple.access_ssh

echo "Clearing cronjobs..."
burm /var/at/tabs

echo "Disabling proxy..."
su $user -c "~$user/.bin/prox off"

echo "Removing ~/bin..."
rm -rf ~$user/.bin &

echo "Getting rid of all prompt histories..."
rm /Users/*/.*history /var/root/.*history

echo "Backing up git projects..."
touch ~$user/repos.txt
for dir in $(ls $src); do
    # if file/folder either isn't a GitHub repository or has unpushed changes
    # This way we don't waste time copying a bunch of repos which are already on GitHub
    if [ -f $src/$dir ] || ! [ -e $src/$dir/.git ] || [[ $(git -C $src/$dir status --porcelain) ]]; then
        burm $src/$dir
    else
        echo $dir >> ~$user/repos.txt
    fi
done
burm ~$user/repos.txt

echo "Removing questionable repositories..."
rm -rf $src/fish $src/net &

echo "Clearing terminal backups..."
rm -f ~$user/Library/Saved\ Application\ State/com.apple.Terminal.savedState/*

echo "Clearing logs..."
rm -rf /var/log/*

echo "Removing root ssh folder..."
rm -rf /var/root/.ssh

wait

##############################################
# Assume nothing past this message will run. #
##############################################

echo "Wipedown complete. Killing terminals."

for i in 3 2 1; do
    echo "$i..."
    sleep 1s
done

echo "Killing terminals..."

killall term Terminal ayy i_term iTerm2

echo "Killing all multiplex sessions..."
killall tmux
killall screen
