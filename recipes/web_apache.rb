# Author:: Nacer Laradji (<nacer.laradji@gmail.com>)
# Cookbook Name:: zabbix
# Recipe:: web
#
# Copyright 2011, Efactures
#
# Apache 2.0
#

include_recipe "zabbix::common"

directory node['zabbix']['install_dir'] do
  mode "0755"
end

node.normal['zabbix']['web']['fqdn'] = node['fqdn'] if node['zabbix']['web']['fqdn'].nil?
unless node['zabbix']['web']['user']
  node.normal['zabbix']['web']['user'] = "apache"
end

user node['zabbix']['web']['user']

case node['platform_family']
when "debian"
  web_pkgs = %w{ php5-mysql php5-gd libapache2-mod-php5 }
when "rhel"
  if node['platform_version'].to_f < 6.0
    web_pkgs =  %w{ php53-mysql php53-gd php53-bcmath php53-mbstring }
  else
    web_pkgs =  %w{ php php-mysql php-gd php-bcmath php-mbstring php-xml }
  end
end

web_pkgs.each do |pkg|
  package pkg do
    action :install
    notifies :restart, "service[apache2]"
  end
end

zabbix_source "extract_zabbix_web" do
  branch              node['zabbix']['server']['branch']
  version             node['zabbix']['server']['version']
  source_url          node['zabbix']['server']['source_url']
  code_dir            node['zabbix']['src_dir']
  target_dir          "zabbix-#{node['zabbix']['server']['version']}"
  install_dir         node['zabbix']['install_dir']
  action :extract_only
end

link node['zabbix']['web_dir'] do
  to "#{node['zabbix']['src_dir']}/zabbix-#{node['zabbix']['server']['version']}/frontends/php"
end

directory "#{node['zabbix']['src_dir']}/zabbix-#{node['zabbix']['server']['version']}/frontends/php/conf" do
  owner node['apache']['user']
  group node['apache']['group']
  mode "0755"
  action :create
end

# install zabbix PHP config file
template "#{node['zabbix']['src_dir']}/zabbix-#{node['zabbix']['server']['version']}/frontends/php/conf/zabbix.conf.php" do
  source "zabbix_web.conf.php.erb"
  owner "root"
  group "root"
  mode "754"
  variables({
    :database => node['zabbix']['database'],
    :server => node['zabbix']['server']
  })
end

# install vhost for zabbix frontend
web_app node['zabbix']['web']['fqdn'] do
  server_name node['zabbix']['web']['fqdn']
  server_aliases node['zabbix']['web']['aliases']
  docroot node['zabbix']['web_dir']
  only_if { node['zabbix']['web']['fqdn'] != nil }
  php_settings node['zabbix']['web']['php']['settings']
  notifies :restart, "service[apache2]", :immediately 
end

apache_site "000-default" do
  enable false
end
