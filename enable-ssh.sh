#!/bin/bash

sed '/Port/s/^# *//' /etc/ssh/sshd_config
sudo service ssh restart

