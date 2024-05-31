terraform {
  required_version = ">= 1.0"

  provider_meta "equinix" {
    module_name = "openstack-cloud-foundation"
  }

  required_providers {
    equinix = {
      source  = "equinix/equinix"
      version = ">= 1.8.1"
    }
  }
}
