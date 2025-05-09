@export()
@description('Information about the configuration for a virtual network in the environment.')
type vnetConfigInfo = {
  @description('Resource ID of a subnet for infrastructure components.')
  infrastructureSubnetId: string
  @description('Value indicating whether the environment only has an internal load balancer.')
  internal: bool
}
