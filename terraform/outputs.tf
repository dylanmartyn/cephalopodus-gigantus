#cluster name
output "cluster_name" {
    value = module.eks.cluster_name
}
#querier access key id
output "querier_access_key_id" {
    value = aws_iam_access_key.querier.id
}
#querier secret access key
output "querier_access_key_secret" {
    value = aws_iam_access_key.querier.secret
    sensitive = true
}
#athena role arn
output "athena_role_arn" {
    value = aws_iam_role.athena.arn
}
#load balancer controller role arn
output "load_balancer_role_arn" {
    value = module.lb_controller_irsa_role.iam_role_arn
}