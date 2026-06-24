FROM debian:bullseye
# Environment Variables
ENV DEBIAN_FRONTEND=noninteractive
ENV PSQL_PASSWORD="fusionpbx"
# 1. Install Basic Dependencies & PHP 8.1 Prerequisites
RUN  apt-get update && apt-get install -y \ lsb-release \ ca-certificates \ 
	apt-transport-https \ software-properties-common \ gnupg2 \ wget \ 
	curl \ git \ vim \ memcached \ haveged \ ssl-cert \ ghostscript \ nginx \
	libtiff-tools \  libtiff5-dev \ supervisor \ net-tools \ sudo \ jq \ lua-cjson \
	 && wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg \
	 && echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list \  
    && apt-get update
# 2. Install PHP 8.1 and Extensions
RUN apt-get install -y --no-install-recommends \
     php8.1 \ php8.1-cli \ php8.1-fpm \ php8.1-pgsql \ php8.1-sqlite3 \
php8.1-odbc \ php8.1-curl \ php8.1-imap \ php8.1-xml \ php8.1-gd \
php8.1-mbstring \ php8.1-ldap \ php8.1-bcmath \ && apt-get clean
# 3. Install FusionPBX  & Configure Nginx
RUN mkdir -p /etc/fusionpbx /var/www/fusionpbx /var/cache/fusionpbx \
    && git config --global http.postBuffer 1048576000 \
    && git config --global http.lowSpeedLimit 0 \
    && git config --global http.lowSpeedTime 999999 \
    && git clone -b 5.1 https://github.com/powerpbx/fusionpbx.git /var/www/fusionpbx \
    && chown -R www-data:www-data /var/www/fusionpbx /etc/fusionpbx /var/cache/fusionpbx \
    && chmod -R 775 /etc/fusionpbx /var/cache/fusionpbx \
    && wget https://raw.githubusercontent.com/fusionpbx/fusionpbx-install.sh/master/debian/resources/nginx/fusionpbx -O /etc/nginx/sites-available/fusionpbx \
    && ln -sf /etc/nginx/sites-available/fusionpbx /etc/nginx/sites-enabled/fusionpbx \
    && ln -sf /etc/ssl/private/ssl-cert-snakeoil.key /etc/ssl/private/nginx.key \
    && ln -sf /etc/ssl/certs/ssl-cert-snakeoil.pem /etc/ssl/certs/nginx.crt \
    && rm -f /etc/nginx/sites-enabled/default \
    && sed -i 's|unix:/var/run/php/php.*-fpm.sock|unix:/run/php/php8.1-fpm.sock|g' /etc/nginx/sites-available/fusionpbx
# 4. Install FreeSWITCH 1.10 (SignalWire Repo)
RUN echo "machine freeswitch.signalwire.com login $USERNAME password $PASSWORD" > /etc/apt/auth.conf.d/freeswitch.conf \
    && wget --http-user=$USERNAME --http-password=$PASSWORD -O /usr/share/keyrings/signalwire-freeswitch-repo.gpg https://freeswitch.signalwire.com/repo/deb/debian-re>
    && echo "deb [signed-by=/usr/share/keyrings/signalwire-freeswitch-repo.gpg] https://freeswitch.signalwire.com/repo/deb/debian-release/ $(lsb_release -sc) main" > /etc/apt/sources.l>
    && apt-get update \
    && apt-get install -y --no-install-recommends \
 freeswitch-meta-bare \ freeswitch-conf-vanilla \
 freeswitch-mod-commands \ freeswitch-mod-console \
 freeswitch-mod-logfile \ freeswitch-mod-distributor \
 freeswitch-lang-en \ freeswitch-mod-say-en \
 freeswitch-sounds-en-us-callie \ freeswitch-music-default \
	    freeswitch-mod-enum \ freeswitch-mod-cdr-csv \
	    freeswitch-mod-event-socket \ freeswitch-mod-sofia \
	    freeswitch-mod-sofia-dbg \ freeswitch-mod-loopback \
	    freeswitch-mod-conference \ freeswitch-mod-db \
	    freeswitch-mod-dptools \  freeswitch-mod-expr \
	    freeswitch-mod-fifo \ freeswitch-mod-httapi \
	    freeswitch-mod-hash \ freeswitch-mod-esl \
	    freeswitch-mod-esf \ freeswitch-mod-fsv \ 
	    freeswitch-mod-dialplan-xml \ freeswitch-mod-valet-parking \
	    freeswitch-mod-sndfile \ freeswitch-mod-native-file \
	    freeswitch-mod-tone-stream \ freeswitch-mod-local-stream \
	    freeswitch-mod-lua \ freeswitch-mod-xml-cdr \
	    freeswitch-mod-verto \    freeswitch-mod-callcenter \
	    freeswitch-mod-rtc \ freeswitch-mod-png \
	    freeswitch-mod-json-cdr \ freeswitch-mod-shout \
	    freeswitch-mod-sms \ freeswitch-mod-cidlookup \
	    freeswitch-mod-memcache \ freeswitch-mod-imagick \
	    freeswitch-mod-tts-commandline \ freeswitch-mod-directory \
	    freeswitch-mod-flite \ freeswitch-mod-pgsql \
    && apt-get clean
# 5. Configure FreeSWITCH Permissions & LUA Scripts
RUN usermod -a -G freeswitch www-data \
    && mv /etc/freeswitch /etc/freeswitch.orig \
    && mkdir -p /etc/freeswitch \
    && cp -R /var/www/fusionpbx/app/switch/resources/conf/* /etc/freeswitch/ \
    && chown -R freeswitch:freeswitch /etc/freeswitch \
    && usermod -a -G www-data freeswitch \
    && chown -R freeswitch:freeswitch /etc/freeswitch \
    && chown -R freeswitch:freeswitch /var/lib/freeswitch \
    && chown -R freeswitch:freeswitch /usr/share/freeswitch \
    && chown -R freeswitch:freeswitch /var/log/freeswitch \
    && chown -R freeswitch:freeswitch /run/freeswitch \
    && chmod -R ug+rw /etc/freeswitch \
    && chmod -R ug+rw /var/lib/freeswitch \
    && chmod -R ug+rw /usr/share/freeswitch \
    && chmod -R ug+rw /var/log/freeswitch \
    && mkdir -p /usr/share/freeswitch/scripts \
    && cp -R /var/www/fusionpbx/app/switch/resources/scripts/* /usr/share/freeswitch/scripts/ \
    && chown -R freeswitch:freeswitch /usr/share/freeswitch/scripts/ \
    && mkdir -p /usr/share/lua/5.2 \
    && ln -sf /usr/share/freeswitch/scripts/resources /usr/share/lua/5.2/resources \
    && ln -sf /usr/share/freeswitch/scripts/app /usr/share/lua/5.2/app
# 6. Install PostgreSQL 13 & Initialize Database
RUN apt-get install -y postgresql postgresql-contrib \
    && /etc/init.d/postgresql start \
    && sleep 5 \
    && su - postgres -c "psql -c \"CREATE DATABASE fusionpbx;\"" \
    && su - postgres -c "psql -c \"CREATE DATABASE freeswitch;\"" \
    && su - postgres -c "psql -c \"CREATE ROLE fusionpbx WITH SUPERUSER LOGIN PASSWORD '$PSQL_PASSWORD';\"" \
    && su - postgres -c "psql -c \"CREATE ROLE freeswitch WITH SUPERUSER LOGIN PASSWORD '$PSQL_PASSWORD';\"" \
    && su - postgres -c "psql -c \"GRANT ALL PRIVILEGES ON DATABASE fusionpbx to fusionpbx;\"" \
    && su - postgres -c "psql -c \"GRANT ALL PRIVILEGES ON DATABASE freeswitch to fusionpbx;\"" \
    && su - postgres -c "psql -c \"GRANT ALL PRIVILEGES ON DATABASE freeswitch to freeswitch;\"" \
    && /etc/init.d/postgresql stop
# 7. Final Configs & AI INTEGRATION FILES
USER root
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY start-freeswitch.sh /usr/bin/start-freeswitch.sh
RUN chmod +x /usr/bin/start-freeswitch.sh && mkdir -p /run/php
# Đưa các tệp mã nguồn vào trong Image
# a. Chèn file giao diện PHP vào thư mục Web
COPY ai_ui.php /var/www/fusionpbx/
COPY ai_chat_detail.php /var/www/fusionpbx/
RUN chown www-data:www-data /var/www/fusionpbx/ai_ui.php /var/www/fusionpbx/ai_chat_detail.php
# b. Chèn kịch bản Lua vào trung tâm đầu não của FreeSWITCH
COPY ai_agent.lua /usr/share/freeswitch/scripts/
RUN chown freeswitch:freeswitch /usr/share/freeswitch/scripts/ai_agent.lua
# c. Chèn cấu hình ghi log vào CSDL (XML CDR)
COPY xml_cdr.conf.xml /etc/freeswitch/autoload_configs/
# d. Cấp lại toàn quyền cho Web Server thao tác với FreeSWITCH
RUN chown -R www-data:freeswitch /etc/freeswitch \
    && chmod -R 775 /etc/freeswitch
# Expose ports (SIP, HTTP, HTTPS, RTP range)
EXPOSE 80 443 5060/tcp 5060/udp 5080/tcp 5080/udp 16384-32768/udp
# Để VOLUME ở sau cùng để tránh việc nó đè đứt các file COPY bên trên
VOLUME ["/var/lib/postgresql", "/etc/freeswitch", "/var/lib/freeswitch", "/usr/share/freeswitch", "/var/www/fusionpbx", "/var/log"]
RUN ln -s /usr/sbin/php-fpm8.1 /usr/sbin/php8.1-fpm || true
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
