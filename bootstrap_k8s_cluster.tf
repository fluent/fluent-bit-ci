module "microk8s" {
  source                     = "git::https://github.com/balchua/terraform-lxd-microk8s?ref=main"
  node_count                 = "2"
  microk8s_channel           = "1.20/edge"
  cluster_token              = "PoiuyTrewQasdfghjklMnbvcxz123409"
  cluster_token_ttl_seconds  = 3600
  cluster_name               = "nemo"
}

