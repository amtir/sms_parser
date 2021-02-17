#!/bin/bash 



echo "##################################################################"
echo
echo " Checking the IOT interfaces - $(date)." 
echo
echo "##################################################################"

MODEM_IP="192.168.8.1"

#
# Detect the interfaces available and activated
#
# eth0 RJ45 cable
# wlan0 Wifi 
# eth1 LTE 4G 
#

#eth0 RJ45 LAN, wlan0 wifi, and the eth1 LTE 4G Modem ..."
#now=$(date --utc +"%T")
#echo "  Current System UTC Time: $now"

# Reading the route table.
# LAN RJ45 Cable 
wceth0=`sudo /sbin/route -n | grep eth0 | wc -l`

# Wifi wlan0
wcwlan0=`sudo /sbin/route -n | grep wlan0 | wc -l`

# LTE 4G Swisscom
wceth1=`sudo /sbin/route -n | grep eth1 | wc -l`


# Ethernet RJ45 LAN eth0
if [ $wceth0 != 0 ]
then
    echo " -> eth0 RJ45 LAN enabled."
fi

# WIFI wlan0
if [ $wcwlan0 != 0  ]
then
    echo " -> wlan0 wifi interface enabled.."
fi


# LTE Modem 4G 
if [ $wceth1 != 0 ]
then
    echo " [+] ->  eth1 Modem 4G LTE is activated."
    echo
    echo "Checking the SMS server ..."
    RESPONSE=`curl -s -X GET http://192.168.8.1/api/webserver/SesTokInfo`
    
    # Check the returned exit value
    if [ "$?" = "0" ]; then
      echo " [+] ->  SMS server alive."
    else
      echo " [-] ->  Failed to connect to SMS Server Connexion refusée!" 1>&2
      exit 1
    fi
    
    echo
    COOKIE=`echo "$RESPONSE" | xmlstarlet sel -t -v '//SesInfo' -n`
    TOKEN=`echo "$RESPONSE" | xmlstarlet sel -t -v '//TokInfo' -n`
    #echo "Cookie: $COOKIE"
    #echo "Token: $TOKEN"
    
    DATA="<request><PageIndex>1</PageIndex><ReadCount>1</ReadCount><BoxType>1</BoxType><SortType>0</SortType><Ascending>0</Ascending><UnreadPreferred>1</UnreadPreferred></request>"
    
    # Get the last SMS sent
    MESSAGE=`curl -H "Cookie: $COOKIE" -H "__RequestVerificationToken: $TOKEN" --data "$DATA" http://192.168.8.1/api/sms/sms-list`
    CONTENT=`echo "$MESSAGE" | xmlstarlet sel -t -v '//Content' -n`
    DATE=`echo "$MESSAGE" | xmlstarlet sel -t -v '//Date' -n`
    
    
    if [ "$CONTENT" = "" ]; then
        echo
        echo " [-] ->  Empty content."
        echo
        exit 1
    elif [ "$CONTENT" = "connect" ]; then 
        echo
        echo " [+] -> Command received: connect, Date: $DATE "
        echo
    elif [ "$CONTENT" = "disconnect" ]; then 
        echo
        echo " -> Command received: disconnect, Date: $DATE "
        echo
    elif [ "$CONTENT" = "update" ]; then 
        echo
        echo " [+] -> Command received: update, Date: $DATE "
        echo
    else
        echo
        echo " [-] ->  Unknown command."
        echo " [-] ->  Content: $CONTENT, Date: $DATE"
        echo
    fi 

fi


echo "##################################################################"
echo
echo "Delete SMS messages."
echo
echo "##################################################################"

RESPONSE=`curl -s -X GET http://192.168.8.1/api/webserver/SesTokInfo`
COOKIE=`echo "$RESPONSE" | xmlstarlet sel -t -v '//SesInfo' -n`
TOKEN=`echo "$RESPONSE" | xmlstarlet sel -t -v '//TokInfo' -n`

echo "Cookie: $COOKIE"
echo "Token: $TOKEN"
DATA="<request><PageIndex>1</PageIndex><ReadCount>35</ReadCount><BoxType>1</BoxType><SortType>0</SortType><Ascending>0</Ascending><UnreadPreferred>1</UnreadPreferred></request>"
echo `curl -H "Cookie: $COOKIE" -H "__RequestVerificationToken: $TOKEN" --data "$DATA" http://192.168.8.1/api/sms/sms-list > modem_status.xml`


cat modem_status.xml

#read index
readarray -t array_index <<< "$(xmlstarlet sel -t -m "//Index" -v . -n modem_status.xml)"

rm -f result_status.xml
touch result_status.xml

for ((i=0; i<${#array_index[@]}; i++ ))
do
     
     RESPONSE=`curl -s -X GET http://192.168.8.1/api/webserver/SesTokInfo`
     COOKIE=`echo "$RESPONSE" | xmlstarlet sel -t -v '//SesInfo' -n`
     TOKEN=`echo "$RESPONSE" | xmlstarlet sel -t -v '//TokInfo' -n`
     
     DATA='<?xml version="1.0" encoding="UTF-8"?><request><Index>${index[$i]}</Index></request>'
     echo $DATA
     
     index[$i]=$(printf ${array_index[$i]} | tr -d '\n\r ')
     printf "${index[$i]} "
     printf "\n${index[$i]}\n" >> result_status.xml 
     curl -s -X POST "http://$MODEM_IP/api/sms/delete-sms" -H "Cookie: $COOKIE" -H "__RequestVerificationToken: $TOKEN" -H "Content-Type: text/xml" -d "<?xml version="1.0" encoding="UTF-8"?><request><Index>${index[$i]}</Index></request>" >> result_status.xml
done

#cat result_status.xml


