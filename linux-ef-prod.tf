#create a public IP address for the virtual machine
resource "azurerm_public_ip" "linux-ef-prod-pubip" {
  name                         = "linux-ef-prod-pubip"
  location                     = "${var.azure_region}"
  resource_group_name          = "${azurerm_resource_group.rg.name}"
  allocation_method            = "Dynamic"
  domain_name_label            = "linux-ef-prod-${lower(substr("${join("", split(":", timestamp()))}", 8, -1))}"

  tags {
    environment = "${var.azure_env}"
  }
}

#create the network interface and put it on the proper vlan/subnet
resource "azurerm_network_interface" "linux-ef-prod-ip" {
  name                = "linux-ef-prod-ip"
  location            = "${var.azure_region}"
  resource_group_name = "${azurerm_resource_group.rg.name}"


  ip_configuration {
    name      = "linux-ef-prod-ipconf"
    subnet_id = "${azurerm_subnet.subnet.id}"
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = "${azurerm_public_ip.linux-ef-prod-pubip.id}"
  }
}

#create the actual VM
resource "azurerm_virtual_machine" "linux-ef-prod" {
  name                  = "linux-ef-prod"
  location              = "${var.azure_region}"
  resource_group_name   = "${azurerm_resource_group.rg.name}"
  network_interface_ids = ["${azurerm_network_interface.linux-ef-prod-ip.id}"]
  vm_size               = "${var.vm_size}"

  storage_os_disk {
    name            = "linux-ef-prod-osdisk"
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
    computer_name  = "linux-ef-prod"
    admin_username = "${var.username}"
    admin_password = "${var.password}"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  tags {
    environment = "${var.azure_env}"
  }

  connection {
    host     = "${azurerm_public_ip.linux-ef-prod-pubip.fqdn}"
    type     = "ssh"
    user     = "${var.username}"
    password = "${var.password}"
  }

  # Add remote_exec provisioner to install hab

}

output "linux-ef-prod-fqdn" {
  value = "${azurerm_public_ip.linux-ef-prod-pubip.fqdn}"
}
