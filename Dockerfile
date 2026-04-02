# -----------------------------------------------------
# Build
# -----------------------------------------------------

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build-stage

WORKDIR /build

RUN apt-get update && apt-get install -y unzip

ADD https://github.com/baaron4/GW2-Elite-Insights-Parser/archive/refs/tags/v3.20.0.0.zip /build/EI.zip
RUN unzip EI.zip

WORKDIR /build/GW2-Elite-Insights-Parser-3.20.0.0/GW2EIParserCLI
RUN dotnet build -c Release --self-contained --runtime linux-x64 -o out

# -----------------------------------------------------
# Main image
# -----------------------------------------------------

FROM debian:bookworm-slim

RUN mkdir -p /opt/gw2-ei-parser /opt/scripts

COPY --from=build-stage /build/GW2-Elite-Insights-Parser-3.20.0.0/GW2EIParserCLI/out /opt/gw2-ei-parser/

COPY ./src/wingman_uploader.sh /opt/scripts/wingman_uploader.sh
COPY ./conf/parser.conf /etc/gw2-ei-parser/parser.conf

ENV XDG_CONFIG_HOME=/etc/gw2-ei-parser
ENV XDG_DATA_HOME=/etc/gw2-ei-parser

RUN apt-get update && apt-get install -y \
    curl \
    inotify-tools \
    unzip \
    libicu72 \
    && rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["/opt/scripts/wingman_uploader.sh"]
