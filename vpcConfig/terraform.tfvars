serviceaccount_map = {
    "loadbalancercontroller" = {
        namespace = "kube-system"
        serviceaccount = "aws-load-balancer-controller"
        policyfilename = "loadbalancercontrollerpolicy.json"
    }
    "ebscsidriverpolicy" = {
        namespace = "kube-system"
        serviceaccount = "ebs-csi-controller-sa"
        policyfilename = "ebscsidriverpolicy.json"
    }
}