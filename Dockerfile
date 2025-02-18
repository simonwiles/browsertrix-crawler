ARG BROWSER_VERSION=91

ARG BROWSER_IMAGE_BASE=webrecorder/browsertrix-browser-base

ARG BROWSER_BIN=google-chrome

FROM ${BROWSER_IMAGE_BASE}:${BROWSER_VERSION} AS browser

FROM ubuntu:bionic

# http://bugs.python.org/issue19846
# > At the moment, setting "LANG=C" on a Linux system *fundamentally breaks Python 3*, and that's not OK.
ENV LANG C.UTF-8

RUN apt-get update -y && apt-get install --no-install-recommends -qqy software-properties-common \
    && add-apt-repository -y ppa:deadsnakes \
    && apt-get update -y \
    && apt-get install --no-install-recommends -qqy build-essential fonts-stix locales-all redis-server xvfb gpg-agent curl git socat \
	   python3.8 python3.8-distutils python3.8-dev gpg ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
    && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
    && curl -sL https://deb.nodesource.com/setup_16.x -o /tmp/nodesource_setup.sh && bash /tmp/nodesource_setup.sh \
	&& apt-get update -y && apt-get install -qqy nodejs yarn \
    && curl https://bootstrap.pypa.io/get-pip.py | python3.8 \
    && pip install 'setuptools<58.0'

# needed to add args to main build stage
ARG BROWSER_VERSION
ARG BROWSER_BIN

ENV PROXY_HOST=localhost \
    PROXY_PORT=8080 \
    PROXY_CA_URL=http://wsgiprox/download/pem \
    PROXY_CA_FILE=/tmp/proxy-ca.pem \
    DISPLAY=:99 \
    GEOMETRY=1360x1020x16 \
    BROWSER_VERSION=${BROWSER_VERSION} \
    BROWSER_BIN=${BROWSER_BIN}

COPY --from=browser /deb/*.deb /deb/
RUN dpkg -i /deb/*.deb; apt-get update; apt-mark hold chromium-browser; apt --fix-broken install -qqy; \
    rm -rf /var/lib/opts/lists/*

WORKDIR /app

ADD requirements.txt /app/
RUN pip install -r requirements.txt

ADD package.json /app/

# to allow forcing rebuilds from this stage
ARG REBUILD

RUN yarn install

ADD uwsgi.ini /app/
ADD *.js /app/
ADD util/*.js /app/util/
COPY config.yaml /app/
ADD html/ /app/html/

RUN ln -s /app/main.js /usr/bin/crawl
RUN ln -s /app/create-login-profile.js /usr/bin/create-login-profile

WORKDIR /crawls

CMD ["crawl"]

