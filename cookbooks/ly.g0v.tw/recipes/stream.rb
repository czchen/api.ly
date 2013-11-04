include_recipe "nginx::source"
include_recipe "ly.g0v.tw::stream-worker"

directory "/var/run/hls" do
  action :create
  owner "www-data"
  group "www-data"
end

template "/etc/nginx/rtmp.conf" do
  source "rtmp.erb"
  owner "root"
  group "root"
  variables ({
    :allow_publish => node[:ly][:allow_publish] || [],
    :rtmp_listen => node[:ly][:rtmp_listen] || '127.0.0.1',
  })
  mode 00755
end
template "/etc/nginx/sites-available/lystream" do
  source "site-lystream.erb"
  owner "root"
  group "root"
  variables ({:fqdn => node[:ly][:lystream_fqdn]})
  mode 00755
end
nginx_site "lystream"

template "/etc/ffserver.conf" do
  source "ffserver.erb"
  owner "root"
  group "root"
  variables ({:channels => node[:ly][:channels]})
  mode 00755
  notifies :restart, "service[ffserver]"
end

runit_service "ffserver" do
  default_logger true
  action [:enable, :start]
end
