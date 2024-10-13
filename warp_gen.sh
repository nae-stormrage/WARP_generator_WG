#!/bin/bash

clear
mkdir -p ~/.cloudshell && touch ~/.cloudshell/no-apt-get-warning # Для Google Cloud Shell, но лучше там не выполнять
echo "Установка зависимостей..."
apt update -y && apt install sudo -y # Для Aeza Terminator, там sudo не установлен по умолчанию
sudo apt-get update -y --fix-missing && sudo apt-get install wireguard-tools jq -y --fix-missing # Update второй раз, если sudo установлен и обязателен (в строке выше не сработал)

api="https://api.cloudflareclient.com/v0i1909051800"
ins() { curl -s -H 'user-agent:' -H 'content-type: application/json' -X "$1" "${api}/$2" "${@:3}"; }
sec() { ins "$1" "$2" -H "authorization: Bearer $3" "${@:4}"; }

# Получение количества конфигов из первого параметра (по умолчанию 1)
num_configs=${1:-1}

for ((i=1; i<=num_configs; i++)); do
  priv=$(wg genkey)
  pub=$(echo "${priv}" | wg pubkey)

  response=$(ins POST "reg" -d "{\"install_id\":\"\",\"tos\":\"$(date -u +%FT%T.000Z)\",\"key\":\"${pub}\",\"fcm_token\":\"\",\"type\":\"ios\",\"locale\":\"en_US\"}")
  
  id=$(echo "$response" | jq -r '.result.id')
  token=$(echo "$response" | jq -r '.result.token')
  response=$(sec PATCH "reg/${id}" "$token" -d '{"warp_enabled":true}')
  peer_pub=$(echo "$response" | jq -r '.result.config.peers[0].public_key')
  peer_endpoint=$(echo "$response" | jq -r '.result.config.peers[0].endpoint.host')
  client_ipv4=$(echo "$response" | jq -r '.result.config.interface.addresses.v4')
  client_ipv6=$(echo "$response" | jq -r '.result.config.interface.addresses.v6')
  port=$(echo "$peer_endpoint" | sed 's/.*:\([0-9]*\)$/\1/')
  peer_endpoint=$(echo "$peer_endpoint" | sed 's/\(.*\):[0-9]*/162.159.193.5/')

  conf=$(cat <<-EOM
  [Interface]
  PrivateKey = ${priv}
  S1 = 0
  S2 = 0
  Jc = 4
  Jmin = 40
  Jmax = 70
  H1 = 1
  H2 = 2
  H3 = 3
  H4 = 4
  Address = ${client_ipv4}, ${client_ipv6}
  DNS = 1.1.1.1, 2606:4700:4700::1111, 1.0.0.1, 2606:4700:4700::1001

  [Peer]
  PublicKey = ${peer_pub}
  AllowedIPs = 0.0.0.0/1, 128.0.0.0/1, ::/1, 8000::/1
  Endpoint = ${peer_endpoint}:${port}
  EOM
  )

  clear
  echo -e "\n\n\n"
  [ -t 1 ] && echo "########## НАЧАЛО КОНФИГА №${i} ##########"
  echo "${conf}"
  [ -t 1 ] && echo "########### КОНЕЦ КОНФИГА №${i} ###########"

  # Сохранение конфига в файл
  conf_base64=$(echo -n "${conf}" | base64 -w 0)
  echo "Скачать конфиг файлом: https://immalware.github.io/downloader.html?filename=WARP_${i}.conf&content=${conf_base64}"
  echo -e "\n"
done

echo "Что-то не получилось? Есть вопросы? Пишите в чат: https://t.me/immalware_chat"
