#!//bin/bash
TITLE=Wiki
vHOST=localhost
vPORT=5432
vUSER=isogd
vPASSWORD=Qwerty123
vDBNAME=wiki
vPASSH=Qwe
vLOGIN=root


USER=$(whiptail --title $TITLE --inputbox "ВВедите существующего пользователя базы данных" 10 60 $vUSER 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus = 0 ]; then
	vUSER=$USER
else
	echo "Cancel"
	exit 1
fi

PASSWORD=$(whiptail --title $TITLE --passwordbox "ВВедите пароль пользователя базы данных" 10 60  3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus = 0 ]; then
	vPASSWORD=$PASSWORD
else
	echo "Cancel"
	exit 1
fi

PORT=$(whiptail --title $TITLE --inputbox "ВВедите существующий порт Базы данных" 10 60 $vPORT 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus = 0 ]; then
	vPORT=$PORT
else
	echo "Cancel"
	exit 1
fi

DB=$(whiptail --title  $TITLE --inputbox  "Задайте имя базы данных для Wiki" 10 60 $vDBNAME 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus = 0 ];  then
   	vDBNAME=$DB
else
    echo "You chose Cancel."
	exit 1
fi

HOST=$(whiptail --title  $TITLE --inputbox  "ВВедите существующий адрес Базы данных" 10 60 $vHOST 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus = 0 ];  then
     vHOST=$HOST
     if [ $vHOST != localhost ]; then {
 		(whiptail --title  $TITLE --msgbox  "Для создания новой базы данных неоходимо ssh подключение к удаленному устройству БД" 10 60 $vHOST 3>&1 1>&2 2>&3)
 		LOGIN=$(whiptail --title $TITLE --inputbox "ВВедите логин" 10 60 $vLOGIN 3>&1 1>&2 2>&3)
 		exitstatus=$?
 		if [ $exitstatus = 0 ]; then
 			vLOGIN=$LOGIN
 		else
 			exit 1
 		fi;
 		PASS=$(whiptail --title $TITLE --inputbox "ВВедите пароль" 10 60 3>&1 1>&2 2>&3)
 		exitstatus=$?
 		if [ $exitstatus = 0 ]; then
 			vPASSH=$PASS
 		else
 			exit 1
 		fi;
 				#Установить sshpass
 				#подключиться
 				chmod +x sshpass
 			 ./sshpass -p$vPASSH ssh -o StrictHostKeyChecking=no $vLOGIN@$vHOST "(cd /opt/pgsql; sudo su postgres -c 'createdb ${vDBNAME} --owner=${vUSER}' &>>log)"
 			 exitstatus=$?
 			 if [ $exitstatus != 1 ]; then
 			 	echo $exitstatus
 			 	echo "Не удалось подключиться к серверу базы данных"
 			 	exit 1
 			 fi
 				#создать
 				#return true
 			}

 	else
 		(cd /opt/pgsql; sudo su postgres -c "createdb ${vDBNAME} -O ${vUSER}" &>>log)
 	fi
else
    echo "You chose Cancel."
	exit 1
fi


#Проверить соединение с базой данных
# psql "${vDBNAME}" -c "SELECT 1" > /dev/null &>>log
# exitstatus=$?
# if [ $exitstatus != 0 ]; then
# 	whiptail --title $TITLE --msgbox "Не удалось подключиться к ${vDBNAME}" 10 60
# 	exit 1
# fi

#распаковать вики
mkdir -p ~/../opt/wikijs
tar xzf wiki-js.tar.gz -C /opt/wikijs

#меняем конфиг файл wikijs
sudo sed "27 s/localhost/$vHOST/" /opt/wikijs/config.sample.yml > /opt/wikijs/config.yml
sudo sed -i "28 s/5432/$vPORT/" /opt/wikijs/config.yml
sudo sed -i "29 s/wikijs/$vUSER/" /opt/wikijs/config.yml
sudo sed -i "30 s/wikijsrocks/$vPASSWORD/" /opt/wikijs/config.yml
sudo sed -i "31 s/wiki/$vDBNAME/" /opt/wikijs/config.yml

# #проверить есть ли node
find /usr/local/bin -name node > /dev/null
var=$?
if [ $var = 0 ]; then
	#Устанавливаем ndoe
	sudo tar --strip-components 1 -xvf node-v14.16.0-linux-x64.tar.xz -C /usr/local > /dev/null
	echo installed
fi

#Создать файл для systemctl
echo "[Unit]
Description=Wiki.js
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/node server
Restart=always
User=root
Environment=NODE_ENV=production
WorkingDirectory=/opt/wikijs

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/wiki.service

#Добавить в автозагрузку
systemctl daemon-reload
systemctl start wiki
systemctl enable wiki

#добавить кофиг для Nginx
#Уточнить server_name
echo "server {
    server_name wiki.gisgis.ru; 
    listen 443 ssl http2;
    include /etc/nginx/sites-available/isogd-common;
    include /etc/nginx/sites-available/isogd-ssl;
    location / {
    proxy_pass http://localhost:3000/;
    }
}" >> /etc/nginx/sites-available/isogd
systemctl restart nginx
systemctl status wiki
sudo iptables -I INPUT -p tcp --dport 3000 -j ACCEPT