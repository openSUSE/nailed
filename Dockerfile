FROM opensuse:13.2
MAINTAINER Duncan Mac-Vicar P. "dmacvicar@suse.de"

RUN zypper --gpg-auto-import-keys --non-interactive in --no-recommends \
    libxml2-devel libxslt-devel \
    sqlite3-devel gcc make ruby-devel rubygem-bundler \
    ca-certificates ca-certificates-mozilla git-core

# Database location
ENV DATABASE_URL sqlite:///data/db/nailed.db

RUN useradd -m nailed
RUN mkdir -p /data/db && mkdir -p /data/log && mkdir -p /data/config
RUN chown nailed:users /data/ -R
VOLUME ["/data"]
# add the git tree with the app
ADD . /home/nailed/app
RUN chown nailed:users /home/nailed/app/ -R
USER nailed
WORKDIR /home/nailed/app
RUN ls -la
# add the dependencies
RUN bundle config build.nokogiri "--use-system-libraries"
RUN bundle install --path /home/nailed/app/vendor/bundle
# redirect the config to the volume
RUN rm -rf config && ln -s /data/config config
RUN rm -rf log && ln -s /data/log log

# Bugzilla configuration
#ENV DEFAULT_OSCRC_PATH /data/config/oscrc
# Guthub configuration
ENV OCTOKIT_NETRC /data/config/netrc
ENV HOME /data/config

EXPOSE 4567
CMD ["--help"]
ENTRYPOINT ["bundle", "exec", "bin/nailed"]