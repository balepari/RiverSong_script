#!/bin/bash

# Procedura di backup di magrathea
# VERSIONE CON COMPRESSIONE 7zip

# 7z a -mx=9 back2.tar.7z back2.tar

dataoggi=`date +%Y-%m-%d_%H-%M-%S`

servername=`riversong`

yesupload=0

wipeall=0

# Check directory structure and build if is missing
if [ ! -d /backup/$servername-bk-$dataoggi ]; then
        mkdir /backup/$servername-bk-$dataoggi
        mkdir /backup/$servername-bk-$dataoggi/mysqldump
        mkdir /backup/$servername-bk-$dataoggi/var
        mkdir /backup/$servername-bk-$dataoggi/var/lib
	mkdir /backup/$servername-bk-$dataoggi/var/log
	mkdir /backup/$servername-bk-$dataoggi/root/
        mkdir /backup/$servername-bk-$dataoggi/root/script
        mkdir /backup/$servername-bk-$dataoggi/var/www
fi

echo "===== $dataoggi ===== STARTING $servername BACKUP =====" | tee -a /tmp/backup-$dataoggi.log

# dump database
echo "Starting dump of owncloud mysql Database" | tee -a /tmp/backup-$dataoggi.log
mysqldump owncloud --comments --dump-date --log-error=/backup/$servername-bk-$dataoggi/mysqldump/mysql-dump-$dataoggi.err -pFoccalabindella69.. --routines -u root --result-file=/backup/$servername-bk-$dataoggi/mysqldump/owncloud-$dataoggi.sql
rc=$?
if [ $rc = 0 ]; then
        #all ok
        echo "Ending dump of owncloud mysql Database" | tee -a /tmp/backup-$dataoggi.log
else
        echo "ERROR Dumping owncloud mysql Database - Exit Code: $rc" | tee -a /tmp/backup-$dataoggi.log
        if [ -e /backup/$servername-bk-$dataoggi/mysqldump/owncloud-dump-$dataoggi.err ]; then
        #send mail with attachment
        att="/backup/$servername-bk-$dataoggi/mysqldump/owncloud-dump-$dataoggi.err"
                $HOME/script/sendEmail/sendEmail -v -f info@makerstation.it -t paridebalestri@gmail.com -u "ERROR Dumping owncloud mysql Database - Log File" -a $att -o message-file=$HOME/script/message.email -o fqdn=www.makerstation.it
        fi
fi

# Copia dei file di configurazione da /etc e di quant'altro potrebbe servire

echo "Starting Backup of /etc" | tee -a /tmp/backup-$dataoggi.log
cp -r /etc /backup/$servername-bk-$dataoggi
rc=$?
if [ $rc = 0 ]; then
        echo "Ending Backup of /etc" | tee -a /tmp/backup-$dataoggi.log
else
        echo " ERROR Backing up /etc - Exit Code: $rc" | tee -a /tmp/backup-$dataoggi.log
fi

# Copia di altri file

# Script da root (servono anche per cron ! )
echo "Starting Copying of /root/script/*" | tee -a /tmp/backup-$dataoggi.log
cp -r /root/script /backup/$servername-bk-$dataoggi/root/
rc=$?
if [ $rc = 0 ]; then
        echo "Ending Copying of /root/script/*" | tee -a /tmp/backup-$dataoggi.log
else
        echo "ERROR Copying /root/script/* - Exit Code: $rc" | tee -a /tmp/backup-$dataoggi.log
fi

# /var - contiene www che contiene html, owncloud e phpmyadmin
echo "Starting Copying of /var/www/html/*"
cp -r /var/www/html/* /backup/$servername-bk-$dataoggi/var/www/
rc=$?
if [ $rc = 0 ]; then
        echo "Ending Copying of /var/www/html/*" | tee -a /tmp/backup-$dataoggi.log
else
        echo "ERROR Copying /var/www/html/*" | tee -a /tmp/backup-$dataoggi.log
fi

echo "Starting Copying of /var/www/owncloud/config/*" | tee -a /tmp/backup-$dataoggi.log
cp -r /var/www/owcloud/config/* /backup/$servername-bk-$dataoggi/var/www/
rc=$?
if [ $rc = 0 ]; then
        echo "Ending Copying of /var/www/owncloud/config/*" | tee -a /tmp/backup-$dataoggi.log
else
        echo "ERROR Copying /var/www/owncloud/config/* - Exit Code: $rc" | tee -a /tmp/backup-$dataoggi.log
fi

echo "Starting Copying of /var/www/owncloud/data/*" | tee -a /tmp/backup-$dataoggi.log
cp -r /var/www/owcloud/data/* /backup/$servername-bk-$dataoggi/var/www/
rc=$?
if [ $rc = 0 ]; then
        echo "Ending Copying of /var/www/owncloud/data/*" | tee -a /tmp/backup-$dataoggi.log
else
        echo "ERROR Copying /var/www/owncloud/data/* - Exit Code: $rc" | tee -a /tmp/backup-$dataoggi.log
fi

echo "Starting Copying of /var/www/phpmyadmin/*" | tee -a /tmp/backup-$dataoggi.log
cp -r /var/www/phpmyadmin/* /backup/$servername-bk-$dataoggi/var/www/
rc=$?
if [ $rc = 0 ]; then
        echo "Ending Copying of /var/www/phpmyadmin/*" | tee -a /tmp/backup-$dataoggi.log
else
        echo "ERROR Copying /var/www/phpmyadmin/* - Exit Code: $rc" | tee -a /tmp/backup-$dataoggi.log
fi

echo "Starting Copying of /var/log/*" | tee -a /tmp/backup-$dataoggi.log
cp -r /var/log /backup/$servername-bk-$dataoggi/var/log
rc=$?
if [ $rc = 0 ]; then
        echo "Ending Copying of /var/log/*" | tee -a /tmp/backup-$dataoggi.log
else
        echo "ERROR Copying /var/log/* - Exit Code: $rc" | tee -a /tmp/backup-$dataoggi.log
fi

# comprimo la cartella backup che contiene tutti i vari backup giornalieri
echo "Starting Compression of daily Backup on /backup/$servername-bk-$dataoggi/*" | tee -a /tmp/backup-$dataoggi.log
tar cfz /backup/$servername-bk-$dataoggi.tar.gz /backup/$servername-bk-$dataoggi/* 2>&1
rc=$?
if [ $rc = 0 ]; then
        echo "Ending Compression of daily Backup" | tee -a /tmp/backup-$dataoggi.log
else
        echo "ERROR Compressing daily Backup on /backup/$servername-bk-$dataoggi/* - Exit Code: $rc" | tee -a /tmp/backup-$dataoggi.log
fi

# creo l' hash SHA256 del file compresso
echo "Crating HASH file of daily backup..." | tee -a /tmp/backup-$dataoggi.log
echo "... SHA256 ..." | tee -a /tmp/backup-$dataoggi.log
sha256sum -b /backup/$servername-bk-$dataoggi.tar.gz > /backup/$servername-bk-$dataoggi.sha256
rc=$?
if [ $rc = 0 ]; then
        echo "... SHA256 OK! ..." | tee -a /tmp/backup-$dataoggi.log
else
        echo "... SHA256 ERROR ... - Exit Code: $rc" | tee -a /tmp/backup-$dataoggi.log
fi

if [ $yesupload = 1 ]; then
        ### Copia dei file su Google Cloud Storage nel bucket Nearline (EU) gcs://imolug-backup

        echo "Starting Google Cloud Storage Backup..." | tee -a /tmp/backup-$dataoggi.log
        gsutil cp /backup/$servername-bk-$dataoggi.tar.gz gs://imolug-backup/
        rc=$?
        if [ $rc = 0 ]; then
                echo "Ending Google Cloud Storage Backup..." | tee -a /tmp/backup-$dataoggi.log
        else
                echo "... ERROR uploading to GCS - Exit Code: $rc" | tee -a /tmp/backup-$dataoggi.log
        fi
fi

if [ $wipeall = 1 ]; then
        echo "Starting directory Wiping..." | tee -a /tmp/backup-$dataoggi.log
        rm -r /backup/*
        rc=$?
        if [ $rc = 0 ]; then
                echo "Ending directory wiping..." | tee -a /tmp/backup-$dataoggi.log
        else
                echo "... ERROR Wiping directory - Exit Code: $rc" | tee -a /tmp/backup-$dataoggi.log
        fi
fi

#popolo la variabile dataend per vedere quanto il backup finisce veramente
dataend=`date +%Y-%m-%d_%H-%M-%S`

echo "====== $dataend ===== ENDING $servername BACKUP =====" | tee -a /tmp/backup-$dataoggi.log
$HOME/script/sendEmail/sendEmail -v -f info@makerstation.it -t paridebalestri@gmail.com -u "=== $dataend === ENDING $servername BACKUP ===" -o message-file=/tmp/backup-$dataoggi.log -o fqdn=www.makerstation.it -o tls=no
