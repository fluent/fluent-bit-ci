module "microk8s" {
  source                    = "git::https://github.com/balchua/terraform-lxd-microk8s?ref=main"
  node_count                = "2"
  microk8s_channel          = var.k8s-version
  cluster_token             = "PoiuyTrewQasdfghjklMnbvcxz123409"
  cluster_token_ttl_seconds = 7200
  cluster_name              = "integration"
}