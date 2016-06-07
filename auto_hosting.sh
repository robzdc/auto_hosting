#openssl rand -hex 6

#useradd demo -m -p 123456 -s /bin/false


#!/bin/bash
# By Anagrama. robzdc.

nginx_enable(){
  confFile=$1
  fullFilePath=/etc/nginx/sites-available/$confFile
  symLinkPath=/etc/nginx/sites-enabled/$confFile

  # First test to see that the file exists
  if [ ! -e $fullFilePath ]
  then
    printf "%s not found..." "$fullFilePath"
    printf "Aborted!\n"
  else
    # If symlink already exists, delete it so the new configuration
    # will take effect.
    if [ -e $symLinkPath ]
    then
      printf "Old symbolic link removed...\n"
      sudo rm $symLinkPath
    fi

    sudo ln -s $fullFilePath $symLinkPath

    # Confirm the symlink was created
    if [ -e $symLinkPath ]
    then
      printf "$confFile enabled.\n"
    fi
  fi
}

clear
# Obtener nombre de pagina
echo -n "Nombre de proyecto: "
read name

# Parameterizar nombre
name=`echo $name | sed 's/\(.\)\([ ]\)/\1-/g' | tr '[:upper:]' '[:lower:]'`

# Obtener url del proyecto para crear directorios
echo -n "URL de pagina (Sin http): "
read url

# Crear usuario para linux
if [ $(id -u) -eq 0 ]; then
  
  password=$(openssl rand -hex 6)

  egrep "^$name" /etc/passwd >/dev/null
  if [ $? -eq 0 ]; then
    echo "$name exists!"

    echo -n "Continuar con este mismo usuario? (y/n): "
    read same_user

    if [ $same_user = "n" ]; then
      exit 1
    fi
  else
    pass=$(perl -e 'print crypt($ARGV[0], "password")' $password) >/dev/null
    useradd $name -d /home/$url -p $pass -s /bin/false -g ssh-users
    [ $? -eq 0 ] && echo "User has been added to system!" || echo "Failed to add a user!" exit 1
  fi
else
  echo "Only root may add a user to the system"
  exit 2
fi

# Obtener repositorio de bitbucket
echo -n "Nombre de Repositorio de Bitbucket: "
read repository

# Crear carpeta con nombre obtenido
if ls /home/$url; then
  echo "Ya existe un proyecto con el mismo nombre."
  echo -n "Presiona ENTER para continuar..."
  read pause

  sh /opt/auto_hosting.sh
else
  mkdir -p /home/$url
  echo "Password: $password" >> .ftp_info
fi

# Si falla, buscar certificado y mostrarlo.. si no existe, crearlo.
if git clone $repository /home/$url/website; then
  echo "Repositorio clonado..."
  replace "ebex_db" $name"_db" -- /home/$url/website/config/database.yml
else
  if cat ~/.ssh/id_rsa.pub; then
    echo "Copia el certificado y pegalo en Bitbucket."
    echo -n "Presiona ENTER para continuar..."
    read pause 

    sh /opt/auto_hosting.sh
  else
    ssh-keygen -t rsa
    cat ~/.ssh/id_rsa.pub
  fi
fi

# Crear archivo en sites-available
cp gistfile1.txt /etc/nginx/sites-available/$url

replace "railsapp1_server" $name -- /etc/nginx/sites-available/$url
replace "/var/www/railsapp1.com/current/public" "/home/$url/website/public" -- /etc/nginx/sites-available/$url
replace "railsapp1.com" "$url" -- /etc/nginx/sites-available/$url
replace "railsapp1.sock" "$name.sock" -- /etc/nginx/sites-available/$url
#my_ip=$(hostname -I | sed 's/^[ \t]*//;s/[ \t]*$//')
#replace "server_name $url" "server_name $url $my_ip/$name" -- /etc/nginx/sites-available/$url

# Crear symbolic link para  el archivo
nginx_enable $url

# Agregar unicorn.rb a proyecto
cp unicorn.conf.rb /home/$url/website/config/unicorn.rb

# Obtener puerto libre para unicorn
unicorn_port=$(grep "1003:" /etc/passwd | wc -l)
# Reemplazar puerto en unicorn.rb
port=$(($unicorn_port + 8080))
replace "listen 8080" "listen $port" -- /home/$url/website/config/unicorn.rb

mkdir -p /home/$url/website/tmp
chmod 775 /home/$url/website/tmp
replace "/var/www/unicorn" "/home/$url/website" -- /home/$url/website/config/unicorn.rb
replace "/tmp/.sock" "/tmp/$name.sock" -- /home/$url/website/config/unicorn.rb

# Hacer bundle install al proyecto
cd /home/$url/website
bundle install
rake db:drop RAILS_ENV=production
rake db:create RAILS_ENV=production
rake db:migrate RAILS_ENV=production
rake db:seed RAILS_ENV=production
rake assets:precompile 

# Reiniciar servicio de nginx
service nginx reload

# Iniciar unicorn de proyecto
unicorn_rails -c /home/$url/website/config/unicorn.rb -D -E production

ls -la /home/
