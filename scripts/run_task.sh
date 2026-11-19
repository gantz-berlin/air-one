#!/usr/bin/env bash
# Starts the dbt container once on Fargate, waits for it and prints its logs.
# Usage:
#   scripts/run_task.sh                          -> dbt build
#   scripts/run_task.sh run --select hello_world -> dbt run --select hello_world
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tf() { terraform -chdir="$ROOT/terraform" output -raw "$1"; }
tf_json() { terraform -chdir="$ROOT/terraform" output -json "$1"; }

REGION="$(tf aws_region)"
CLUSTER="$(tf ecs_cluster_name)"
TASK_DEF="$(tf task_definition_family)"
SG="$(tf security_group_id)"
PUBLIC_IP="$(tf assign_public_ip)"
LOG_GROUP="$(tf log_group_name)"
SUBNETS="$(tf_json subnet_ids | python3 -c 'import json,sys; print(",".join(json.load(sys.stdin)))')"

OVERRIDES='{}'
if [ "$#" -gt 0 ]; then
  OVERRIDES="$(python3 -c 'import json,sys; print(json.dumps({"containerOverrides":[{"name":"dbt","command":sys.argv[1:]}]}))' "$@")"
fi

echo "Starting task $TASK_DEF on cluster $CLUSTER (dbt ${*:-build})"
TASK_ARN="$(aws ecs run-task \
  --region "$REGION" \
  --cluster "$CLUSTER" \
  --task-definition "$TASK_DEF" \
  --launch-type FARGATE \
  --count 1 \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNETS],securityGroups=[$SG],assignPublicIp=$PUBLIC_IP}" \
  --overrides "$OVERRIDES" \
  --query 'tasks[0].taskArn' --output text)"

if [ -z "$TASK_ARN" ] || [ "$TASK_ARN" = "None" ]; then
  echo "run-task did not start a task" >&2
  exit 1
fi

TASK_ID="${TASK_ARN##*/}"
echo "Task: $TASK_ID - waiting for it to finish..."
aws ecs wait tasks-stopped --region "$REGION" --cluster "$CLUSTER" --tasks "$TASK_ARN"

echo "=== Logs ($LOG_GROUP, stream dbt/dbt/$TASK_ID) ==="
aws logs get-log-events --region "$REGION" \
  --log-group-name "$LOG_GROUP" \
  --log-stream-name "dbt/dbt/$TASK_ID" \
  --start-from-head --query 'events[].message' --output text | tr '\t' '\n' || true

EXIT_CODE="$(aws ecs describe-tasks --region "$REGION" --cluster "$CLUSTER" --tasks "$TASK_ARN" \
  --query 'tasks[0].containers[0].exitCode' --output text)"
REASON="$(aws ecs describe-tasks --region "$REGION" --cluster "$CLUSTER" --tasks "$TASK_ARN" \
  --query 'tasks[0].stoppedReason' --output text)"

echo "=== Task stopped: exit code $EXIT_CODE ($REASON) ==="
[ "$EXIT_CODE" = "0" ]
