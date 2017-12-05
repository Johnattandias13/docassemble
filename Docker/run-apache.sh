#!/bin/bash

export DA_ACTIVATE="${DA_PYTHON:-/usr/share/docassemble/local}/bin/activate"
export DA_CONFIG_FILE="${DA_CONFIG:-/usr/share/docassemble/config/config.yml}"
source /dev/stdin < <(su -c "source $DA_ACTIVATE && python -m docassemble.base.read_config $DA_CONFIG_FILE" www-data)

if [ "${DAHOSTNAME:-none}" == "none" ]; then
    if [ "${EC2:-false}" == "true" ]; then
	export LOCAL_HOSTNAME=`curl -s http://169.254.169.254/latest/meta-data/local-hostname`
	export PUBLIC_HOSTNAME=`curl -s http://169.254.169.254/latest/meta-data/public-hostname`
    else
	export LOCAL_HOSTNAME=`hostname --fqdn`
	export PUBLIC_HOSTNAME=$LOCAL_HOSTNAME
    fi
    export DAHOSTNAME=$PUBLIC_HOSTNAME
fi

if [ "${BEHINDHTTPSLOADBALANCER:-false}" == "true" ]; then
    a2enmod remoteip
    a2enconf docassemble-behindlb
else
    a2dismod remoteip
    a2disconf docassemble-behindlb
fi
echo -e "# This file is automatically generated\nWSGIPythonHome ${DA_PYTHON:-/usr/share/docassemble/local}\nTimeout ${DATIMEOUT:-60}\nDefine DAHOSTNAME ${DAHOSTNAME}\nDefine DAPOSTURLROOT ${POSTURLROOT}\nDefine DAWSGIROOT ${WSGIROOT}\nDefine DASERVERADMIN ${SERVERADMIN}" > /etc/apache2/conf-available/docassemble.conf
if [ -n "${CROSSSITEDOMAIN}" ]; then
    echo -e "Define DACROSSSITEDOMAIN\nDefine DACROSSSITEDOMAINVALUE ${CROSSSITEDOMAIN}" >> /etc/apache2/conf-available/docassemble.conf
else
    echo "Define DACROSSSITEDOMAINVALUE *" >> /etc/apache2/conf-available/docassemble.conf
fi
echo "Listen 80" > /etc/apache2/ports.conf
if [ "${BEHINDHTTPSLOADBALANCER:-false}" == "true" ]; then
    echo "Listen 8081" >> /etc/apache2/ports.conf
    a2ensite docassemble-redirect
fi
if [ "${USEHTTPS:-false}" == "true" ]; then
    echo "Listen 443" >> /etc/apache2/ports.conf
    a2enmod ssl
    a2ensite docassemble-ssl
else
    a2dismod ssl
    a2dissite -q docassemble-ssl &> /dev/null
fi

function stopfunc {
    /usr/sbin/apache2ctl stop
    exit 0
}

trap stopfunc SIGINT SIGTERM

/usr/sbin/apache2ctl -DFOREGROUND &
wait %1
