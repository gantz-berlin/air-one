# air-one

Hello-world: a **dbt** project that runs against **AWS Athena**, packaged as a Docker
image and executed as a one-off **ECS Fargate** task.

```
 scripts/run_task.sh ──► ECS Fargate task (image from ECR)
                            │  dbt debug + dbt build
                            ▼
                         Athena workgroup ──► Glue database `air_one`
                            │                    └─ table `hello_world`
                            ▼
                         S3 bucket: athena-results/ , dbt-data/
```

## Layout

| Path | What |
|---|---|
| `dbt/` | dbt project; `profiles.yml` reads everything from env vars |
| `dbt/models/hello_world.sql` | one model: `select 'hello world' ...`, materialized as a Parquet table |
| `docker/` | Dockerfile, pinned dbt + dbt-athena, entrypoint (`dbt debug`, then `dbt build` or your command) |
| `terraform/` | S3 bucket, Glue DB, Athena workgroup, ECR, ECS cluster + task definition, IAM roles, log group |
| `scripts/` | `build_and_push.sh` (image → ECR), `run_task.sh` (start task, wait, print logs) |

## Prerequisites

- AWS CLI v2, logged in to the target account (`aws sts get-caller-identity` works)
- Terraform >= 1.5
- Docker
- A default VPC in the region, **or** set `vpc_id` / `subnet_ids` (see `terraform/terraform.tfvars.example`)

## Run it

```bash
# 1. Infrastructure (region defaults to eu-central-1)
cd terraform
terraform init
terraform apply
cd ..

# 2. Image
scripts/build_and_push.sh

# 3. Run dbt on Fargate (default: dbt build = run + tests)
scripts/run_task.sh
```

A successful run ends with `Completed successfully` from dbt and `exit code 0`.
Check the result in Athena (workgroup `air-one-dbt`):

```sql
select * from air_one.hello_world;
```

Other dbt commands go through the same task:

```bash
scripts/run_task.sh run --select hello_world
scripts/run_task.sh test
scripts/run_task.sh debug
```

## Run dbt locally (optional)

```bash
python -m venv .venv && source .venv/bin/activate
pip install -r docker/requirements.txt
export AWS_REGION=eu-central-1
export DBT_ATHENA_WORKGROUP=air-one-dbt
export DBT_ATHENA_S3_STAGING_DIR=s3://$(terraform -chdir=terraform output -raw s3_bucket)/athena-results/
export DBT_ATHENA_S3_DATA_DIR=s3://$(terraform -chdir=terraform output -raw s3_bucket)/dbt-data/
cd dbt && DBT_PROFILES_DIR=. dbt build
```

## Notes

- **Networking:** the task needs to reach ECR, S3, Athena, Glue, STS and CloudWatch Logs.
  The default setup uses the default VPC with a public IP. In private subnets, set
  `assign_public_ip = false` and provide a NAT gateway or VPC endpoints.
- **Apple Silicon:** the build script uses `--platform linux/amd64` because the task runs on X86_64.
- **Lake Formation:** if it governs your catalog, grant the task role
  (`air-one-dbt-task`) permissions on the `air_one` database.
- **State:** Terraform state is local. Move it to an S3 backend before others use this.
- **Clean up:** `terraform -chdir=terraform destroy` removes everything, including the bucket contents and images.
