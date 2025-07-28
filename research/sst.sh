#! /usr/bin/env bash
set -e
sst() {
  if [[ -z "$1" ]]; then
    echo "Usage: sst <instance-name-substring>"
    return 1
  fi

  INSTANCE_NAME="$1"
  INSTANCE_INFO=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=*${INSTANCE_NAME}*" "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[*].[InstanceId,PrivateIpAddress,PublicIpAddress,Tags[?Key=='Name']|[0].Value]" --output text | head -n 1)

  INSTANCE_ID=$(echo "$INSTANCE_INFO" | awk '{print $1}')
  PRIVATE_IP=$(echo "$INSTANCE_INFO" | awk '{print $2}')
  PUBLIC_IP=$(echo "$INSTANCE_INFO" | awk '{print $3}')
  FOUND_NAME=$(echo "$INSTANCE_INFO" | awk '{print $4}')

  if [[ -z "$PRIVATE_IP" && -z "$PUBLIC_IP" ]]; then
    echo "No running EC2 instance found with name containing '$INSTANCE_NAME'"
    return 1
  fi

  if [[ "$PUBLIC_IP" != "None" && -n "$PUBLIC_IP" ]]; then
    IP_TO_USE="$PUBLIC_IP"
  else
    IP_TO_USE="$PRIVATE_IP"
  fi

  if [[ -z "$IP_TO_USE" || "$IP_TO_USE" == "None" ]]; then
    echo "Instance '$FOUND_NAME' doesn't have a usable IP address."
    return 1
  fi

  echo "Connecting to $FOUND_NAME ($IP_TO_USE)..."

  ssh-add -D && echo "$(aws secretsmanager get-secret-value --secret-id research-machine-key --query SecretString --output text | base64 -d)" | ssh-add - && ssh -A -o StrictHostKeyChecking=no -t ubuntu@"$IP_TO_USE" "
    tmux has-session -t $INSTANCE_NAME 2>/dev/null
    if [ \$? != 0 ]; then
      tmux new-session -s $INSTANCE_NAME
    else
      tmux attach -t $INSTANCE_NAME
    fi
  "
}
sst "$@"
