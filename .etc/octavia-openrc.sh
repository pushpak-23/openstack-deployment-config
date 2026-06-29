# Clear any old environment that may conflict.
for key in $( set | awk '{FS="="}  /^OS_/ {print $1}' ); do unset $key ; done
export OS_PROJECT_DOMAIN_NAME='Default'
export OS_USER_DOMAIN_NAME='Default'
export OS_PROJECT_NAME='service'
export OS_USERNAME='octavia'
export OS_PASSWORD='kuLvEHY9BAHiynrPfeBN50t73Y2J6kHTW5elPg3v'
export OS_AUTH_URL='https://vip.internal.cloud:5000'
export OS_INTERFACE='internal'
export OS_ENDPOINT_TYPE='internalURL'
