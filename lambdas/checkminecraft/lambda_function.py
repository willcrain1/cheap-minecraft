import json
import boto3

def lambda_handler(event, context):
    client = boto3.client('ec2')
    response = client.describe_instances(
        Filters=[
            {
                'Name': 'tag:Name',
                'Values': [
                    'Minecraft',
                ]
            },
        ]
    )
    ip = ""
    for r in response['Reservations']:
        for i in r['Instances']:
            if(i['State']['Name'] == "running" and i['Tags'][0].get('Value') == "Minecraft"):
                ip = i['NetworkInterfaces'][0]['Association']['PublicIp']
    statusCode = 500
    if(ip != ""):
        statusCode = 200
    returnStatement = ""
    if statusCode == 200:
        returnStatement = "The Minecraft server is up and running on ip " + ip
    else:
        returnStatement = "The Minecraft server is not up and running"
    return returnStatement