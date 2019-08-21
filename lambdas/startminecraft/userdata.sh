#!/bin/bash

yum update -y
yum install java -y
yum install jq -y

mkdir /minecraftserver
cd /minecraftserver

#using minecraft server version 1.14.2
curl https://launcher.mojang.com/v1/objects/808be3869e2ca6b62378f9f4b33c946621620019/server.jar > /minecraftserver/server.jar

chmod +x /minecraftserver/server.jar
echo "eula=true" > /minecraftserver/eula.txt
aws s3 sync s3://crainweminecraftbucket/minecraftserver/world /minecraftserver/world || echo "no world directory in s3"
aws s3 cp s3://crainweminecraftbucket/minecraftserver/banned-ips.json /minecraftserver/banned-ips.json || echo "no banned-ips.json file in s3"
aws s3 cp s3://crainweminecraftbucket/minecraftserver/banned-players.json /minecraftserver/banned-players.json || echo "no banned-players.json file in s3"
aws s3 cp s3://crainweminecraftbucket/minecraftserver/ops.json /minecraftserver/ops.json || echo "no ops.json file in s3"
aws s3 cp s3://crainweminecraftbucket/minecraftserver/server.properties /minecraftserver/server.properties || echo "no server.properties file in s3"
aws s3 cp s3://crainweminecraftbucket/minecraftserver/usercache.json /minecraftserver/usercache.json || echo "no usercache.json file in s3"
aws s3 cp s3://crainweminecraftbucket/minecraftserver/whitelist.json /minecraftserver/whitelist.json || echo "no whitelist.json file in s3"

echo "0 * * * * aws s3 sync /minecraftserver/world s3://crainweminecraftbucket/minecraftserver/world" > /var/spool/cron/root
echo "0 * * * * aws s3 cp /minecraftserver/banned-ips.json s3://crainweminecraftbucket/minecraftserver/banned-ips.json" >> /var/spool/cron/root
echo "0 * * * * aws s3 cp /minecraftserver/banned-players.json s3://crainweminecraftbucket/minecraftserver/banned-players.json" >> /var/spool/cron/root
echo "0 * * * * aws s3 cp /minecraftserver/ops.json s3://crainweminecraftbucket/minecraftserver/ops.json" >> /var/spool/cron/root
echo "0 * * * * aws s3 cp /minecraftserver/server.properties s3://crainweminecraftbucket/minecraftserver/server.properties" >> /var/spool/cron/root
echo "0 * * * * aws s3 cp /minecraftserver/usercache.json s3://crainweminecraftbucket/minecraftserver/usercache.json" >> /var/spool/cron/root
echo "0 * * * * aws s3 cp /minecraftserver/whitelist.json s3://crainweminecraftbucket/minecraftserver/whitelist.json" >> /var/spool/cron/root

cat <<EOF > /autoshutdown.sh
#!/bin/bash

minutesNotConnected=0

while true
do

sleep 60

playersConnected=\$(netstat -anp | grep :25565 | grep ESTABLISHED | wc -l)

if [ \${playersConnected} -gt 0 ]
then
  echo "\${playersConnected} players are connected to the server."
  minutesNotConnected=0
else
  ((minutesNotConnected++))
  echo "no one has been connected for \${minutesNotConnected} minutes."
  if [ \${minutesNotConnected} -gt 30 ] && [ \$(date +"%M") -eq 5 ]
  then
    echo "shutting down the server"
    aws ec2 cancel-spot-instance-requests --spot-instance-request-ids `aws ec2 describe-instances --filters "Name=tag:Name,Values=Minecraft,Name=instance-state-name,Values=running" --region us-east-1 | jq .Reservations[].Instances[].SpotInstanceRequestId -r` --region us-east-1
	aws ec2 terminate-instances --instance-ids `aws ec2 describe-instances --filters "Name=tag:Name,Values=Minecraft,Name=instance-state-name,Values=running" --region us-east-1 | jq .Reservations[].Instances[].InstanceId -r` --region us-east-1
  fi
fi

done
EOF

sh /autoshutdown.sh &>/autoshutdown.log &

aws ec2 create-tags --resources `curl 169.254.169.254/latest/meta-data/instance-id` --tags Key=Name,Value=Minecraft --region us-east-1

java -d64 -Xmx6G -Xms6G -Xmn768m -XX:+DisableExplicitGC -XX:+UseConcMarkSweepGC -XX:+UseParNewGC -XX:+UseNUMA -XX:+CMSParallelRemarkEnabled -XX:MaxTenuringThreshold=15 -XX:MaxGCPauseMillis=30 -XX:GCPauseIntervalMillis=150 -XX:+UseAdaptiveGCBoundary -XX:-UseGCOverheadLimit -XX:+UseBiasedLocking -XX:SurvivorRatio=8 -XX:TargetSurvivorRatio=90 -XX:MaxTenuringThreshold=15 -Dfml.ignorePatchDiscrepancies=true -Dfml.ignoreInvalidMinecraftCertificates=true -XX:+UseFastAccessorMethods -XX:+AggressiveOpts -XX:ReservedCodeCacheSize=2048m -XX:+UseCodeCacheFlushing -XX:SoftRefLRUPolicyMSPerMB=10000 -XX:ParallelGCThreads=10 -jar /minecraftserver/server.jar