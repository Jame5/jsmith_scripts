cli53 rrcreate -r -x 60 ${DOMAIN} <dns_entry> A $IP_2
cli53 rrcreate -r -x 60 ${DOMAIN} <dns_entry> A $IP_1
cli53 rrcreate -r -x 60 ${DOMAIN} _srv._example.record SRV "1 10 <port> FQDN1.${DOMAIN}" "2 20 <port> FQDN2.${DOMAIN}"
