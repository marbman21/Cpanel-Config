#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
CWD="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DOMAIN=linode.com
USERNAME=linode
EMAIL=username@example.com
PASSWORD=test123456
HOSTNAME=host.linode.com
SSH_PORT=2202
PASSV_PORT="49152:65534";
PASSV_MIN=$(echo $PASSV_PORT | cut -d':' -f1)
PASSV_MAX=$(echo $PASSV_PORT | cut -d':' -f2)
ISVPS=$(((dmidecode -t system 2>/dev/null | grep "Manufacturer" | grep -i 'VMware\|KVM\|Bochs\|Virtual\|HVM' > /dev/null) || [ -f /proc/vz/veinfo ]) && echo "SI" || echo "NO")

echo "########  #### ##    ##    ###    ########     #### ########"
echo "##     ##  ##   ##  ##    ## ##   ##     ##     ##     ##"    
echo "##     ##  ##    ####    ##   ##  ##     ##     ##     ##"   
echo "##     ##  ##     ##    ##     ## ########      ##     ##"   
echo "##     ##  ##     ##    ######### ##   ##       ##     ##"   
echo "##     ##  ##     ##    ##     ## ##    ##      ##     ##"   
echo "########  ####    ##    ##     ## ##     ##    ####    ##"   

echo ""
echo "             ####################### cPanel Configurator #######################              "
echo ""
echo ""

if [ ! -f /etc/redhat-release ]; then
	echo "CentOS was not detected. Aborting"
	exit 0
fi

echo "This script installs and pre-configures cPanel (CTRL + C to cancel)"
sleep 10

echo "####### SETTING CENTOS #######"
wget https://raw.githubusercontent.com/marbman21/Centos-Config/master/configure_centos.sh -O "$CWD/configure_centos.sh" && bash "$CWD/configure_centos.sh"

echo "####### CPANEL PRE-CONFIGURATION ##########"
echo "Disabling yum-cron..."
yum erase yum-cron -y

echo "####### SETTING HOSTNAME TO $HOSTNAME ##########"
hostname $HOSTNAME

systemctl stop NetworkManager.service
systemctl disable NetworkManager.service
yum erase NetworkManager -y

echo "######### CONFIGURING DNS AND NETWORK ########"
NETWORK=$(route -n | awk '$1 == "0.0.0.0" {print $8}')
ETHCFG="/etc/sysconfig/network-scripts/ifcfg-$NETWORK"

sed -i '/^NM_CONTROLLED=.*/d' $ETHCFG
sed -i '/^DNS1=.*/d' $ETHCFG
sed -i '/^DNS2=.*/d' $ETHCFG
	
echo "Configuring network..."
echo "PEERDNS=no" >> $ETHCFG
echo "NM_CONTROLLED=no" >> $ETHCFG
echo "DNS1=127.0.0.1" >> $ETHCFG
echo "DNS2=8.8.8.8" >> $ETHCFG

echo "Rewriting /etc/resolv.conf..."

echo "options timeout:5 attempts:2" > /etc/resolv.conf
echo "nameserver 127.0.0.1" >> /etc/resolv.conf # local
echo "nameserver 208.67.222.222" >> /etc/resolv.conf # OpenDNS
echo "nameserver 8.20.247.20" >> /etc/resolv.conf # Comodo
echo "nameserver 8.8.8.8" >> /etc/resolv.conf # Google
echo "nameserver 199.85.126.10" >> /etc/resolv.conf # Norton
echo "nameserver 8.26.56.26" >> /etc/resolv.conf # Comodo
echo "nameserver 209.244.0.3" >> /etc/resolv.conf # Level3
echo "nameserver 8.8.4.4" >> /etc/resolv.conf # Google
echo "######### END CONFIGURING DNS AND NETWORK ########"

echo "####### INSTALLING CPANEL #######"
if [ -f /usr/local/cpanel/cpanel ]; then
        echo "cPanel already detected, not installed, only configured (CTRL + C to cancel)"
        sleep 10
else
	hostname -f > /root/hostname

        cd /home && curl -o latest -L https://securedownloads.cpanel.net/latest && sh latest --skip-cloudlinux
	
		echo "Waiting 5 minutes for you to finish installing remaining packages in the background to continue ..."
	        sleep 300
		
	whmapi1 sethostname hostname=$(cat /root/hostname) # Fix hostname change by cprapid.com cpanel v90 https://docs.cpanel.net/knowledge-base/dns/automatically-issued-hostnames/
	hostnamectl set-hostname $(cat /root/hostname)
	rm -f /root/hostname
fi
echo "####### END INSTALLING CPANEL #######"

whmapi1 sethostname hostname=$(cat /root/hostname) # Fix hostname change by cprapid.com cpanel v90 https://docs.cpanel.net/knowledge-base/dns/automatically-issued-hostnames/
hostnamectl set-hostname $(cat /root/hostname)
rm -f /root/hostname

echo "####### SETTING ConfigServer Explorer #######"
if [ ! -d /etc/csf ]; then
        echo "csf not detected, downloading!"
	touch /etc/sysconfig/iptables
	touch /etc/sysconfig/iptables6
	systemctl start iptables
	systemctl start ip6tables
	systemctl enable iptables
	systemctl enable ip6tables
	cd /root && rm -f ./csf.tgz; wget https://download.configserver.com/csf.tgz && tar xvfz ./csf.tgz && cd ./csf && sh ./install.sh
fi

        echo "ConfigServer Explorer (cse) not detected, downloading!"
	cd /usr/src
	rm -fv /usr/src/cse.tgz
	wget https://download.configserver.com/cse.tgz
	tar -xzf cse.tgz
	cd cse
	sh install.sh
	rm -Rfv /usr/src/cse*
	
	echo "ConfigServer ModSecurity Control (cmc) not detected, downloading!"
	cd /usr/src
	rm -fv /usr/src/cmc.tgz
	wget http://download.configserver.com/cmc.tgz
	tar -xzf cmc.tgz
	cd cmc
	sh install.sh
	rm -Rfv /usr/src/cmc*
	
	echo "Softaculous not detected, downloading!"
	cd /usr/src
	wget -N http://files.softaculous.com/install.sh
	chmod 755 install.sh
	./install.sh
	
	echo "R-fx Malware Detect not detected, downloading!"	
	cd /usr/src
	wget https://www.rfxn.com/downloads/maldetect-current.tar.gz
	tar -xzf maldetect-*.tar.gz
	rm -rf maldetect-*.tar.gz
	cd maldetect*
	sh install.sh
	
echo -e "\e[1;36;40m Enabling auto quarantine in maldet configuration \e[0m"
sed -i 's/quarantine_hits="0"/quarantine_hits="1"/g' /usr/local/maldetect/conf.maldet

echo "Changing SSH portdefault 22 a $SSH_PORT..."
sed -i "s/^\(#\|\)Port.*/Port $SSH_PORT/" /etc/ssh/sshd_config

echo " Setting CSF..."
yum remove firewalld -y
yum -y install iptables-services wget perl unzip net-tools perl-libwww-perl perl-LWP-Protocol-https perl-GDGraph

sed -i 's/^TESTING = .*/TESTING = "0"/g' /etc/csf/csf.conf
sed -i 's/^ICMP_IN = .*/ICMP_IN = "0"/g' /etc/csf/csf.conf
sed -i 's/^IPV6 = .*/IPV6 = "0"/g' /etc/csf/csf.conf
sed -i 's/^DENY_IP_LIMIT = .*/DENY_IP_LIMIT = "400"/g' /etc/csf/csf.conf
sed -i 's/^SAFECHAINUPDATE = .*/SAFECHAINUPDATE = "1"/g' /etc/csf/csf.conf
sed -i 's/^CC_DENY = .*/CC_DENY = ""/g' /etc/csf/csf.conf
sed -i 's/^CC_IGNORE = .*/CC_IGNORE = ""/g' /etc/csf/csf.conf
sed -i 's/^SMTP_BLOCK = .*/SMTP_BLOCK = "1"/g' /etc/csf/csf.conf
sed -i 's/^LF_FTPD = .*/LF_FTPD = "30"/g' /etc/csf/csf.conf
sed -i 's/^LF_SMTPAUTH = .*/LF_SMTPAUTH = "90"/g' /etc/csf/csf.conf
sed -i 's/^LF_EXIMSYNTAX = .*/LF_EXIMSYNTAX = "0"/g' /etc/csf/csf.conf
sed -i 's/^LF_POP3D = .*/LF_POP3D = "100"/g' /etc/csf/csf.conf
sed -i 's/^LF_IMAPD = .*/LF_IMAPD = "100"/g' /etc/csf/csf.conf
sed -i 's/^LF_HTACCESS = .*/LF_HTACCESS = "40"/g' /etc/csf/csf.conf
sed -i 's/^LF_CPANEL = .*/LF_CPANEL = "40"/g' /etc/csf/csf.conf
sed -i 's/^LF_MODSEC = .*/LF_MODSEC = "100"/g' /etc/csf/csf.conf
sed -i 's/^LF_CXS = .*/LF_CXS = "10"/g' /etc/csf/csf.conf
sed -i 's/^LT_POP3D =  .*/LT_POP3D = "180"/g' /etc/csf/csf.conf
sed -i 's/^CT_SKIP_TIME_WAIT = .*/CT_SKIP_TIME_WAIT = "1"/g' /etc/csf/csf.conf
sed -i 's/^PT_LIMIT = .*/PT_LIMIT = "0"/g' /etc/csf/csf.conf
sed -i 's/^ST_MYSQL = .*/ST_MYSQL = "1"/g' /etc/csf/csf.conf
sed -i 's/^ST_APACHE = .*/ST_APACHE = "1"/g' /etc/csf/csf.conf
sed -i 's/^CONNLIMIT = .*/CONNLIMIT = "80;70,110;50,993;50,143;50,25;30"/g' /etc/csf/csf.conf
sed -i 's/^LF_PERMBLOCK_INTERVAL = .*/LF_PERMBLOCK_INTERVAL = "14400"/g' /etc/csf/csf.conf
sed -i 's/^LF_INTERVAL = .*/LF_INTERVAL = "900"/g' /etc/csf/csf.conf
sed -i 's/^PS_INTERVAL = .*/PS_INTERVAL = "60"/g' /etc/csf/csf.conf
sed -i 's/^PS_LIMIT = .*/PS_LIMIT = "60"/g' /etc/csf/csf.conf

echo "Disabling alerts..."

sed -i 's/^LF_PERMBLOCK_ALERT = .*/LF_PERMBLOCK_ALERT = "0"/g' /etc/csf/csf.conf
sed -i 's/^LF_NETBLOCK_ALERT = .*/LF_NETBLOCK_ALERT = "0"/g' /etc/csf/csf.conf
sed -i 's/^LF_EMAIL_ALERT = .*/LF_EMAIL_ALERT = "0"/g' /etc/csf/csf.conf
sed -i 's/^LF_CPANEL_ALERT = .*/LF_CPANEL_ALERT = "0"/g' /etc/csf/csf.conf
sed -i 's/^LF_QUEUE_ALERT = .*/LF_QUEUE_ALERT = "0"/g' /etc/csf/csf.conf
sed -i 's/^LF_DISTFTP_ALERT = .*/LF_DISTFTP_ALERT = "0"/g' /etc/csf/csf.conf
sed -i 's/^LF_DISTSMTP_ALERT = .*/LF_DISTSMTP_ALERT = "0"/g' /etc/csf/csf.conf
sed -i 's/^LT_EMAIL_ALERT = .*/LT_EMAIL_ALERT = "0"/g' /etc/csf/csf.conf
sed -i 's/^RT_RELAY_ALERT = .*/RT_RELAY_ALERT = "0"/g' /etc/csf/csf.conf
sed -i 's/^RT_AUTHRELAY_ALERT = .*/RT_AUTHRELAY_ALERT = "0"/g' /etc/csf/csf.conf
sed -i 's/^RT_POPRELAY_ALERT = .*/RT_POPRELAY_ALERT = "0"/g' /etc/csf/csf.conf
sed -i 's/^RT_LOCALRELAY_ALERT = .*/RT_LOCALRELAY_ALERT = "0"/g' /etc/csf/csf.conf
sed -i 's/^RT_LOCALHOSTRELAY_ALERT = .*/RT_LOCALHOSTRELAY_ALERT = "0"/g' /etc/csf/csf.conf
sed -i 's/^CT_EMAIL_ALERT = .*/CT_EMAIL_ALERT = "0"/g' /etc/csf/csf.conf
sed -i 's/^PT_USERKILL_ALERT = .*/PT_USERKILL_ALERT = "0"/g' /etc/csf/csf.conf
sed -i 's/^PS_EMAIL_ALERT = .*/PS_EMAIL_ALERT = "0"/g' /etc/csf/csf.conf
sed -i 's/^PT_USERMEM = .*/PT_USERMEM = "0"/g' /etc/csf/csf.conf
sed -i 's/^PT_USERTIME = .*/PT_USERTIME = "0"/g' /etc/csf/csf.conf
sed -i 's/^PT_USERPROC = .*/PT_USERPROC = "0"/g' /etc/csf/csf.conf
sed -i 's/^PT_USERRSS = .*/PT_USERRSS = "0"/g' /etc/csf/csf.conf

echo "Activating ssh port ..."
# IPv4
CURR_CSF_IN=$(grep "^TCP_IN" /etc/csf/csf.conf | cut -d'=' -f2 | sed 's/\ //g' | sed 's/\"//g' | sed "s/,$PASSV_PORT,/,/g" | sed "s/,$PASSV_PORT//g" | sed "s/$PASSV_PORT,//g" | sed "s/,,//g")
sed -i "s/^TCP_IN.*/TCP_IN = \"$CURR_CSF_IN,$SSH_PORT\"/" /etc/csf/csf.conf

echo "Activating passive FTP range ..."
# IPv4
CURR_CSF_IN=$(grep "^TCP_IN" /etc/csf/csf.conf | cut -d'=' -f2 | sed 's/\ //g' | sed 's/\"//g' | sed "s/,$PASSV_PORT,/,/g" | sed "s/,$PASSV_PORT//g" | sed "s/$PASSV_PORT,//g" | sed "s/,,//g")
sed -i "s/^TCP_IN.*/TCP_IN = \"$CURR_CSF_IN,$PASSV_PORT\"/" /etc/csf/csf.conf

CURR_CSF_OUT=$(grep "^TCP_OUT" /etc/csf/csf.conf | cut -d'=' -f2 | sed 's/\ //g' | sed 's/\"//g' | sed "s/,$PASSV_PORT,/,/g" | sed "s/,$PASSV_PORT//g" | sed "s/$PASSV_PORT,//g" | sed "s/,,//g")
sed -i "s/^TCP_OUT.*/TCP_OUT = \"$CURR_CSF_OUT,$PASSV_PORT\"/" /etc/csf/csf.conf

# IPv6
CURR_CSF_IN6=$(grep "^TCP6_IN" /etc/csf/csf.conf | cut -d'=' -f2 | sed 's/\ //g' | sed 's/\"//g' | sed "s/,$PASSV_PORT,/,/g" | sed "s/,$PASSV_PORT//g" | sed "s/$PASSV_PORT,//g" | sed "s/,,//g")
sed -i "s/^TCP6_IN.*/TCP6_IN = \"$CURR_CSF_IN6,$PASSV_PORT\"/" /etc/csf/csf.conf

CURR_CSF_OUT6=$(grep "^TCP6_OUT" /etc/csf/csf.conf | cut -d'=' -f2 | sed 's/\ //g' | sed 's/\"//g' | sed "s/,$PASSV_PORT,/,/g" | sed "s/,$PASSV_PORT//g" | sed "s/$PASSV_PORT,//g" | sed "s/,,//g")
sed -i "s/^TCP6_OUT.*/TCP6_OUT = \"$CURR_CSF_OUT6,$PASSV_PORT\"/" /etc/csf/csf.conf

echo "Enabling blacklists..."
sed -i '/^#SPAMDROP/s/^#//' /etc/csf/csf.blocklists
sed -i '/^#SPAMEDROP/s/^#//' /etc/csf/csf.blocklists
sed -i '/^#DSHIELD/s/^#//' /etc/csf/csf.blocklists
sed -i '/^#HONEYPOT/s/^#//' /etc/csf/csf.blocklists
#sed -i '/^#MAXMIND/s/^#//' /etc/csf/csf.blocklists #FALSE POSITIVES
sed -i '/^#BDE|/s/^#//' /etc/csf/csf.blocklists

sed -i '/^SPAMDROP/s/|0|/|300|/' /etc/csf/csf.blocklists
sed -i '/^SPAMEDROP/s/|0|/|300|/' /etc/csf/csf.blocklists
sed -i '/^DSHIELD/s/|0|/|300|/' /etc/csf/csf.blocklists
sed -i '/^HONEYPOT/s/|0|/|300|/' /etc/csf/csf.blocklists
#sed -i '/^MAXMIND/s/|0|/|300|/' /etc/csf/csf.blocklists #FALSE POSITIVES
sed -i '/^BDE|/s/|0|/|300|/' /etc/csf/csf.blocklists

sed -i '/^TOR/s/^TOR/#TOR/' /etc/csf/csf.blocklists
sed -i '/^ALTTOR/s/^ALTTOR/#ALTTOR/' /etc/csf/csf.blocklists
sed -i '/^CIARMY/s/^CIARMY/#CIARMY/' /etc/csf/csf.blocklists
sed -i '/^BFB/s/^BFB/#BFB/' /etc/csf/csf.blocklists
sed -i '/^OPENBL/s/^OPENBL/#OPENBL/' /etc/csf/csf.blocklists
sed -i '/^BDEALL/s/^BDEALL/#BDEALL/' /etc/csf/csf.blocklists
	
cat > /etc/csf/csf.rignore << EOF
.cpanel.net
.googlebot.com
.crawl.yahoo.net
.search.msn.com
EOF

echo "Opening ports in CSF for TCP_OUT cPanel migrations..."
CPANEL_PORTS="2082,2083"
CURR_CSF_OUT=$(grep "^TCP_OUT" /etc/csf/csf.conf | cut -d'=' -f2 | sed 's/\ //g' | sed 's/\"//g' | sed "s/,$CPANEL_PORTS,/,/g" | sed "s/,$CPANEL_PORTS//g" | sed "s/$CPANEL_PORTS,//g" | sed "s/,,//g")
sed -i "s/^TCP_OUT.*/TCP_OUT = \"$CURR_CSF_OUT,$CPANEL_PORTS\"/" /etc/csf/csf.conf

echo "Activating DYNDNS..."
sed -i 's/^DYNDNS = .*/DYNDNS = "300"/g' /etc/csf/csf.conf
sed -i 's/^DYNDNS_IGNORE = .*/DYNDNS_IGNORE = "1"/g' /etc/csf/csf.conf

echo "Adding a csf.dyndns..."
sed -i '/gmail.com/d' /etc/csf/csf.dyndns
sed -i '/public.pyzor.org/d' /etc/csf/csf.dyndns
echo "tcp|out|d=25|d=smtp.gmail.com" >> /etc/csf/csf.dyndns
echo "tcp|out|d=465|d=smtp.gmail.com" >> /etc/csf/csf.dyndns
echo "tcp|out|d=587|d=smtp.gmail.com" >> /etc/csf/csf.dyndns
echo "tcp|out|d=995|d=imap.gmail.com" >> /etc/csf/csf.dyndns
echo "tcp|out|d=993|d=imap.gmail.com" >> /etc/csf/csf.dyndns
echo "tcp|out|d=143|d=imap.gmail.com" >> /etc/csf/csf.dyndns
echo "udp|out|d=24441|d=public.pyzor.org" >> /etc/csf/csf.dyndns

csf -r
service lfd restart

echo "####### END CONFIGURING CSF #######"
echo "####### SETTING CPANEL #######"

if [ ! -d /usr/local/cpanel ]; then
	echo "cPanel not detected. Aborting."
	exit 0
fi

HOSTNAME_LONG=$(hostname -d)

echo "DNS TTL down to 15 min..."
sed -i 's / ^ TTL . * / TTL 900 /' /etc/wwwacct.conf

echo "Changing contact email..."
sed -i '/^CONTACTEMAIL\ .*/d' /etc/wwwacct.conf
echo "CONTACTEMAIL hostmaster@$HOSTNAME_LONG" >> /etc/wwwacct.conf

echo "Changing default DNSs..."
sed -i '/^NS\ .*/d' /etc/wwwacct.conf
sed -i '/^NS2\ .*/d' /etc/wwwacct.conf
sed -i '/^NS3\ .*/d' /etc/wwwacct.conf
echo "NS ns1.$HOSTNAME_LONG" >> /etc/wwwacct.conf
echo "NS2 ns2.$HOSTNAME_LONG" >> /etc/wwwacct.conf

echo "Setting FTP..."
sed -i '/^MaxClientsPerIP:.*/d' /var/cpanel/conf/pureftpd/local; echo "MaxClientsPerIP: 30 " >> /var/cpanel/conf/pureftpd/local
sed -i '/^RootPassLogins:.*/d' /var/cpanel/conf/pureftpd/local; echo "RootPassLogins: 'no'" >> /var/cpanel/conf/pureftpd/local
sed -i '/^PassivePortRange:.*/d' /var/cpanel/conf/pureftpd/local; echo "PassivePortRange: $ PASSV_MIN  $ PASSV_MAX " >> /var/cpanel/conf/pureftpd/local
sed -i '/^TLSCipherSuite:.*/d' /var/cpanel/conf/pureftpd/local; echo 'TLSCipherSuite: "HIGH: MEDIUM: + TLSv 1 :! SSLv 2 : + SSLv 3 "' >> /var/cpanel/conf/pureftpd/local
sed -i '/^LimitRecursion:.*/d' /var/cpanel/conf/pureftpd/local; echo "LimitRecursion: 50000  12 " >> /var/cpanel/conf/pureftpd/local

/usr/local/cpanel/scripts/setupftpserver pure-ftpd --force

echo "Activating module ip_conntrack_ftp..."
modprobe ip_conntrack_ftp
echo "modprobe ip_conntrack_ftp" >> /etc/rc.modules
chmod +x /etc/rc.modules

echo "Setting Tweak Settings..."
whmapi1 set_tweaksetting key=allowremotedomains value=1
whmapi1 set_tweaksetting key=allowunregistereddomains value=1
whmapi1 set_tweaksetting key=chkservd_check_interval value=120
whmapi1 set_tweaksetting key=defaultmailaction value=fail
whmapi1 set_tweaksetting key=email_send_limits_max_defer_fail_percentage value=25
whmapi1 set_tweaksetting key=email_send_limits_min_defer_fail_to_trigger_protection value=15
whmapi1 set_tweaksetting key=maxemailsperhour value=200
whmapi1 set_tweaksetting key=permit_unregistered_apps_as_root value=1
whmapi1 set_tweaksetting key=requiressl value=1
whmapi1 set_tweaksetting key=skipanalog value=1
whmapi1 set_tweaksetting key=skipboxtrapper value=1
whmapi1 set_tweaksetting key=skipwebalizer value=1
whmapi1 set_tweaksetting key=smtpmailgidonly value=0
whmapi1 set_tweaksetting key=eximmailtrap value=1
whmapi1 set_tweaksetting key=use_information_schema value=0
whmapi1 set_tweaksetting key=cookieipvalidation value=disabled
whmapi1 set_tweaksetting key=notify_expiring_certificates value=0
whmapi1 set_tweaksetting key=cpaddons_notify_owner value=0
whmapi1 set_tweaksetting key=cpaddons_notify_root value=0
whmapi1 set_tweaksetting key=enable_piped_logs value=1
whmapi1 set_tweaksetting key=email_outbound_spam_detect_action value=block
whmapi1 set_tweaksetting key=email_outbound_spam_detect_enable value=1
whmapi1 set_tweaksetting key=email_outbound_spam_detect_threshold value=120
whmapi1 set_tweaksetting key=skipspambox value=0
whmapi1 set_tweaksetting key=skipmailman value=1
whmapi1 set_tweaksetting key=jaildefaultshell value=1
whmapi1 set_tweaksetting key = php_post_max_size value = 100
whmapi1 set_tweaksetting key = php_upload_max_filesize value = 100
whmapi1 set_tweaksetting key = empty_trash_days value = 30
whmapi1 set_tweaksetting key=publichtmlsubsonly value=0

# DEACTIVATE PASSWORD RESET BY MAIL
whmapi1 set_tweaksetting key=resetpass value=0
whmapi1 set_tweaksetting key=resetpass_sub value=0

sed -i 's/^phpopenbasedirhome=.*/phpopenbasedirhome=1/' /var/cpanel/cpanel.config
sed -i 's/^minpwstrength=.*/minpwstrength=70/' /var/cpanel/cpanel.config

/usr/local/cpanel/etc/init/startcpsrvd

# CONFIGURATIONS THAT CANNOT BE DONE BY CONSOLE
echo "Configuring the inconfigurable from console..."
yum install -y curl

touch $CWD/wpwhmcookie.txt
SESS_CREATE=$(whmapi1 create_user_session user=root service=whostmgrd)
SESS_TOKEN=$(echo "$SESS_CREATE" | grep "cp_security_token:" | cut -d':' -f2- | sed 's/ //')
SESS_QS=$(echo "$SESS_CREATE" | grep "session:" | cut -d':' -f2- | sed 's/ //' | sed 's/ /%20/g;s/!/%21/g;s/"/%22/g;s/#/%23/g;s/\$/%24/g;s/\&/%26/g;s/'\''/%27/g;s/(/%28/g;s/)/%29/g;s/:/%3A/g')

curl -sk "https://127.0.0.1:2087/$SESS_TOKEN/login/?session=$SESS_QS" --cookie-jar $CWD/wpwhmcookie.txt > /dev/null

echo "Disabling compilers..."
curl -sk "https://127.0.0.1:2087/$SESS_TOKEN/scripts2/tweakcompilers" --cookie $CWD/wpwhmcookie.txt --data 'action=Disable+Compilers' > /dev/null
echo "Disabling SMTP Restrictions (se usa CSF)..."
curl -sk "https://127.0.0.1:2087/$SESS_TOKEN/scripts2/smtpmailgidonly?action=Disable" --cookie $CWD/wpwhmcookie.txt > /dev/null
echo "Disabling Shell Fork Bomb Protection..."
curl -sk "https://127.0.0.1:2087/$SESS_TOKEN/scripts2/modlimits?limits=0" --cookie $CWD/wpwhmcookie.txt > /dev/null
echo "Enabling Background Process Killer..."
curl -sk "https://127.0.0.1:2087/$SESS_TOKEN/json-api/configurebackgroundprocesskiller" --cookie $CWD/wpwhmcookie.txt --data 'api.version=1&processes_to_kill=BitchX&processes_to_kill=bnc&processes_to_kill=eggdrop&processes_to_kill=generic-sniffers&processes_to_kill=guardservices&processes_to_kill=ircd&processes_to_kill=psyBNC&processes_to_kill=ptlink&processes_to_kill=services&force=1' > /dev/null

echo "Setting Apache..."
# BASIC CONFIG
curl -sk "https://127.0.0.1:2087/$SESS_TOKEN/scripts2/saveglobalapachesetup" --cookie $CWD/wpwhmcookie.txt --data 'module=Apache&find=&___original_sslciphersuite=ECDHE-ECDSA-AES256-GCM-SHA384%3AECDHE-RSA-AES256-GCM-SHA384%3AECDHE-ECDSA-CHACHA20-POLY1305%3AECDHE-RSA-CHACHA20-POLY1305%3AECDHE-ECDSA-AES128-GCM-SHA256%3AECDHE-RSA-AES128-GCM-SHA256%3AECDHE-ECDSA-AES256-SHA384%3AECDHE-RSA-AES256-SHA384%3AECDHE-ECDSA-AES128-SHA256%3AECDHE-RSA-AES128-SHA256&sslciphersuite_control=default&___original_sslprotocol=TLSv1.2&sslprotocol_control=default&___original_loglevel=warn&loglevel=warn&___original_traceenable=Off&traceenable=Off&___original_serversignature=Off&serversignature=Off&___original_servertokens=ProductOnly&servertokens=ProductOnly&___original_fileetag=None&fileetag=None&___original_root_options=&root_options=FollowSymLinks&root_options=IncludesNOEXEC&root_options=SymLinksIfOwnerMatch&___original_startservers=5&startservers_control=default&___original_minspareservers=5&minspareservers_control=default&___original_maxspareservers=10&maxspareservers_control=default&___original_optimize_htaccess=search_homedir_below&optimize_htaccess=search_homedir_below&___original_serverlimit=256&serverlimit_control=default&___original_maxclients=150&maxclients_control=other&maxclients_other=100&___original_maxrequestsperchild=10000&maxrequestsperchild_control=default&___original_keepalive=On&keepalive=1&___original_keepalivetimeout=5&keepalivetimeout_control=default&___original_maxkeepaliverequests=100&maxkeepaliverequests_control=default&___original_timeout=300&timeout_control=default&___original_symlink_protect=Off&symlink_protect=0&its_for_real=1' > /dev/null

# DIRECTORYINDEX
curl -sk "https://127.0.0.1:2087/$SESS_TOKEN/scripts2/save_apache_directoryindex" --cookie $CWD/wpwhmcookie.txt --data 'valid_submit=1&dirindex=index.php&dirindex=index.php5&dirindex=index.php4&dirindex=index.php3&dirindex=index.perl&dirindex=index.pl&dirindex=index.plx&dirindex=index.ppl&dirindex=index.cgi&dirindex=index.jsp&dirindex=index.jp&dirindex=index.phtml&dirindex=index.shtml&dirindex=index.xhtml&dirindex=index.html&dirindex=index.htm&dirindex=index.wml&dirindex=Default.html&dirindex=Default.htm&dirindex=default.html&dirindex=default.htm&dirindex=home.html&dirindex=home.htm&dirindex=index.js' > /dev/null

curl -sk "https://127.0.0.1:2087/$SESS_TOKEN/scripts2/save_apache_mem_limits" --cookie $CWD/wpwhmcookie.txt --data 'newRLimitMem=enabled&newRLimitMemValue=1024&restart_apache=on&btnSave=1' > /dev/null

/scripts/rebuildhttpdconf
service httpd restart

# DOVECOT
curl -sk "https://127.0.0.1:2087/$SESS_TOKEN/scripts2/savedovecotsetup" --cookie $ CWD / wpwhmcookie.txt --data 'protocols_enabled_imap = on & protocols_enabled_pop3 = on & ipv6 = on & enable_plaintext_auth = yes & yesssl_cipher_list = ECDHE-ECDSA-CHACHA20-POLY1305% 3AECDHE-RSA-CHACHA20-POLY1305% 3AECDHE-ECDSA-AES128-GCM-SHA256% 3AECDHE-RSA-AES128-GCM-SHA256% -AECA-6A GCA-6A GCA-6A GCA-6A-GCA-6A GCA-6A-GCAA6E-GCA-6A GCA-6A-GCAA6E-GCAA6E-GCAA6E-GCAA6E-GCAA6E-GCAA6E-A6A-GCAA6E-GCAA6E-GCAA6E-GCAA6E-GCAA6E-GCAA6E-GCAA6A-GCAA6E-GCAA6E-GCAA6A-GCAA6E-GCAA6A-GCAA6E-6% GCA-A6D RSA-AES256-GCM-SHA384% 3ADHE-RSA-AES128-GCM-SHA256% 3ADHE-RSA-AES256-GCM-SHA384% 3AECDHE-ECDSA-AES128-SHA256% 3AECDHE-RSA-AES128-SHA256-ECA-AES128-ECA-AES128-ECA-AES128-ECA-AES128-ECA-AES128-ECA-AES128-ECA-AES128-ECA-AES128-ECA-AES128-ECA-AES128-ECA-AES128-ECA-AES128-ECA-AES128-ECA-AES128-ECA-AES128-SHA256 SHA% 3AECDHE-RSA-AES256-SHA384% 3AECDHE-RSA-AES128-SHA% 3AECDHE-ECDSA-AES256-SHA384% 3AECDHE-ECDSA-AES256-SHA% 3AECDHE-RSA-AES256-SHA% 3ADHE-RSA-AES128-SHA256% 3ADHE-RSA-AES128-SHA% 3ADHE-RSA-AES256-SHA256% 3ADHE-RSA-AES256-SHA% 3AECDHE-ECDSA-DES-CBC3-SHA% 3AECDHE-RSA-DES-CBC3-SHA% 3AEDH-RSA-RSA-RSA-RSA-RSA CBC3-SHA% 3AAES128-GCM-SHA256% 3AAES256-GCM-SHA384% 3AAES128-SHA256% 3AAES256-SHA256% 3AAES128-SHA% 3AAES256-SHA% 3ADES-CBC3-SHA% 3A% 21DSS & ssl_min_protocol = TLSv1 & max_mail_processes = 512 & mail_process_size = 512 & protocol_imap.mail_max_userip_connections = 20 protocol_imap.imap_idle_notify_interval & = 24 & protocol_pop3.mail_max_userip_connections = 3 & login_processes_count = 2 & login_max_processes_count = 50 & login_process_size = 128 & auth_cache_size = 1M & auth_cache_ttl = 3600 & auth_cache_negative_ttl = 3600 & login_process_per_connection = no & config_vsz_limit = 2048 mailbox_idle_check_interval & = 30 & mdbox_rotate_size = 10M & mdbox_rotate_interval = 0 & incoming_reached_quota = bounce & lmtp_process_min_avail = 0 & lmtp_process_limit = 500 & lmtp_user_concurrency_limit = 4 & expire_trash = 1 & expire_trash_ttl = 30 & include_trash_in_quota = 1 'auth_cache_size = 1M & auth_cache_ttl = 3600 & auth_cache_negative_ttl = 3600 & login_process_per_connection = no & config_vsz_limit = 2048 mailbox_idle_check_interval & = 30 & mdbox_rotate_size = 10M & mdbox_rotate_interval = 0 & incoming_reached_quota = bounce & lmtp_process_min_avail = 0 & lmtp_process_limit = 500 & lmtp_user_concurrency_limit = 4 & expire_trash = 1 & expire_trash_ttl = 30 & include_trash_in_quota = 1 'auth_cache_size = 1M & auth_cache_ttl = 3600 & auth_cache_negative_ttl = 3600 & login_process_per_connection = no & config_vsz_limit = 2048 mailbox_idle_check_interval & = 30 & mdbox_rotate_size = 10M & mdbox_rotate_interval = 0 & incoming_reached_quota = bounce & lmtp_process_min_avail = 0 & lmtp_process_limit = 500 & lmtp_user_concurrency_limit = 4 & expire_trash = 1 & expire_trash_ttl = 30 & include_trash_in_quota = 1 '

# EXIM
curl -sk "https://127.0.0.1:2087/$SESS_TOKEN/scripts2/saveeximtweaks" --cookie $COOKIE_FILE --data 'in_tab=1&module=Mail&find=&___original_acl_deny_spam_score_over_int=&___undef_original_acl_deny_spam_score_over_int=1&acl_deny_spam_score_over_int_control=undef&___original_acl_dictionary_attack=1&acl_dictionary_attack=1&___original_acl_primary_hostname_bl=0&acl_primary_hostname_bl=0&___original_acl_spam_scan_secondarymx=1&acl_spam_scan_secondarymx=1&___original_acl_ratelimit=1&acl_ratelimit=1&___original_acl_ratelimit_spam_score_over_int=&___undef_original_acl_ratelimit_spam_score_over_int=1&acl_ratelimit_spam_score_over_int_control=undef&___original_acl_slow_fail_block=1&acl_slow_fail_block=1&___original_acl_requirehelo=1&acl_requirehelo=1&___original_acl_delay_unknown_hosts=1&acl_delay_unknown_hosts=1&___original_acl_dont_delay_greylisting_trusted_hosts=1&acl_dont_delay_greylisting_trusted_hosts=1&___original_acl_dont_delay_greylisting_common_mail_providers=0&acl_dont_delay_greylisting_common_mail_providers=0&___original_acl_requirehelonoforge=1&acl_requirehelonoforge=1&___original_acl_requirehelonold=0&acl_requirehelonold=0&___original_acl_requirehelosyntax=1&acl_requirehelosyntax=1&___original_acl_dkim_disable=1&acl_dkim_disable=1&___original_acl_dkim_bl=0&___original_acl_deny_rcpt_soft_limit=&___undef_original_acl_deny_rcpt_soft_limit=1&acl_deny_rcpt_soft_limit_control=undef&___original_acl_deny_rcpt_hard_limit=&___undef_original_acl_deny_rcpt_hard_limit=1&acl_deny_rcpt_hard_limit_control=undef&___original_spammer_list_ips_button=&___undef_original_spammer_list_ips_button=1&___original_sender_verify_bypass_ips_button=&___undef_original_sender_verify_bypass_ips_button=1&___original_trusted_mail_hosts_ips_button=&___undef_original_trusted_mail_hosts_ips_button=1&___original_skip_smtp_check_ips_button=&___undef_original_skip_smtp_check_ips_button=1&___original_backup_mail_hosts_button=&___undef_original_backup_mail_hosts_button=1&___original_trusted_mail_users_button=&___undef_original_trusted_mail_users_button=1&___original_blocked_domains_button=&___undef_original_blocked_domains_button=1&___original_filter_emails_by_country_button=&___undef_original_filter_emails_by_country_button=1&___original_per_domain_mailips=1&per_domain_mailips=1&___original_custom_mailhelo=0&___original_custom_mailips=0&___original_systemfilter=%2Fetc%2Fcpanel_exim_system_filter&systemfilter_control=default&___original_filter_attachments=1&filter_attachments=1&___original_filter_spam_rewrite=1&filter_spam_rewrite=1&___original_filter_fail_spam_score_over_int=&___undef_original_filter_fail_spam_score_over_int=1&filter_fail_spam_score_over_int_control=undef&___original_spam_header=***SPAM***&spam_header_control=default&___original_acl_0tracksenders=0&acl_0tracksenders=0&___original_callouts=0&callouts=0&___original_smarthost_routelist=&smarthost_routelist_control=default&___original_smarthost_autodiscover_spf_include=1&smarthost_autodiscover_spf_include=1&___original_spf_include_hosts=&spf_include_hosts_control=default&___original_rewrite_from=disable&rewrite_from=disable&___original_hiderecpfailuremessage=0&hiderecpfailuremessage=0&___original_malware_deferok=1&malware_deferok=1&___original_senderverify=1&senderverify=1&___original_setsenderheader=0&setsenderheader=0&___original_spam_deferok=1&spam_deferok=1&___original_srs=0&srs=0&___original_query_apache_for_nobody_senders=1&query_apache_for_nobody_senders=1&___original_trust_x_php_script=1&trust_x_php_script=1&___original_dsn_advertise_hosts=&___undef_original_dsn_advertise_hosts=1&dsn_advertise_hosts_control=undef&___original_smtputf8_advertise_hosts=&___undef_original_smtputf8_advertise_hosts=1&smtputf8_advertise_hosts_control=undef&___original_manage_rbls_button=&___undef_original_manage_rbls_button=1&___original_acl_spamcop_rbl=1&acl_spamcop_rbl=1&___original_acl_spamhaus_rbl=1&acl_spamhaus_rbl=1&___original_rbl_whitelist_neighbor_netblocks=1&rbl_whitelist_neighbor_netblocks=1&___original_rbl_whitelist_greylist_common_mail_providers=1&rbl_whitelist_greylist_common_mail_providers=1&___original_rbl_whitelist_greylist_trusted_netblocks=0&rbl_whitelist_greylist_trusted_netblocks=0&___original_rbl_whitelist=&rbl_whitelist=&___original_allowweakciphers=1&allowweakciphers=1&___original_require_secure_auth=0&require_secure_auth=0&___original_openssl_options=+%2Bno_sslv2+%2Bno_sslv3&openssl_options_control=other&openssl_options_other=+%2Bno_sslv2+%2Bno_sslv3&___original_tls_require_ciphers=ECDHE-ECDSA-CHACHA20-POLY1305%3AECDHE-RSA-CHACHA20-POLY1305%3AECDHE-ECDSA-AES128-GCM-SHA256%3AECDHE-RSA-AES128-GCM-SHA256%3AECDHE-ECDSA-AES256-GCM-SHA384%3AECDHE-RSA-AES256-GCM-SHA384%3ADHE-RSA-AES128-GCM-SHA256%3ADHE-RSA-AES256-GCM-SHA384%3AECDHE-ECDSA-AES128-SHA256%3AECDHE-RSA-AES128-SHA256%3AECDHE-ECDSA-AES128-SHA%3AECDHE-RSA-AES256-SHA384%3AECDHE-RSA-AES128-SHA%3AECDHE-ECDSA-AES256-SHA384%3AECDHE-ECDSA-AES256-SHA%3AECDHE-RSA-AES256-SHA%3ADHE-RSA-AES128-SHA256%3ADHE-RSA-AES128-SHA%3ADHE-RSA-AES256-SHA256%3ADHE-RSA-AES256-SHA%3AECDHE-ECDSA-DES-CBC3-SHA%3AECDHE-RSA-DES-CBC3-SHA%3AEDH-RSA-DES-CBC3-SHA%3AAES128-GCM-SHA256%3AAES256-GCM-SHA384%3AAES128-SHA256%3AAES256-SHA256%3AAES128-SHA%3AAES256-SHA%3ADES-CBC3-SHA%3A%21DSS&tls_require_ciphers_control=other&tls_require_ciphers_other=ECDHE-ECDSA-CHACHA20-POLY1305%3AECDHE-RSA-CHACHA20-POLY1305%3AECDHE-ECDSA-AES128-GCM-SHA256%3AECDHE-RSA-AES128-GCM-SHA256%3AECDHE-ECDSA-AES256-GCM-SHA384%3AECDHE-RSA-AES256-GCM-SHA384%3ADHE-RSA-AES128-GCM-SHA256%3ADHE-RSA-AES256-GCM-SHA384%3AECDHE-ECDSA-AES128-SHA256%3AECDHE-RSA-AES128-SHA256%3AECDHE-ECDSA-AES128-SHA%3AECDHE-RSA-AES256-SHA384%3AECDHE-RSA-AES128-SHA%3AECDHE-ECDSA-AES256-SHA384%3AECDHE-ECDSA-AES256-SHA%3AECDHE-RSA-AES256-SHA%3ADHE-RSA-AES128-SHA256%3ADHE-RSA-AES128-SHA%3ADHE-RSA-AES256-SHA256%3ADHE-RSA-AES256-SHA%3AECDHE-ECDSA-DES-CBC3-SHA%3AECDHE-RSA-DES-CBC3-SHA%3AEDH-RSA-DES-CBC3-SHA%3AAES128-GCM-SHA256%3AAES256-GCM-SHA384%3AAES128-SHA256%3AAES256-SHA256%3AAES128-SHA%3AAES256-SHA%3ADES-CBC3-SHA%3A%21DSS&___original_globalspamassassin=0&globalspamassassin=0&___original_max_spam_scan_size=1000&max_spam_scan_size_control=default&___original_acl_outgoing_spam_scan=0&acl_outgoing_spam_scan=0&___original_acl_outgoing_spam_scan_over_int=&___undef_original_acl_outgoing_spam_scan_over_int=1&acl_outgoing_spam_scan_over_int_control=undef&___original_no_forward_outbound_spam=0&no_forward_outbound_spam=0&___original_no_forward_outbound_spam_over_int=&___undef_original_no_forward_outbound_spam_over_int=1&no_forward_outbound_spam_over_int_control=undef&___original_spamassassin_plugin_BAYES_POISON_DEFENSE=1&spamassassin_plugin_BAYES_POISON_DEFENSE=1&___original_spamassassin_plugin_P0f=1&spamassassin_plugin_P0f=1&___original_spamassassin_plugin_KAM=1&spamassassin_plugin_KAM=1&___original_spamassassin_plugin_CPANEL=1&spamassassin_plugin_CPANEL=1'

# ACTIVATE BIND INSTEAD OF POWERDNS
-sk curl "https: // 127 . 0 . 0 . 1 : 2087 / $ SESS_TOKEN ? / scripts / doconfigurenameserver nameserver = bind" --cookie $ COOKIE_FILE

# REMOVE COOKIE
rm -f $CWD/wpwhmcookie.txt

echo "SETTING exim..."
sed -i 's/^acl_spamhaus_rbl=.*/acl_spamhaus_rbl=1/' /etc/exim.conf.localopts
sed -i 's/^acl_spamcop_rbl=.*/acl_spamcop_rbl=1/' /etc/exim.conf.localopts
sed -i 's/^require_secure_auth=.*/require_secure_auth=0/' /etc/exim.conf.localopts
sed -i 's/^acl_spamcop_rbl=.*/acl_spamcop_rbl=1/' /etc/exim.conf.localopts
sed -i 's/^allowweakciphers=.*/allowweakciphers=1/' /etc/exim.conf.localopts
sed -i 's/^per_domain_mailips=.*/per_domain_mailips=1/' /etc/exim.conf.localopts # IT SEEMS TO HAVE A BUG WHEIN IT IS CONFIGUERD WITH CURL
sed -i 's/^max_spam_scan_size=.*/max_spam_scan_size=1000/' /etc/exim.conf.localopts
sed -i 's/^openssl_options=.*/openssl_options= +no_sslv2 +no_sslv3/' /etc/exim.conf.localopts
sed -i 's/^tls_require_ciphers=.*/tls_require_ciphers=ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256:DHE-RSA-AES256-SHA:ECDHE-ECDSA-DES-CBC3-SHA:ECDHE-RSA-DES-CBC3-SHA:EDH-RSA-DES-CBC3-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:DES-CBC3-SHA:!DSS/' /etc/exim.conf.localopts

# LIMIT OF ATTACHMENTS
sed -i '/^message_size_limit.*/d' /etc/exim.conf.local
if grep "@CONFIG@" /etc/exim.conf.local > /dev/null; then
        sed -i '/@CONFIG@/ a message_size_limit = 25M' /etc/exim.conf.local
else
        echo "@CONFIG@" >> /etc/exim.conf.local
        echo "" >> /etc/exim.conf.local
        sed -i '/@CONFIG@/ a message_size_limit = 25M' /etc/exim.conf.local
fi

/scripts/buildeximconf

echo "Installing EasyApache 4 PHP packages..."
yum install -y \
ea-apache24-mod_proxy_fcgi \
libcurl-devel \
openssl-devel \
unixODBC \
ea-apache24-mod_version \
ea-apache24-mod_env \
ea-php55-php-curl \
ea-php55-php-fileinfo \
ea-php55-php-fpm \
ea-php55-php-gd \
ea-php55-php-iconv \
ea-php55-php-ioncube \
ea-php55-php-intl \
ea-php55-php-mbstring \
ea-php55-php-mcrypt \
ea-php55-php-pdo \
ea-php55-php-soap \
ea-php55-php-zip \
ea-php55-php-mysqlnd \
ea-php55-php-exif \
ea-php55-php-xmlrpc \
ea-php55-php-gmp \
ea-php55-php-gettext \
ea-php55-php-fpm \
ea-php55-php-xml \
ea-php55-php-bcmath \
ea-php55-php-imap \
ea-php56-php-curl \
ea-php56-php-fileinfo \
ea-php56-php-fpm \
ea-php56-php-gd \
ea-php56-php-iconv \
ea-php56-php-ioncube \
ea-php56-php-intl \
ea-php56-php-mbstring \
ea-php56-php-mcrypt \
ea-php56-php-pdo \
ea-php56-php-soap \
ea-php56-php-zip \
ea-php56-php-opcache \
ea-php56-php-mysqlnd \
ea-php56-php-bcmath \
ea-php56-php-exif \
ea-php56-php-xmlrpc \
ea-php56-php-gettext \
ea-php56-php-gmp \
ea-php56-php-fpm \
ea-php56-php-xml \
ea-php56-php-imap \
ea-php70-php-curl \
ea-php70-php-fileinfo \
ea-php70-php-fpm \
ea-php70-php-gd \
ea-php70-php-iconv \
ea-php70-php-intl \
ea-php70-php-mbstring \
ea-php70-php-mcrypt \
ea-php70-php-pdo \
ea-php70-php-soap \
ea-php70-php-xmlrpc \
ea-php70-php-xml \
ea-php70-php-zip \
ea-php70-php-ioncube10 \
ea-php70-php-opcache \
ea-php70-php-mysqlnd \
ea-php70-php-bcmath \
ea-php70-php-exif \
ea-php70-php-gettext \
ea-php70-php-gmp \
ea-php70-php-fpm \
ea-php70-php-imap \
ea-php71 \
ea-php71-pear \
ea-php71-php-cli \
ea-php71-php-common \
ea-php71-php-curl \
ea-php71-php-devel \
ea-php71-php-exif \
ea-php71-php-fileinfo \
ea-php71-php-fpm \
ea-php71-php-ftp \
ea-php71-php-gd \
ea-php71-php-iconv \
ea-php71-php-intl \
ea-php71-php-litespeed \
ea-php71-php-mbstring \
ea-php71-php-mcrypt \
ea-php71-php-mysqlnd \
ea-php71-php-odbc \
ea-php71-php-opcache \
ea-php71-php-pdo \
ea-php71-php-posix \
ea-php71-php-soap \
ea-php71-php-zip \
ea-php71-runtime \
ea-php71-php-bcmath \
ea-php71-php-ioncube10 \
ea-php71-php-xmlrpc \
ea-php71-php-gettext \
ea-php71-php-gmp \
ea-php71-php-xml \
ea-php71-php-imap \
ea-php72 \
ea-php72-pear \
ea-php72-php-cli \
ea-php72-php-common \
ea-php72-php-curl \
ea-php72-php-devel \
ea-php72-php-exif \
ea-php72-php-fileinfo \
ea-php72-php-fpm \
ea-php72-php-ftp \
ea-php72-php-gd \
ea-php72-php-iconv \
ea-php72-php-intl \
ea-php72-php-litespeed \
ea-php72-php-mbstring \
ea-php72-php-mysqlnd \
ea-php72-php-opcache \
ea-php72-php-pdo \
ea-php72-php-posix \
ea-php72-php-soap \
ea-php72-php-zip \
ea-php72-runtime \
ea-php72-php-bcmath \
ea-php72-php-ioncube10 \
ea-php72-php-xmlrpc \
ea-php72-php-gettext \
ea-php72-php-gmp \
ea-php72-php-xml \
ea-php72-php-imap \
ea-php73 \
ea-php73-pear \
ea-php73-php-cli \
ea-php73-php-common \
ea-php73-php-curl \
ea-php73-php-devel \
ea-php73-php-exif \
ea-php73-php-fileinfo \
ea-php73-php-fpm \
ea-php73-php-ftp \
ea-php73-php-gd \
ea-php73-php-iconv \
ea-php73-php-intl \
ea-php73-php-litespeed \
ea-php73-php-mbstring \
ea-php73-php-mysqlnd \
ea-php73-php-opcache \
ea-php73-php-pdo \
ea-php73-php-posix \
ea-php73-php-soap \
ea-php73-php-zip \
ea-php73-runtime \
ea-php73-php-bcmath \
ea-php73-php-ioncube10 \
ea-php73-php-xmlrpc \
ea-php73-php-gettext \
ea-php73-php-gmp \
ea-php73-php-xml \
ea-php73-php-imap \
ea-php74 \
ea-php74-pear \
ea-php74-php-cli \
ea-php74-php-common \
ea-php74-php-curl \
ea-php74-php-devel \
ea-php74-php-exif \
ea-php74-php-fileinfo \
ea-php74-php-fpm \
ea-php74-php-ftp \
ea-php74-php-gd \
ea-php74-php-iconv \
ea-php74-php-intl \
ea-php74-php-litespeed \
ea-php74-php-mbstring \
ea-php74-php-mysqlnd \
ea-php74-php-opcache \
ea-php74-php-pdo \
ea-php74-php-posix \
ea-php74-php-soap \
ea-php74-php-zip \
ea-php74-runtime \
ea-php74-php-bcmath \
ea-php74-php-ioncube10 \
ea-php74-php-xmlrpc \
ea-php74-php-gettext \
ea-php74-php-gmp \
ea-php74-php-xml \
ea-php74-php-imap \
ea-php80 \
ea-php80-pear \
ea-php80-php-cli \
ea-php80-php-common \
ea-php80-php-curl \
ea-php80-php-devel \
ea-php80-php-exif \
ea-php80-php-fileinfo \
ea-php80-php-fpm \
ea-php80-php-ftp \
ea-php80-php-gd \
ea-php80-php-iconv \
ea-php80-php-intl \
ea-php80-php-litespeed \
ea-php80-php-mbstring \
ea-php80-php-mysqlnd \
ea-php80-php-opcache \
ea-php80-php-pdo \
ea-php80-php-posix \
ea-php80-php-soap \
ea-php80-php-zip \
ea-php80-runtime \
ea-php80-php-bcmath \
ea-php80-php-gettext \
ea-php80-php-gmp \
ea-php80-php-xml \
ea-php80-php-imap \
--skip-broken

echo "Setting EasyApache 4 PHP..."
find /opt/ \( -name "php.ini" -o -name "local.ini" \) | xargs sed -i 's/^memory_limit.*/memory_limit = 1024M/g'
find /opt/ \( -name "php.ini" -o -name "local.ini" \) | xargs sed -i 's/^enable_dl.*/enable_dl = Off/g'
find /opt/ \( -name "php.ini" -o -name "local.ini" \) | xargs sed -i 's/^expose_php.*/expose_php = Off/g'
find /opt/ \( -name "php.ini" -o -name "local.ini" \) | xargs sed -i 's/^register_globals.*/register_globals = Off/g'
find /opt/ \( -name "php.ini" -o -name "local.ini" \) | xargs sed -i 's/^emagic_quotes_gpc.*/magic_quotes_gpc = Off/g'
find /opt/ \( -name "php.ini" -o -name "local.ini" \) | xargs sed -i 's/^disable_functions.*/disable_functions = apache_get_modules,apache_get_version,apache_getenv,apache_note,apache_setenv,disk_free_space,diskfreespace,dl,exec,highlight_file,ini_alter,ini_restore,openlog,passthru,phpinfo,popen,posix_getpwuid,proc_close,proc_get_status,proc_nice,proc_open,proc_terminate,shell_exec,show_source,symlink,system,eval,debug_zval_dump/g'
find /opt/ \( -name "php.ini" -o -name "local.ini" \) | xargs sed -i 's/^upload_max_filesize.*/upload_max_filesize = 16M/g'
find /opt/ \( -name "php.ini" -o -name "local.ini" \) | xargs sed -i 's/^post_max_size.*/post_max_size = 16M/g'
find /opt/ \( -name "php.ini" -o -name "local.ini" \) | xargs sed -i 's/^date.timezone.*/date.timezone = "America\/Argentina\/Buenos_Aires"/g'
find /opt/ \( -name "php.ini" -o -name "local.ini" \) | xargs sed -i 's/^allow_url_fopen.*/allow_url_fopen = On/g'

find /opt/ \( -name "php.ini" -o -name "local.ini" \) | xargs sed -i 's/^max_execution_time.*/max_execution_time = 120/g'
find /opt/ \( -name "php.ini" -o -name "local.ini" \) | xargs sed -i 's/^max_input_time.*/max_input_time = 120/g'
find /opt/ \( -name "php.ini" -o -name "local.ini" \) | xargs sed -i 's/^max_input_vars.*/max_input_vars = 2000/g'
find /opt/ \( -name "php.ini" -o -name "local.ini" \) | xargs sed -i 's/^;default_charset = "UTF-8"/default_charset = "UTF-8"/g'
find /opt/ \( -name "php.ini" -o -name "local.ini" \) | xargs sed -i 's/^default_charset.*/default_charset = "UTF-8"/g'

find /opt/ \( -name "php.ini" -o -name "local.ini" \) | xargs sed -i 's/^display_errors.*/display_errors = Off/g'
find /opt/ \( -name "php.ini" -o -name "local.ini" \) | xargs sed -i 's/^track_errors.*/track_errors = Off/g'
find /opt/ \( -name "php.ini" -o -name "local.ini" \) | xargs sed -i 's/^html_errors.*/html_errors = Off/g'
find /opt/ \( -name "php.ini" -o -name "local.ini" \) | xargs sed -i 's/^error_reporting.*/error_reporting = E_ALL \& \~E_DEPRECATED \& \~E_STRICT/g'

echo "Setting default PHP-FPM values..." # https://documentation.cpanel.net/display/74Docs/Configuration+Values+of+PHP-FPM
mkdir -p /var/cpanel/ApachePHPFPM
cat > /var/cpanel/ApachePHPFPM/system_pool_defaults.yaml << EOF
---
pm_max_children: 20
pm_max_requests: 40
EOF
/usr/local/cpanel/scripts/php_fpm_config --rebuild
/scripts/restartsrv_apache_php_fpm

echo "Configuring Handlers..."
whmapi1 php_set_handler version=ea-php55 handler=cgi
whmapi1 php_set_handler version=ea-php56 handler=cgi
whmapi1 php_set_handler version=ea-php70 handler=cgi
whmapi1 php_set_handler version=ea-php71 handler=cgi
whmapi1 php_set_handler version=ea-php73 handler=cgi
whmapi1 php_set_handler version=ea-php74 handler=cgi
whmapi1 php_set_handler version=ea-php80 handler=cgi
whmapi1 php_set_system_default_version version=ea-php74


#echo "Configuring PHP-FPM..."
#whmapi1 php_set_default_accounts_to_fpm default_accounts_to_fpm=1
#whmapi1 convert_all_domains_to_fpm

if [ $ISVPS = "NO" ]; then
	echo "Configuring ModSecurity..."
	URL="https%3A%2F%2Fwaf.comodo.com%2Fdoc%2Fmeta_comodo_apache.yaml"
	whmapi1 modsec_add_vendor url=$URL
                
	MODSEC_DISABLE_CONF=("00_Init_Initialization.conf" "10_Bruteforce_Bruteforce.conf" "12_HTTP_HTTPDoS.conf")
	for CONF in "${MODSEC_DISABLE_CONF[@]}"
	do
		echo "Disabling conf $CONF..."
		whmapi1 modsec_make_config_inactive config=modsec_vendor_configs%2Fcomodo_apache%2F$CONF
	done
	whmapi1 modsec_enable_vendor vendor_id=comodo_apache

	function disable_rule {
	        whmapi1 modsec_disable_rule config=$2 id=$1
	        whmapi1 modsec_deploy_rule_changes config=$2
	}

	echo "Disabling conflicting rules..."
	disable_rule 211050 modsec_vendor_configs/comodo_apache/09_Global_Other.conf
	disable_rule 214420 modsec_vendor_configs/comodo_apache/17_Outgoing_FilterPHP.conf
	disable_rule 214940 modsec_vendor_configs/comodo_apache/22_Outgoing_FiltersEnd.conf
	disable_rule 222390 modsec_vendor_configs/comodo_apache/26_Apps_Joomla.conf
	disable_rule 211540 modsec_vendor_configs/comodo_apache/24_SQL_SQLi.conf
	disable_rule 210730 modsec_vendor_configs/comodo_apache/11_HTTP_HTTP.conf
	disable_rule 221570 modsec_vendor_configs/comodo_apache/32_Apps_OtherApps.conf
	disable_rule 212900 modsec_vendor_configs/comodo_apache/08_XSS_XSS.conf
	disable_rule 212000 modsec_vendor_configs/comodo_apache/08_XSS_XSS.conf
	disable_rule 212620 modsec_vendor_configs/comodo_apache/08_XSS_XSS.conf
	disable_rule 212700 modsec_vendor_configs/comodo_apache/08_XSS_XSS.conf
	disable_rule 212740 modsec_vendor_configs/comodo_apache/08_XSS_XSS.conf
	disable_rule 212870 modsec_vendor_configs/comodo_apache/08_XSS_XSS.conf
	disable_rule 212890 modsec_vendor_configs/comodo_apache/08_XSS_XSS.conf
	disable_rule 212640 modsec_vendor_configs/comodo_apache/08_XSS_XSS.conf
	disable_rule 212650 modsec_vendor_configs/comodo_apache/08_XSS_XSS.conf
	disable_rule 221560 modsec_vendor_configs/comodo_apache/32_Apps_OtherApps.conf
	disable_rule 210831 modsec_vendor_configs/comodo_apache/03_Global_Agents.conf
fi

echo "Configuring MySQL..."
sed -i '/^local-infile.*/d' /etc/my.cnf
sed -i '/^query_cache_type.*/d' /etc/my.cnf
sed -i '/^query_cache_size.*/d' /etc/my.cnf
sed -i '/^join_buffer_size.*/d' /etc/my.cnf
sed -i '/^tmp_table_size.*/d' /etc/my.cnf
sed -i '/^max_heap_table_size.*/d' /etc/my.cnf
sed -i '/^sql_mode.*/d' /etc/my.cnf

sed  -i '/\[mysqld\]/a\ ' /etc/my.cnf
sed  -i '/\[mysqld\]/a sql_mode = NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' /etc/my.cnf
sed  -i '/\[mysqld\]/a local-infile=0' /etc/my.cnf
sed  -i '/\[mysqld\]/a query_cache_type=1' /etc/my.cnf
sed  -i '/\[mysqld\]/a query_cache_size=12M' /etc/my.cnf
sed  -i '/\[mysqld\]/a join_buffer_size=12M' /etc/my.cnf
sed  -i '/\[mysqld\]/a tmp_table_size=192M' /etc/my.cnf
sed  -i '/\[mysqld\]/a max_heap_table_size=256M' /etc/my.cnf

/scripts/restartsrv_mysql

echo "Updating a MariaDB 10.3..."
whmapi1 start_background_mysql_upgrade version=10.3

echo "Configuring disabled features..."
whmapi1 update_featurelist featurelist = disabled api_shell = 0 agora = 0 analog = 0 boxtrapper = 0 traceaddy = 0 modules-php-pear = 0 modules-perl = 0 modules-ruby = 0 pgp = 0 phppgadmin = 0 postgres = 0 ror = 0 serverstatus = 0 webalizer = 0 clamavconnector_scan = 0 lists = 0

echo "defaultSetting features..."
whmapi1 update_featurelist featurelist=default modsecurity=1 zoneedit=1 emailtrace=1

echo "Creating default package..."
# It IS ESTIMATED 80% OF THE DISC FOR DEFAULT ACCOUNT
QUOTA=$(df -h /home/ | tail -1 | awk '{ print $2 }' | sed 's/G//' | awk '{ print ($1 * 1000) * 0.8 }')
whmapi1 addpkg name=default featurelist=default quota=$QUOTA cgi=0 frontpage=0 language=es maxftp=20 maxsql=20 maxpop=unlimited maxlists=0 maxsub=30 maxpark=30 maxaddon=0 hasshell=1 bwlimit=unlimited MAX_EMAIL_PER_HOUR=300 MAX_DEFER_FAIL_PERCENTAGE=30

echo "Setting server time..."
yum install ntpdate -y
echo "Synchronizing date with pool.ntp.org..."
ntpdate 0.pool.ntp.org 1.pool.ntp.org 2.pool.ntp.org 3.pool.ntp.org 0.south-america.pool.ntp.org
if [ -f /usr/share/zoneinfo/America/New_York ]; then
        echo "Configuring TIME ZONE America/New_York..."
        mv /etc/localtime /etc/localtime.old
        ln -s /usr/share/zoneinfo/America/New_York /etc/localtime
fi
echo "Setting BIOS date..."
hwclock -r

echo "Disabling mlocate cron..."
chmod -x /etc/cron.daily/mlocate* 2>&1 > /dev/null

if [ -f /proc/user_beancounters ]; then
	echo "OpenVZ detected, implementing hostname patch..."
	echo "/usr/bin/hostnamectl set-hostname $HOSTNAME" >> /etc/rc.d/rc.local
	echo "/bin/systemctl restart exim.service" >> /etc/rc.d/rc.local
	chmod +x /etc/rc.d/rc.local
fi

echo "Configuring AutoSSL..."
whmapi1 set_autossl_metadata_key key=clobber_externally_signed value=1
whmapi1 set_autossl_metadata_key key=notify_autossl_expiry value=0
whmapi1 set_autossl_metadata_key key=notify_autossl_expiry_coverage value=0
whmapi1 set_autossl_metadata_key key=notify_autossl_renewal value=0
whmapi1 set_autossl_metadata_key key=notify_autossl_renewal_coverage value=0
whmapi1 set_autossl_metadata_key key=notify_autossl_renewal_coverage_reduced value=0
whmapi1 set_autossl_metadata_key key=notify_autossl_renewal_uncovered_domains value=0

/scripts/install_lets_encrypt_autossl_provider

echo "Disabling cPHulk..."
whmapi1 disable_cphulk

echo "Activating Header Authorization in CGI..."
sed -i '/# ACTIVATE HEADER AUTHORIZATION CGI/,/# END ACTIVATE HEADER AUTHORIZATION CGI/d' /etc/apache2/conf.d/includes/pre_main_global.conf

cat >> /etc/apache2/conf.d/includes/pre_main_global.conf << 'EOF'
# START ACTIVATE HEADER AUTHORIZATION CGI
SetEnvIf Authorization "(.*)" HTTP_AUTHORIZATION=$1
# END ACTIVATE HEADER AUTHORIZATION CGI

EOF

/scripts/restartsrv_apache

echo "Activating 2FA..."
/usr/local/cpanel/bin/whmapi1 twofactorauth_enable_policy

echo "Patch Webmail x3 error..."
ln -s /usr/local/cpanel/base/webmail/paper_lantern /usr/local/cpanel/base/webmail/x3

echo "disabling mod_userdir (old preview with ~ user)..."
sed -i 's/:.*/:/g' /var/cpanel/moddirdomains

find /var/cpanel/userdata/ -type f -exec grep -H "userdirprotect: -1" {} \; | while read LINE
do
        FILE=$(echo "$LINE" | cut -d':' -f1)
        sed -i "s/userdirprotect: -1/userdirprotect: ''/" "$FILE"
done

/scripts/rebuildhttpdconf
/scripts/

echo "Configuring JailShell..."
echo "/etc/pki/java" >> /var/cpanel/jailshell-additional-mounts

echo "Miscellaneous..."
# DOES NOT HAVE EXECUTION PERMITS FOR EVERYONE BY DEFAULT
chmod 755 /usr/bin/wget
chmod 755 /usr/bin/curl 

/scripts/restartsrv_httpd
/scripts/restartsrv_apache_php_fpm

echo "Disabling Greylisting ..."
whmapi1 disable_cpgreylist

echo "Disabling Welcome Panel..."
# https://support.cpanel.net/hc/en-us/articles/1500003456602-How-to-Disable-the-Welcome-Panel-Server-Wide-for-Newly-Created-Accounts
mkdir -pv /root/cpanel3-skel/.cpanel/nvdata; echo "1" > /root/cpanel3-skel/.cpanel/nvdata/xmainwelcomedismissed

echo "Deactivating the new Glass theme for new accounts..."
# https://support.cpanel.net/hc/en-us/articles/1500011608461
# https://support.cpanel.net/hc/en-us/articles/4402125595415-How-to-disable-the-Glass-theme-feedback-banner-for-newly-created-accounts
mkdir -pv /root/cpanel3-skel/.cpanel/nvdata/; echo -n "1" > /root/cpanel3-skel/.cpanel/nvdata/xmainNewStyleBannerDismissed
mkdir -pv /root/cpanel3-skel/.cpanel/nvdata/; echo -n "1" > /root/cpanel3-skel/.cpanel/nvdata/xmainSwitchToPreviousBannerDismissed
whmapi1 set_default type='default' name='basic'

echo "Disabling cPanel Analytics..."
whmapi1 participate_in_analytics enabled=0

echo "Create User Account..."
whmapi1 createacct username=$USERNAME domain=$DOMAIN bwlimit=unlimited cgi=1 contactemail=$EMAIL dkim=1 featurelist=default hasshell=1 maxaddon=unlimited maxftp=unlimited maxpark=unlimited maxpop=unlimited maxsql=unlimited pass=$PASSWORD quota=0 reseller=1 spamassassin=1 spf=1

echo "Create Reeller ACL..."
whmapi1 saveacllist acllist='default' acl-acct-summary=1 acl-add-pkg=1 acl-add-pkg-ip=1 acl-add-pkg-shell=1 acl-all=0 acl-allow-addoncreate=1 acl-allow-emaillimits-pkgs=1 acl-allow-parkedcreate=1 acl-allow-shell=1 acl-allow-unlimited-bw-pkgs=1 acl-allow-unlimited-disk-pkgs=1 acl-allow-unlimited-pkgs=1 acl-assign-root-account-enhancements=0 acl-basic-system-info=1 acl-basic-whm-functions=1 acl-clustering=1 acl-connected-applications=1 acl-cors-proxy-get=1 acl-cpanel-api=1 acl-cpanel-integration=1 acl-create-acct=1 acl-create-dns=1 acl-create-user-session=1 acl-demo-setup=0 acl-digest-auth=1 acl-edit-account=1 acl-edit-dns=1 acl-edit-mx=1 acl-edit-pkg=1 acl-file-restore=0 acl-generate-email-config=1 acl-kill-acct=1 acl-kill-dns=1 acl-limit-bandwidth=1 acl-list-accts=1 acl-list-pkgs=1 acl-locale-edit=0 acl-mailcheck=1 acl-manage-api-tokens=1 acl-manage-dns-records=1 acl-manage-oidc=1 acl-manage-styles=1 acl-mysql-info=1 acl-news=1 acl-ns-config=1 acl-park-dns=1 acl-passwd=1 acl-public-contact=1 acl-quota=1 acl-rearrange-accts=0 acl-resftp=0 acl-restart=0 acl-show-bandwidth=1 acl-software-ConfigServer-csf=0 acl-ssl=1 acl-ssl-buy=0 acl-ssl-gencrt=1 acl-ssl-info=1 acl-stats=1 acl-status=1 acl-suspend-acct=1 acl-thirdparty=1 acl-track-email=1 acl-upgrade-account=1 acl-viewglobalpackages=1

echo "Apply ACL to Reseller..."
whmapi1 setacls reseller=$USERNAME acllist=default

echo "Cleaning...."

history -c
echo "" > /root/.bash_history

echo "#### ¡Finished!. If you are going to restart do it in 10 minutes because you're be updating MySQL ####"
