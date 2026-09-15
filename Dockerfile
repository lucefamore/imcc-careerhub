FROM nginx:alpine

# Copy static web files to nginx default html directory
COPY . /usr/share/nginx/html/

# Copy imcc.html as default index.html for root access
RUN cp /usr/share/nginx/html/imcc.html /usr/share/nginx/html/index.html

# Expose default HTTP port
EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
