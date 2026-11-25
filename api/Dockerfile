# Pinned to an explicit Elixir+OTP pairing (not a bare `elixir:1.17-slim` tag)
# because newer `jose` (a Guardian dependency) ships Erlang typespecs that
# only compile cleanly on OTP 27+; letting the base image float could land on
# an older OTP and fail the build the same way it did outside Docker.
FROM hexpm/elixir:1.17.3-erlang-27.1.2-debian-bookworm-20241016-slim

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      build-essential \
      ca-certificates \
      git \
      inotify-tools \
      postgresql-client \
    && rm -rf /var/lib/apt/lists/*

RUN mix local.hex --force && mix local.rebar --force

WORKDIR /app

COPY mix.exs mix.lock ./
RUN mix deps.get

COPY . .

EXPOSE 4000

ENTRYPOINT ["./docker-entrypoint.sh"]
CMD ["mix", "phx.server"]
