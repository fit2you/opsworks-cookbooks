require 'resolv'
include_recipe 'deploy'

Chef::Log.level = :debug

node[:deploy].each do |application, deploy|
  next if deploy[:database].nil? || deploy[:database].empty?

  mysql_dump_f = "mysqldump -h %s --user=%s --password=%s --add-drop-table --skip-lock-tables %s | %s %s"

  execute "root password" do
    command "mysql -uroot -e \"SET PASSWORD=PASSWORD('#{deploy[:database][:root_password]}');\""
  end

  mysql_command = "#{node[:mysql][:mysql_bin]} -u root -p#{deploy[:database][:root_password]}"


  node[:mysql_import][:databases].each do |origin, db|
    execute "drop database #{db}" do
      command "#{mysql_command} -e 'DROP DATABASE `#{db}`' "
      action :run

      only_if do
        system("#{mysql_command} -e 'SHOW DATABASES' | egrep -e '^#{db}$'")
      end
    end

    execute "create database #{db}" do
      command "#{mysql_command} -e 'CREATE DATABASE `#{db}`' "
      action :run
    end

    execute "import remote database #{db}" do
      mysql_dump_command = sprintf(mysql_dump_f, node[:mysql_import][:host],
                                   node[:mysql_import][:username],
                                   node[:mysql_import][:password],
                                   origin, mysql_command, db
      )
      command mysql_dump_command
      action :run
    end

    log "#{db} import message" do
      message "Database #{db} imported from #{node[:mysql_import][:host]}@#{origin}"
      level :info
    end


  end

end


