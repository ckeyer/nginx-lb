user  nginx;
worker_processes  auto;

error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;

events {
    worker_connections  10240;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;
    sendfile        on;
    keepalive_timeout  65;
    gzip  on;
    server_names_hash_bucket_size 128;

    include /etc/nginx/conf.d/*.conf;

    (template "upstreams" . -)

    (range $server := .)
    server  {
        listen ($server.FrontendPort);
        server_name ($server.DomainName);
        ($server.Opaque)

        (range $uri, $route := $server.Routes)

        location ($uri) {
            ($route.Opaque)
            proxy_pass http://(upstreamName $route $server.DomainName $uri)($route.BackendPath);
            proxy_redirect    off;
            proxy_set_header  Host             $host;
            proxy_set_header  X-Real-IP        $remote_addr;
            proxy_set_header  X-Forwarded-For  $proxy_add_x_forwarded_for;
        }
        (- end)
    }
    (if .EnableSsl)
    server  {
        listen (.SslPort) ssl;
        server_name (.DomainName);
        ssl_certificate     (.SslCertPath);
        ssl_certificate_key (.SslKeyPath);
        ssl_session_cache   shared:SSL:10m;
        ssl_session_timeout 10m;
        ($server.Opaque)

        (- range $uri, $route := $server.Routes)

        location ($uri) {
            ($route.Opaque)
            proxy_pass http://(upstreamName $route $server.DomainName $uri)($route.BackendPath);
            proxy_redirect    off;
            proxy_set_header  Host             $host;
            proxy_set_header  X-Real-IP        $remote_addr;
            proxy_set_header  X-Forwarded-For  $proxy_add_x_forwarded_for;
        }
        (- end)
    }
    (end -)
    (- end)
}
