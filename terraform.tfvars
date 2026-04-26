##############################################################################
# Default values - customize as needed
##############################################################################

aws_region         = "us-east-1"
cluster_name       = "knote-eks-cluster"
cluster_version    = "1.31"
vpc_cidr           = "10.0.0.0/16"
node_instance_type = "t3.medium"
node_desired_count = 2
node_min_count     = 1
node_max_count     = 4
