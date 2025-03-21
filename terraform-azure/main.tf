# Grupo de Recursos
resource "azurerm_resource_group" "rg" {
  name     = "my-resource-group"
  location = "West Europe"
}

# Azure Container Registry (ACR)
resource "azurerm_container_registry" "acr" {
  name                = "myacr${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = true
}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# Máquina Virtual Linux
resource "azurerm_virtual_network" "vnet" {
  name                = "my-vnet"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "subnet" {
  name                 = "my-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_interface" "nic" {
  name                = "my-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm_public_ip.id
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                = "my-linux-vm"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B1s"
  admin_username      = "mayca"
  network_interface_ids = [azurerm_network_interface.nic.id]

  admin_ssh_key {
    username   = "mayca"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }
}

# Cluster AKS (Kubernetes)
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "my-aks-cluster"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "myakscluster"

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_DS2_v2"
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_public_ip" "vm_public_ip" {
  name                = "my-vm-public-ip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Dynamic"
}

data "azurerm_client_config" "current" {}

resource "azurerm_role_assignment" "vm_acr_role" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "ACRPull"
  principal_id = try(azurerm_linux_virtual_machine.vm.identity[0].principal_id, azurerm_linux_virtual_machine.vm.identity.0.principal_id)
  depends_on = [azurerm_linux_virtual_machine.vm] # Dependencia explícita
}

resource "azurerm_role_assignment" "aks_acr_role" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "ACRPull"
  principal_id         = try(azurerm_kubernetes_cluster.aks.identity[0].principal_id, azurerm_kubernetes_cluster.aks.identity.0.principal_id)
  depends_on = [azurerm_kubernetes_cluster.aks] # Dependencia explícita
}