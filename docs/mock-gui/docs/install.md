# Способы установки 

## С помощью ansible от пользователя root

```shell
dnf install epel-release
dnf install ansible git
git clone https://dev.brepo.ru/brepo/mock-gui.git
cd mock-gui/install
ansible-galaxy install -r requirements.yml
ansible-playbook mock-gui-install.yml --ask-become-pass
перезагрузить систему
systemctl enable mockgui
systemctl start mockgui
```

И обязательно задать пароль для mockgui, т.к. без ключа git будет запрашивать именно пароль для этого пользователя:

```shell
passwd mockgui
```

## С помощью ansible и пользователь в sudo

```shell
sudo dnf install epel-release
sudo dnf install ansible git
git clone https://dev.brepo.ru/brepo/mock-gui.git
cd mock-gui/install
ansible-galaxy install -r requirements.yml
ansible-playbook mock-gui-install.yml --ask-become-pass
перезагрузить систему
sudo systemctl enable mockgui
sudo systemctl start mockgui
```

И обязательно задать пароль для mockgui, т.к. без ключа git будет запрашивать именно пароль для этого пользователя:

```shell
passwd mockgui
```

## Ручная установка

Команды ниже выполнять под root или привилегированным пользователем с sudo:

1. отключить selinux
2. `systemctl stop firewalld`
3. `systemctl disable firewalld`
4. `systemctl stop nftables`
5. `systemctl disable nftables`
6.  `useradd mockgui`
7. Добавить репозиторий:
```ini
# cat /etc/yum.repos.d/brepo_projects.repo
[brepo_projects]
name=msvsphere9 repo on repo.brepo.ru
baseurl=https://repo.brepo.ru/hestia/
enabled=1
gpgkey=https://repo.brepo.ru/hestia/brepo_projects-gpg-key
gpgcheck=1
```
8. `dnf install epel-release`
9. `dnf install mock rpmdevtools rpm-build ccache rpm-sign sqlite sqlite-devel alt-brepo-ruby33 openssh-server git tar gcc gcc-c++ make cmake alt-brepo-ruby33-devel openssl-devel zlib-devel`
10.  `usermod -a -G mock mockgui`
11. добавить в .bashrc root и mockgui строки: `export PATH=/usr/lib64/ccache:$PATH`

Команды ниже выполнять под пользователем mockgui:


12. `cd ~`
13. `git clone https://dev.brepo.ru/brepo/mock-gui.git`
14. `cd mock-gui`
15. `/opt/brepo/ruby33/bin/bundle install`
16. `/opt/brepo/ruby33/bin/bundle exec sequel -m db/migrations sqlite://db/workbase.sqlite3`


Следующая команда от root:

17. `cp /home/mockgui/mock-gui/mockgui.service /etc/systemd/system/mockgui.service`
18. `systemctl enable mockgui.service --now`

И обязательно задать пароль для mockgui, т.к. без ключа git будет запрашивать именно пароль для этого пользователя:

19.  `passwd mockgui`

