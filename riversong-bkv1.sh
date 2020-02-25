#!/bin/bash

#set -v on
#set -x on

# Procedura di backup di magrathea
# VERSIONE CON COMPRESSIONE 7zip

# 7z a -mx=9 back2.tar.7z back2.tar

dataoggi=`date +%Y-%m-%d_%H-%M-%S`

#backupslapd : saltare il backup di slapd
# 0 = NON FA BACKUP
# 1 = fa il backup
backupslapd=0

#backupopenfire : saltare il backup di openfire
# 0 = NON FA BACKUP
# 1 = fa il backup
backupopenfire=0

# logger -t RBCK "====== $dataoggi ===== STARTING MAGRATHEA BACKUP ====="

#$HOME/sendEmail/sendEmail -v -f root@imolug.org -t admin@imolug.org -u "=== $dataoggi === STARTING MAGRATHEA BACKUP ===" -o message-file=$HOME/script/message.email -o fqdn=www.imolug.org

# Check directory structure and build if is missing
if [ ! -d /backup/magrathea-bk-$dataoggi ]; then
        mkdir /backup/magrathea-bk-$dataoggi
        mkdir /backup/magrathea-bk-$dataoggi/ldap-backup
        mkdir /backup/magrathea-bk-$dataoggi/mysqldump
        mkdir /backup/magrathea-bk-$dataoggi/var
        mkdir /backup/magrathea-bk-$dataoggi/var/lib
		mkdir /backup/magrathea-bk-$dataoggi/var/log
		mkdir /backup/magrathea-bk-$dataoggi/root/
        mkdir /backup/magrathea-bk-$dataoggi/root/script
        mkdir /backup/magrathea-bk-$dataoggi/var/www
fi

echo "===== $dataoggi ===== STARTING MAGRATHEA BACKUP =====" | tee -a /tmp/backup-$dataoggi.log


# lancio drush per cancellare la cache di drupal dal DB
echo "Starting Drupal cache wiping..." | tee -a /tmp/backup-$dataoggi.log
cd /var/www/www.imolug.org
drush cc all 2>&1
cd
echo "Ending Drupal cache wiping..." | tee -a /tmp/backup-$dataoggi.log

# dump database di Drupal
#logger -t RBCK "Starting dump of Drupal Database"
echo "Starting dump of Drupal Database" | tee -a /tmp/backup-$dataoggi.log
# mysqldump -A --comments --dump-date --log-error=/backup/magrathea-bk-$dataoggi/mysqldump-$dataoggi.err -pmedia4_Rolex --routines -u root --result-file=/backup/magrathea-bk-$dataoggi/mysqldump/mysql-backup-$dataoggi.sql
mysqldump drupal --comments --dump-date --log-error=/backup/magrathea-bk-$dataoggi/mysqldump/drupal-dump-$dataoggi.err -pmedia4_Rolex --routines -u root --result-file=/backup/magrathea-bk-$dataoggi/mysqldump/drupal-$dataoggi.sql
rc=$?
if [ $rc = 0 ]; then
        #all ok
#       logger -t RBCK "Ending dump of Drupal Database"
        echo "Ending dump of Drupal Database" | tee -a /tmp/backup-$dataoggi.log
else
        #some error
#       logger -t RBCK "ERROR Dumping Drupal Database - Exit Code: $rc "
        echo "ERROR Dumping Drupal Database - Exit Code: $rc" | tee -a /tmp/backup-$dataoggi.log
        if [ -e /backup/magrathea-bk-$dataoggi/mysqldump/drupal-dump-$dataoggi.err ]; then
                #send mail with attachment
        att="/backup/magrathea-bk-$dataoggi/mysqldump/drupal-dump-$dataoggi.err"
                $HOME/script/sendEmail/sendEmail -v -f root@imolug.org -t admin@imolug.org -u "ERROR Dumping Drupal Database - Log File" -a $att -o message-file=$HOME/script/message.email -o fqdn=www.imolug.org
        fi
fi

# Copia dei file di configurazione da /etc e di quant'altro potrebbe servire

#logger -t RBCK "Starting Backup of /etc"
echo "Starting Backup of /etc" | tee -a /tmp/backup-$dataoggi.log
cp -r /etc /backup/magrathea-bk-$dataoggi
rc=$?
if [ $rc = 0 ]; then
#       logger -t RBCK "Ending Backup of /etc"
        echo "Ending Backup of /etc" | tee -a /tmp/backup-$dataoggi.log
else
#       logger -t RBCK "ERROR Backing up /etc - Exit Code: $rc"
        echo " ERROR Backing up /etc - Exit Code: $rc" | tee -a /tmp/backup-$dataoggi.log
fi

if [ $backupslapd = 1 ]; then
        # Export intero tree LDAP con slapcat
#       logger -t RBCK "Starting LDAP Export"
        echo "Starting LDAP Export" | tee -a /tmp/backup-$dataoggi.log
        slapcat > /backup/magrathea-bk-$dataoggi/ldap-backup/ldap-backup-$dataoggi.ldif
        rc=$?
        if [ $rc = 0 ]; then
#               logger -t RBCK "Ending LDAP Backup - All OK!"
                echo "Ending LDAP Backup - All Ok!" | tee -a /tmp/backup-$dataoggi.log
        else
#               logger -t RBCK "ERROR Exporting LDAP - Exit Code: $rc"
                echo "ERROR exporting LDAP - Exit Code: $rc"
        fi

#       logger -t RBCK "Starting Copying of /var/lib/ldap/*"
        echo "Starting Copying of /var/lib/ldap/*"  | tee -a /tmp/backup-$dataoggi.log
#       logger -t RBCK "Stopping slapd..."
        echo "Stopping slapd..." | tee -a /tmp/backup-$dataoggi.log
        /etc/init.d/slapd stop
        rc=$?
        if [ $rc = 0 ]; then
#               logger -t RBCK "...slapd stopped... Copying /var/lib/ldap/*"
                echo "...slapd stopped... Copying /var/lib/ldap/*" | tee -a /tmp/backup-$dataoggi.log
        #       tar cfz /backup/magrathea-bk/etc/ldap/var-lib-ldap-$dataoggi.tar.gz /var/lib/ldap/* 2>&1
        cp -r /var/lib/ldap /backup/magrathea-bk-$dataoggi/var/lib/ldap
                rc=$?
                if [ $rc = 0 ]; then
#                       logger -t RBCK "Ending Copying of /var/lib/ldap/*"
                        echo "Ending Copying of /var/lib/ldap/*" | tee -a /tmp/backup-$dataoggi.log
#                       logger -t RBCK "Restartign slapd..."
                        echo "Restarting slapd..." | tee -a /tmp/backup-$dataoggi.log
                        /etc/init.d/slapd start
                        rc=$?
                        if [ $rc = 0 ]; then
#                               logger -t RBCK "slapd restarted..."
                                echo "slapd restarted..." | tee -a /tmp/backup-$dataoggi.log
                        else
#                               logger -t RBCK "ERROR slapd not restarted - Exit Code: $rc"
                                echo "ERROR slapd not restarted - Exit Code: $rc" | tee -a /tmp/backup-$dataoggi.log
                                ## Send email to admin@imolug.org
                                $HOME/script/sendEmail/sendEmail -v -f root@imolug.org -t admin@imolug.org -u "ERROR slapd NOT RESTATED" -o message-file=$HOME/script/message.email -o fqdn=www.imolug.org
                        fi
                else
#                       logger -t RBCK "ERROR Compressing /var/lib/ldap/* - Exit Code: $rc"
                        echo "ERROR Copying /var/lib/ldap/* - Exit Code: $rc" | tee -a /tmp/backup-$dataoggi.log
#                       logger -t RBCK "Restarting slapd"
                        echo "Restarting slapd" | tee -a /tmp/backup-$dataoggi.log
                        /etc/init.d/slapd start
                        rc=$?
                        if [ $rc = 0 ]; then
#                               logger -t RBCK "slapd restarted"
                                echo "slapd restarted" | tee -a /tmp/backup-$dataoggi.log
                        else
#                               logger -t RBCK "ERROR slapd not restarted - Exit Code: $rc"
                                echo "ERROR slapd not restarted - Exit Code: $rc" | tee -a /tmp/backup-$dataoggi.log
                                $HOME/script/sendEmail/sendEmail -v -f root@imolug.org -t admin@imolug.org -u "ERROR slapd NOT RESTATED" -o message-file=$HOME/script/message.email -o fqdn=www.imolug.org
                        fi
                fi
        else
#               logger -t RBCK "ERROR slapd not stopped - Exit Code: $rc"
                echo "ERROR slapd not stopped - Exit Code: $rc" | tee -a /tmp/backup-$dataoggi.log
                $HOME/script/sendEmail/sendEmail -v -f root@imolug.org -t admin@imolug.org -u "ERROR slapd NOT STOPPED" -o message-file=$HOME/script/message.email -o fqdn=www.imolug.org
        fi
fi

if [ $backupopenfire = 1 ]; then
#       logger -t RBCK "Starting dump of openfire Database"
        echo "Starting dump of openfire Database" | tee -a /tmp/backup-$dataoggi.log
        # mysqldump -A --comments --dump-date --log-error=/backup/magrathea-bk-$dataoggi/mysqldump-$dataoggi.err -pmedia4_Rolex --routines -u root --result-file=/backup/magrathea-bk-$dataoggi/mysqldump/mysql-backup-$dataoggi.sql
        mysqldump openfire --comments --dump-date --log-error=/backup/magrathea-bk-$dataoggi/mysqldump/openfire-dump-$dataoggi.err -pmedia4_Rolex --routines -u root --result-file=/backup/magrathea-bk-$dataoggi/mysqldump/openfire-$dataoggi.sql
        rc=$?
        if [ $rc = 0 ]; then
                #all ok
#               logger -t RBCK "Ending dump of openfire Database"
                echo "Ending dump of openfire Databse" | tee -a /tmp/backup-$dataoggi.log
        else
                #some error
#               logger -t RBCK "ERROR Dumping openfire Database - Exit Code: $rc "
                echo "ERROR Dumping openfire Database - Exit Code: $rc" | tee -a /tmp/backup-$dataoggi.log
                if [ -e /backup/magrathea-bk-$dataoggi/mysqldump/openfire-dump-$dataoggi.err ]; then
                        #send mail with attachment
                        att="/backup/magrathea-bk-$dataoggi/openfire-dump-$dataoggi.err"
                        $HOME/script/sendEmail/sendEmail -v -f root@imolug.org -t admin@imolug.org -u "ERROR Dumping openfire Database - Log File" -a $att -o message-file=$HOME/script/message.email -o fqdn=www.imolug.org
                fi
        fi
fi

# Copia di altri file

# Script da root (servono anche per cron ! )
#logger -t RBCK "Starting Copying of /root/script/*"
echo "Starting Copying of /root/script/*" | tee -a /tmp/backup-$dataoggi.log
#tar cfz /backup/magrathea-bk/root_script/root-script-$dataoggi.tar.gz /root/script/* 2>&1
cp -r /root/script /backup/magrathea-bk-$dataoggi/root/
rc=$?
if [ $rc = 0 ]; then
#       logger -t RBCK "Ending Copying of /root/script/*"
        echo "Ending Copying of /root/script/*" | tee -a /tmp/backup-$dataoggi.log
else
#       logger -t RBCK "ERROR Copying /root/script/* - Exit Code: $rc"
        echo "ERROR Copying /root/script/* - Exit Code: $rc" | tee -a /tmp/backup-$dataoggi.log
fi

# /var - contiene www che contiene DRUPAL, BACKUP e UTILITY
#logger -t RBCK "Starting Copying of /var/www/www.imolug.org/*"
echo "Starting Copying of /var/www/www.imolug.org/*"
#tar cfz /backup/magrathea-bk/var/www/drupal-$dataoggi.tar.gz /var/www/drupal/* 2>&1
cp -r /var/www/www.imolug.org /backup/magrathea-bk-$dataoggi/var/www/
rc=$?
if [ $rc = 0 ]; then
#       logger -t RBCK "Ending Copying of /var/www/www.imolug.org/*"
        echo "Ending Copying of /var/www/www.imolug.org/*" | tee -a /tmp/backup-$dataoggi.log
else
#       logger -t RBCK "ERROR Copying /var/www/www.imolug.org/* - Exit Code: $rc"
        echo "ERROR Copying /var/www/www.imolug.org/*" | tee -a /tmp/backup-$dataoggi.log
fi

#logger -t RBCK "Starting Copying of /var/www/utilty.imolug.org/*"
echo "Starting Copying of /var/www/utility.imolug.org/*" | tee -a /tmp/backup-$dataoggi.log
# tar cfz /backup/magrathea-bk/var/www/utlity-$dataoggi.tar.gz /var/www/utility.imolug.org/* 2>&1
cp -r /var/www/utility.imolug.org /backup/magrathea-bk-$dataoggi/var/www
rc=$?
if [ $rc = 0 ]; then
#       logger -t RBCK "Ending Copying of /var/www/utility.imolug.org/*"
        echo "Ending Copying of /var/www/utility.imolug.org/*" | tee -a /tmp/backup-$dataoggi.log
else
#       logger -t RBCK "ERROR Copying /var/www/utility.imolug.org/* - Exit Code: $rc"
        echo "ERROR Copying /var/www/utility.imolug.org/* - Exit Code: $rc" | tee -a /tmp/backup-$dataoggi.log
fi

echo "Starting Copying of /var/log/*" | tee -a /tmp/backup-$dataoggi.log
# tar cfz /backup/magrathea-bk/var/www/utlity-$dataoggi.tar.gz /var/www/utility.imolug.org/* 2>&1
cp -r /var/log /backup/magrathea-bk-$dataoggi/var/log
rc=$?
if [ $rc = 0 ]; then
#       logger -t RBCK "Ending Copying of /var/log/*"
        echo "Ending Copying of /var/log/*" | tee -a /tmp/backup-$dataoggi.log
		else
#       logger -t RBCK "ERROR Copying /var/log/* - Exit Code: $rc"
        echo "ERROR Copying /var/log/* - Exit Code: $rc" | tee -a /tmp/backup-$dataoggi.log
fi

# comprimo la cartella backup che contiene tutti i vari backup giornalieri
#logger -t RBCK "Starting Compression of daily Backup on /backup/magrathea-bk-$dataoggi/*"
echo "Starting Compression of daily Backup on /backup/magrathea-bk-$dataoggi/*" | tee -a /tmp/backup-$dataoggi.log
tar cfz /backup/magrathea-bk-$dataoggi.tar.gz /backup/magrathea-bk-$dataoggi/* 2>&1
rc=$?
if [ $rc = 0 ]; then
#       logger -t RBCK "Ending Compression of daily Backup"
        echo "Ending Compression of daily Backup" | tee -a /tmp/backup-$dataoggi.log
else
#       logger -t RBCK "ERROR Compressing daily Backup on /backup/magrathea-bk-$dataoggi/* - Exit Code: $rc"
        echo "ERROR Copmpressing daily Backup on /backup/magrathea-bk-$dataoggi/* - Exit Code: $rc" | tee -a /tmp/backup-$dataoggi.log
fi

# creo l' hash SHA256 del file compresso
#logger -t RBCK "Creating HASH file of daily backup..."
echo "Crating HASH file of daily backup..." | tee -a /tmp/backup-$dataoggi.log
#logger -t RBCK "... SHA256 ..."
echo "... SHA256 ..." | tee -a /tmp/backup-$dataoggi.log
sha256sum -b /backup/magrathea-bk-$dataoggi.tar.gz > /backup/magrathea-bk-$dataoggi.sha256
rc=$?
if [ $rc = 0 ]; then
#       logger -t RBCK "... SHA256 OK! ..."
        echo "... SHA256 OK! ..." | tee -a /tmp/backup-$dataoggi.log
else
#       logger -t RBCK "... SHA256 ERROR ... - Exit Code: $rc"
        echo "... SHA256 ERROR ... - Exit Code: $rc" | tee -a /tmp/backup-$dataoggi.log
fi

# creo dir con data del backup su server remoto
#logger -t RBCK "Creating remote dir..."
echo "Creating remote dir..." | tee -a /tmp/backup-$dataoggi.log
ssh pari5657@paridebalestri.net "mkdir magrathea-bk/$dataoggi"
rc=$?
if [ $rc = 0 ]; then
#       logger -t RBCK "Remote dir created"
        echo "Remote dir created" | tee -a /tmp/backup-$dataoggi.log
else
#       logger -t RBCK "ERROR creating remote dir - Exit Code: $rc"
        echo "ERROR creating remote dir - Exit Code: $rc" | tee -a /tmp/backup-$dataoggi.log
fi

# copio il backup via ssh su server remoto
#logger -t RBCK "Starting copy of backup on remote host..."
echo "Starting copy of backup on remote host..." | tee -a /tmp/backup-$dataoggi.log
#logger -t RBCK "... Compressed Backup ..."
echo "... Compressed Backup ..." | tee -a /tmp/backup-$dataoggi.log
scp /backup/magrathea-bk-$dataoggi.tar.gz pari5657@paridebalestri.net:magrathea-bk/$dataoggi
rc=$?
if [ $rc = 0 ]; then
#       logger -t RBCK "... Compressed Backup OK ..."
        echo "... Compressed Backup OK ..." | tee -a /tmp/backup-$dataoggi.log
else
#       logger -t RBCK "... ERROR Copying Compressed Backup - Exit Code: $rc"
        echo "... ERROR Copying Compressed Backup - Exit Code: $rc" | tee -a /tmp/backup-$dataoggi.log
fi

#logger -t RBCK "... HASH SHA256 ..."
echo "... HASH SHA256 ..." | tee -a /tmp/backup-$dataoggi.log
scp /backup/magrathea-bk-$dataoggi.sha256 pari5657@paridebalestri.net:magrathea-bk/$dataoggi
rc=$?
if [ $rc = 0 ]; then
#       logger -t RBCK "... HASH SHA256 OK ..."
        echo "... HASH SHA256 OK ..." | tee -a /tmp/backup-$dataoggi.log
else
#       logger -t RBCK "... ERROR Copying HASH SHA256 - Exit Code: $rc"
        echo "... ERROR Copying HASH SHA256 - Exit Code: $rc" | tee -a /tmp/backup-$dataoggi.log
fi

# copio backup via rsync
#logger -t RBCK "Starting rsync of backup..."
#echo "Starting rsync of backup..." | tee -a /tmp/backup-$dataoggi.log
#rsync -avuz --compress --progress --password-file /root/pwd_rsync /backup/magrathea-bk-$dataoggi.tar.gz netbackup@paridecasa78.dyndns.org::NetBackup 2>&1
#rc=$?
#if [ $rc = 0 ]; then
#       logger -t RBCK "Ending rsync..."
#        echo "Ending rsync..." | tee -a /tmp/backup-$dataoggi.log
#else
#       logger -t RBCK "... ERROR Rsyncing Backup - Exit Code: $rc"
#        echo "... ERROR Rsyncing Backup - Exit Code: $rc" | tee -a /tmp/backup-$dataoggi.log
#fi

##### Modifica del 02.04.2013 - Introduzione backup con Google Cloud Storage ##########
# copio backup nel Dropbox
#logger -t RBCK "Starting copy to Dropbox"
#cp /backup/magrathea-bk-$dataoggi.tar.gz $HOME/Dropbox
#rc=$?
#if [ $rc = 0 ]; then
#       logger -t RBCK "Ending copy to Dropbox..."
#       logger -t RBCK "Starting Dropbox sync"
#else
#       logger -t RBCK "... ERROR Copying to Dropbox - Exit Code: $rc"
#fi
#
#for (( c=1; c<=100; c++ ))
#do
#    rc=$(/root/dropbox.py status 2>&1)
#    if [ $rc="Idle" ]; then
#        logger -t RBCK "Ending Dropbox sync..."
#               break
#    fi
#       logger -t RBCK "Waiting Dropbox to be synced.... pausing $pausatempo seconds"
#       sleep $pausatempo
#
#done

# copio backup nel dropbox con nuovo script https://github.com/andreafabrizi/Dropbox-Uploader
#$HOME/script/dropbox_script/dropbox_uploader.sh upload /backup/magrathea-bk-$dataoggi.tar.gz
#rc=$?
#if [ $rc = 0 ];then
#       logger -t RBCK "Ending Dropbox upload..."
#else
#       logger -t RBCK "... ERROR Uploading to Dropbox - Exit Code: $rc"
#fi

### Copia dei file su Google Cloud Storage nel bucket Nearline (EU) gcs://imolug-backup

#logger -t RBCK "Starting Google Cloud Storage Backup..."
echo "Starting Google Cloud Storage Backup..." | tee -a /tmp/backup-$dataoggi.log
gsutil cp /backup/magrathea-bk-$dataoggi.tar.gz gs://imolug-backup/
rc=$?
if [ $rc = 0 ]; then
#       logger -t RBCK "Ending Google Cloud Storage Backup..."
        echo "Ending Google Cloud Storage Backup..." | tee -a /tmp/backup-$dataoggi.log
else
#       logger -t RBCK "... ERROR uploading to GCS - Exit Code: $rc"
        echo "... ERROR uploading to GCS - Exit Code: $rc" | tee -a /tmp/backup-$dataoggi.log
fi


#logger -t RBCK "Staring directory Wiping..."
echo "Starting directory Wiping..." | tee -a /tmp/backup-$dataoggi.log
rm -r /backup/*
rc=$?
if [ $rc = 0 ]; then
#        logger -t RBCK "Ending directory wiping..."
        echo "Ending directory wiping..." | tee -a /tmp/backup-$dataoggi.log
else
#        logger -t RBCK "... ERROR Wiping directory - Exit Code: $rc"
        echo "... ERROR Wiping directory - Exit Code: $rc" | tee -a /tmp/backup-$dataoggi.log
fi

#logger -t RBCK "====== $dataoggi ===== ENDING MAGRATHEA BACKUP ====="

#popolo la variabile dataend per vedere quanto il backup finisce veramente
dataend=`date +%Y-%m-%d_%H-%M-%S`

echo "====== $dataend ===== ENDING MAGRATHEA BACKUP =====" | tee -a /tmp/backup-$dataoggi.log
#$HOME/script/sendEmail/sendEmail -v -f root@imolug.org -t admin@imolug.org -u "=== $dataoggi === ENDING MAGRATHEA BACKUP ===" -o message-file=$HOME/script/message.email -o fqdn=www.imolug.org
$HOME/script/sendEmail/sendEmail -v -f root@imolug.org -t admin@imolug.org -u "=== $dataend === ENDING MAGRATHEA BACKUP ===" -o message-file=/tmp/backup-$dataoggi.log -o fqdn=www.imolug.org -o tls=no
#set -v off
#set -x off
