# Fargate Lab — Issues & Fixes Needed

## 1. ecsTaskExecutionRole trust policy missing

**Symptom:** Service stays at 0 running tasks. No obvious error in console.

**Diagnose:**
```bash
aws ecs describe-services --cluster coroutine-lab --services coroutine-lab-svc \
  --region ap-south-1 --query 'services[0].events[0:3]'
```
Error: `ECS was unable to assume the role 'arn:aws:iam::...:role/ecsTaskExecutionRole'`

**Fix (account admin, one-time):**
```bash
aws iam update-assume-role-policy --role-name ecsTaskExecutionRole --policy-document '{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "ecs-tasks.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }]
}'
```

## 2. No public endpoint after service starts

The deploy script registers the task and creates the service but doesn't output the task's public IP.

**After service is running, get the IP:**
```bash
TASK_ARN=$(aws ecs list-tasks --cluster coroutine-lab --service-name coroutine-lab-svc \
  --region ap-south-1 --query 'taskArns[0]' --output text)

ENI=$(aws ecs describe-tasks --cluster coroutine-lab --tasks $TASK_ARN \
  --region ap-south-1 \
  --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' \
  --output text)

aws ec2 describe-network-interfaces --network-interface-ids $ENI \
  --region ap-south-1 \
  --query 'NetworkInterfaces[0].Association.PublicIp' --output text
```

Then: `curl http://<PUBLIC_IP>:8080/lab/1`

**Suggested fix:** Add above IP-discovery block to end of `deploy-fargate.sh`.

## 3. Security group blocks port 8080

Default SG may not allow inbound 8080. If curl times out:
```bash
SG=$(aws ec2 describe-security-groups --region ap-south-1 \
  --filters "Name=group-name,Values=default" \
  --query 'SecurityGroups[0].GroupId' --output text)

aws ec2 authorize-security-group-ingress --group-id $SG \
  --protocol tcp --port 8080 --cidr 0.0.0.0/0 --region ap-south-1
```

## 4. What the lab should demonstrate (once working)

Deploy with different CPU units and run `/lab/1` each time:

| CPU Units | vCPU | Expected peak concurrent (Lab 1) |
|-----------|------|----------------------------------|
| 256       | 0.25 | 1                                |
| 512       | 0.5  | 1                                |
| 1024      | 1    | 1                                |
| 2048      | 2    | 2                                |
| 4096      | 4    | 4                                |

`Dispatchers.Default` peak concurrent = available processors. Changing CPU units changes the number — same code, different hardware, different behavior. That's the point.
