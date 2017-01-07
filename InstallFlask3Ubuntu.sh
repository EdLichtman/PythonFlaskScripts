#!/bin/bash
# This Script assumes you took responsibility as root user (sudo -i)

clear

function installIfNotExists {
packageName=$1;
if [ $(dpkg-query -W -f='${Status}' $packageName 2>/dev/null | grep -c "ok installed") -eq 0 ];
then
  echo Y | apt-get install $packageName;
fi
}

function enableWSGI {

if [ $(apache2ctl -M | grep -c "wsgi_module") -eq 0 ];
then
  echo a2enmod wsgi
fi
}


# Initialize User Defined Variables

read -p "Please enter a name for new Flask Application : " flaskApp
read -p "Please enter a listener port for $flaskApp (8080) : " listenerPort
read -p "Please enter an email for Application Admin : " applicationAdminEmailAddress

## Initial Setup

# Install mod-swgi
installIfNotExists libapache2-mod-wsgi-py3
installIfNotExists python3-dev


# Add Beginning and Ending Listeners to ports.conf
if [ $(cat /etc/apache2/ports.conf | grep -c "# Beginning Extra Listeners") -eq 0 ];
then
  sed -i '/Listen 80/a# Beginning Extra Listeners' /etc/apache2/ports.conf 
fi
if [ $(cat /etc/apache2/ports.conf | grep -c "# Beginning Extra Listeners") -eq 1 ] &&
   [ $(cat /etc/apache2/ports.conf | grep -c "# Ending Extra listeners") -eq 0 ];
then
  sed -i '/# Beginning Extra Listeners/a# Ending Extra listeners' /etc/apache2/ports.conf
fi

#enable wsgi
enableWSGI

# Create FlaskApp

cd /var/www/ && mkdir $flaskApp && cd $flaskApp && mkdir $flaskApp && cd $flaskApp && mkdir static templates

printf "from flask import Flask\r\napp = Flask(__name__)\r\n@app.route(\"/\")\r\ndef hello():\r\n\treturn \"Hello, I love Eddie's Scripts!\"\r\nif __name__ == \"__main__\":\r\n\tapp.run()" > /var/www/$flaskApp/$flaskApp/__init__.py

flaskAppLocation="/var/www/"$flaskApp"/"$flaskApp

# Install Flask into a virtual environment

installIfNotExists python3-pip

cd $flaskAppLocation && pip3 install virtualenv && virtualenv venv && source venv/bin/activate && pip3 install flask && deactivate

# Step Four -- Configure and Enable a New Virtual Host

printf "WSGIPythonPath "$flaskAppLocation"/venv/:"$flaskAppLocation"/venv/lib/python3.4/site-packages\r\n<VirtualHost *:"$listenerPort">\r\n\t\tServerName localhost\r\n\t\tServerAdmin $applicationAdminEmailAddress\r\n\t\tWSGIScriptAlias / /var/www/"$flaskApp"/flaskapp.wsgi\r\n\t\t<Directory "$flaskAppLocation"/>\r\n\t\t\tOrder allow,deny\r\n\t\t\tAllow from all\r\n\t\t</Directory>\r\n\t\tAlias /static "$flaskAppLocation"/static\r\n\t\t<Directory "$flaskAppLocation"/static/>\r\n\t\t\tOrder allow,deny\r\n\t\t\tAllow from all\r\n\t\t</Directory>\r\n\t\tErrorLog \${APACHE_LOG_DIR}/flaskError.log\r\n\t\tLogLevel warn\r\n\t\tCustomLog \${APACHE_LOG_DIR}/flaskAccess.log combined\r\n</VirtualHost>" > /etc/apache2/sites-available/$flaskApp.conf 

a2ensite $flaskApp

# Step Five -- Create the .wsgi File

printf '#!/usr/bin/python3.4\r\nimport sys\r\nimport logging\r\nlogging.basicConfig(stream=sys.stderr)\r\nsys.path.insert(0,"/var/www/'$flaskApp'/")\r\n\r\nfrom '$flaskApp' import app as application\r\napplication.secret_key = "Add your secret key"\r\n'  > /var/www/$flaskApp/flaskapp.wsgi

# Add new listener to the listeners

sed -i '/# Ending Extra listeners/i Listen '$listenerPort /etc/apache2/ports.conf


# Step Seven -- Restart apache2
service apache2 restart
