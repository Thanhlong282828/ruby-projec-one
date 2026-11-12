FROM ghcr.io/gitleaks/gitleaks:v8.30.1@sha256:c00b6bd0aeb3071cbcb79009cb16a60dd9e0a7c60e2be9ab65d25e6bc8abbb7f AS secret_scanner
FROM ruby:3.4.12-slim
RUN apt-get update -qq && apt-get install --no-install-recommends -y build-essential default-mysql-client default-libmysqlclient-dev pkg-config curl && rm -rf /var/lib/apt/lists/*
COPY --from=secret_scanner /usr/bin/gitleaks /usr/local/bin/gitleaks
WORKDIR /app
COPY Gemfile Gemfile.lock* ./
COPY modules ./modules
RUN gem install bundler -v 2.6.9 --no-document && bundle _2.6.9_ install
RUN apt-get update -qq && apt-get install --no-install-recommends -y git && rm -rf /var/lib/apt/lists/*
COPY . .
RUN groupadd --gid 1000 hrm && useradd --uid 1000 --gid hrm --create-home hrm && mkdir -p tmp/pids log && chown -R hrm:hrm /app
USER hrm
EXPOSE 3000
CMD ["sh", "/app/bin/start-web"]
