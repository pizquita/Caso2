FROM nginx:latest
RUN apt update && apt install -y apache2-utils openssl
RUN mkdir -p /etc/nginx/auth /etc/nginx/certificates /usr/share/nginx/html
RUN htpasswd -bc /etc/nginx/auth/.htpasswd admin password
RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/nginx/certificates/server.key \
  -out /etc/nginx/certificates/server.crt \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"
COPY index.html /usr/share/nginx/html/index.html
COPY default.conf /etc/nginx/conf.d/default.conf
