# cephalopodus-gigantus
A data infra demo project with Amazon Athena, S3, Apache Superset

## Pre-requisites
1. An AWS account and AWS CLI
2. Helm
3. Kubectl
4. Terraform
5. Python

## 1. Deploy Terraform Infrastructure
The `terraform/` directory contains the IaC for this project. You will deploy:
- A VPC
- An EKS cluster
- An S3 bucket
- An Athena workgroup
- (Optionally) ACM certificate, Hosted Zone and DNS records for a custom domain
### 1.1 Set variables
Before we can deploy the terraform infrastructure to AWS, we need to customize the variables in `terraform/variables.tf` to our use case.
Create your own `terraform/terraform.tfvars` file and set the values you wish to use.

### 1.2 Plan/Apply
1. Go to the terraform folder and run `terraform init`
2. Run `terraform plan -out plan.out` and examine the plan for any issues
3. If everything looks good, run `terraform apply`
## 2. Upload Data to S3 Bucket
1. Download the data CSV file `curl -O `
2. Transform the date format in the CSV file so it can be read by Athena `python convert_dates.py`. This will produce a file `megamillions_formatted.csv`
3. Upload the formatted data file to the S3 bucket `aws s3 cp megamillions_formatted.csv s3://<bucket-name>/data/`
> Note: You may have to create a table in Athena using the Query editor and this query before Superset can query the table itself (replace LOCATION with your bucket)
```sql
CREATE EXTERNAL TABLE IF NOT EXISTS `lottery`.`megamillions` (
  `draw_date` date,
  `winning_numbers` array < int >,
  `mega_ball` int,
  `multiplier` float
) COMMENT "Megamillions winning umbers beginning 2002"
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe'
WITH SERDEPROPERTIES ('field.delim' = ',', 'collection.delim' = ' ')
STORED AS INPUTFORMAT 'org.apache.hadoop.mapred.TextInputFormat' OUTPUTFORMAT 'org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat'
LOCATION 's3://cephalopodus-gigantus/data/'
TBLPROPERTIES (
  'classification' = 'csv',
  'skip.header.line.count' = '1'
);
```

## 3. Deploy AWS Load Balancer Controller Helm Chart
1. Set up your kubeconfig (replace args with your own values as necessary) `aws eks update-kubeconfig --region us-east-1 --name cephalopod --alias cephalopod --profile dylan-aws1`
2. Set `LB_ROLE_ARN`: `LB_ROLE_ARN=$(terraform output load_balancer_role_arn | tr -d '"')`
3. Add the Helm repo to your local system `helm repo add eks https://aws.github.io/eks-charts`
4. Install the chart (replace clusterName with your own)
```bash
helm install -n kube-system aws-load-balancer-controller eks/aws-load-balancer-controller \
 --set clusterName=cephalopod \
 --set serviceAccount.name=aws-load-balancer-controller \
 --set "serviceAccount.annotations.eks\.amazonaws\.com/role-arn=${LB_ROLE_ARN}"
 ```
## 4. DNS / HTTPS
I decided not include the Route53 and AWS Certificate Manager resources in the terraform (short on time). 
However, in the next step we do provision an ALB ingress, and it is very simple to create an Alias record pointing to the provisioned ALB and create a TLS certificate in ACM to associate with the ALB.

It's not necessary to do this, because we can just port-forward the Superset service to our localhost.
## 5. Deploy Superset Helm Chart
1. Edit the `helm/superset/.env` file to set the username/pw you want to use in your system, then run `source .env`
2. Generate a secret key used to encrypt the Postgres metastore `SECRET_KEY=$(openssl rand -base64 42)`
3. Save all credentials in your password manager so you don't lose them
4. In the `helm/superset/values.yaml` file, customize `role-arn` and `sqlalchemy_uri` in `import_datasources.yaml` to match your values. Also, under `ingress` customize the values to match your domain and ACM certificate.
5. Add the Superset Helm repo to your local repository `helm repo add superset https://apache.github.io/superset`
6. Create a new namespace for Superset `kubectl create namespace superset`
7. Deploy the chart into the namespace
```bash
helm upgrade --install --values values.yaml superset superset/superset -n superset \
--set init.adminUser.username=$ADMIN_USER \
--set init.adminUser.password=$ADMIN_PW \
--set postgresql.auth.username=$PG_USER \
--set postgresql.auth.password=$PG_PW \
--set supersetNode.connections.db_user=$PG_USER \
--set supersetNode.connections.db_pass=$PG_PW \
--set "configOverrides.secret=SECRET_KEY \= '${SECRET_KEY}'"
```
8. Port-forward the Superset service to your machine `kubectl -n superset port-forward service/superset 8088:8088`
9. Visit Superset at [http://localhost:8088](http://localhost:8088)
