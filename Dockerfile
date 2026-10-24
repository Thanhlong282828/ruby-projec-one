FROM ruby:3.4-slim
RUN apt-get update -qq && apt-get install --no-install-recommends -y build-essential default-libmysqlclient-dev pkg-config curl && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY Gemfile Gemfile.lock* ./
COPY modules ./modules
RUN bundle install
RUN apt-get update -qq && apt-get install --no-install-recommends -y git && rm -rf /var/lib/apt/lists/*
COPY . .
RUN groupadd --gid 1000 hrm && useradd --uid 1000 --gid hrm --create-home hrm && mkdir -p tmp/pids log && chown -R hrm:hrm /app
USER hrm
EXPOSE 3000
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
