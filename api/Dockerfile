# Multi-stage build for the SQL Performance Playground API
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY SqlPerf.Api/SqlPerf.Api.csproj SqlPerf.Api/
RUN dotnet restore SqlPerf.Api/SqlPerf.Api.csproj
COPY SqlPerf.Api/ SqlPerf.Api/
RUN dotnet publish SqlPerf.Api/SqlPerf.Api.csproj -c Release -o /app

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app

# Docker CLI + compose plugin so the API can drive disaster-recovery operations
# (recreate the sqlserver container/image/volume) via the mounted host Docker socket.
# See docker-compose.yml: /var/run/docker.sock is bind-mounted into this container.
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl gnupg \
    && install -m 0755 -d /etc/apt/keyrings \
    && . /etc/os-release \
    && curl -fsSL "https://download.docker.com/linux/${ID}/gpg" -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/${ID} ${VERSION_CODENAME} stable" > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends docker-ce-cli docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /app .
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080
ENTRYPOINT ["dotnet", "SqlPerf.Api.dll"]
