Usage
----------

This image is an automated reverse proxy using Nginx.  It is designed to reverse proxy multiple other Docker containers and thus route requests from the host's HTTP and HTTPS ports to different containers based on the hostname.

This image requires a reasonable amount of preconfiguration, in that you need to specify how the Nginx configuration will be generated for each of the servers.

To configure this image, create a `config` directory, with a `servers` directory inside it and a `generate` script inside that.  It should be mapped in such a way that in the container, `/config/servers/generate` exists and is executable.

**WARNING:** Do not reverse proxy to SSL ports. There are known issues with downloading files and reverse proxying to an SSL port, so you should just use port 80 instead. In this scenario, the reverse proxy still offers SSL to the end-user, but uses plain HTTP while routing to the other Docker instances.

Here is an example script that you can change for your own needs:

    #!/bin/bash
    
    cat >example.com.conf <<EOF
    server {
        server_name example.com;
    
        listen      *:80;
        return 301 https://\$host\$request_uri;
    }
    
    server {
        server_name example.com;
    
        listen      *:443 ssl;
    
        ssl_certificate      /etc/nginx/certs/cert-example.com.pem;
        ssl_certificate_key  /etc/nginx/certs/cert-example.com.key;
    
        ssl_session_timeout  5m;
    
        ssl_protocols  SSLv2 SSLv3 TLSv1;
        ssl_ciphers  HIGH:!aNULL:!MD5;
        ssl_prefer_server_ciphers   on;
    
        location / {
            # Note that this is HTTP on port 80 and NOT SSL!
            proxy_pass http://${LINKED_EXAMPLE_COM_PORT_80_TCP_ADDR}:${LINKED_EXAMPLE_COM_PORT_80_TCP_PORT};
            include reverse.inc;
        }
    }
    
    EOF
    
    cat >another.com.conf <<EOF
    server {
        server_name another.com;
    
        listen      *:80;
    
        location / {
            try_files \$uri \$uri/ /index.php;
            if ( !-f \$request_filename )
            {
                rewrite ^/(.*)$ /index.php?__path__=/tychaia/\$1&__pageview=TychaiaStandardPageView&__appname=Unearth last;
                break;
            }
        }
    
        location /index.php {
            proxy_pass http://${LINKED_ANOTHER_COM_PORT_80_TCP_ADDR}:${LINKED_ANOTHER_COM_PORT_80_TCP_PORT};
            include reverse.inc;
        }
    }
    
    EOF

The other critical step is linking the containers together correctly.  The example above assumes that this container has been run with the following command:

    /usr/bin/docker run -p 80:80 -p 443:443 -v /path/to/autoproxy/config:/config --name=autoproxy --link example.com:linked_example_com --link another.com:linked_another_com hachque/nginx-autoproxy
    
What do these parameters do?

    -p 80:80 = forward the host's HTTP port to this proxy
    -p 443:443 = forward the host's HTTPS port to this proxy
    -v /path/to/autoproxy/config:/config = map the configuration directory for the proxy
    --name autoproxy = the name of the container
    --link example.com:linked_example_com = link the example.com container to this one
    --link another.com:linked_another_com = link the another.com container to this one
    hachque/nginx-autoproxy = the name of the image
    
Note that the names `linked_example_com` and `linked_another_com` directly correspond to the variables names used in the `generate` script.

This image is intended to be used in such a way that a new container is created each time it is started, instead of starting and stopping a pre-existing container from this image.  You should configure your service startup so that the container is stopped and removed each time.  A systemd configuration file may look like:
    
    [Unit]
    Description=Nginx proxy for main sites
    Requires=docker.service example.com.service another.com.service
    
    [Service]
    ExecStart=<command to start instance, see above>
    ExecStop=/usr/bin/docker stop autoproxy
    ExecStop=/usr/bin/docker rm autoproxy
    Restart=always
    RestartSec=5s
    
    [Install]
    WantedBy=multi-user.target

SSL configuration
-------------------

All files located in the `/config/certs` directory (if present) are copied to `/etc/nginx/certs`.  This allows you to reference SSL certificates from within the Nginx server configuration.

SSH / Login
--------------

**Username:** root

**Password:** linux

