#create a public IP address for the virtual machine
resource "azurerm_public_ip" "linux-env-stg-pubip" {
  name                = "linux-env-stg-pubip"
  location            = var.azure_region
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
  domain_name_label   = "linux-env-stg-${lower(substr(join("", split(":", timestamp())), 8, -1))}"

  tags = {
    environment = var.azure_env
  }
}

#create the network interface and put it on the proper vlan/subnet
resource "azurerm_network_interface" "linux-env-stg-ip" {
  name                = "linux-env-stg-ip"
  location            = var.azure_region
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "linux-env-stg-ipconf"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = azurerm_public_ip.linux-env-stg-pubip.id
  }
}

#create the actual VM
resource "azurerm_virtual_machine" "linux-env-stg" {
  name                  = "linux-env-stg"
  location              = var.azure_region
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.linux-env-stg-ip.id]
  vm_size               = var.vm_size

  storage_os_disk {
    name              = "linux-env-stg-osdisk"
    managed_disk_type = "Standard_LRS"
    caching           = "ReadWrite"
    create_option     = "FromImage"
  }
  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  os_profile {
    computer_name  = "linux-env-stg"
    admin_username = var.username
    admin_password = var.password
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  tags = {
    environment = var.azure_env
  }

  connection {
    host     = azurerm_public_ip.linux-env-stg-pubip.fqdn
    type     = "ssh"
    user     = var.username
    password = var.password
  }

  provisioner "chef" {
    client_options  = ["chef_license '${var.license_accept}'"]
    run_list        = [var.run_list]
    environment     = "stg"
    node_name       = "linux-env-stg"
    server_url      = var.chef_server_url
    recreate_client = true
    user_name       = var.chef_user_name
    user_key        = file(var.chef_user_key)
    version         = var.chef_client_version

    # If you have a self signed cert on your chef server change this to :verify_none
    ssl_verify_mode = ":verify_peer"
  }
}

output "linux-env-stg-fqdn" {
  value = azurerm_public_ip.linux-env-stg-pubip.fqdn
}

