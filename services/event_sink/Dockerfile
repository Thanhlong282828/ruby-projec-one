FROM python:3.13-alpine
WORKDIR /service
COPY server.py test_server.py ./
RUN adduser -D -u 1000 hrm && mkdir -p /data && chown hrm /data
USER hrm
EXPOSE 8080
CMD ["python", "server.py"]
