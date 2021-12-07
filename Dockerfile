FROM python:3.10-alpine

WORKDIR /app/

COPY . /app/
RUN pip install --upgrade pip

# requirements.txt lists `cryptography` which needs `cffi`
# which doesn't have a musl (Alpine) wheel and needs `gcc`
# and libs for installation from source
RUN apk add --update --no-cache --virtual .build-deps \
      gcc musl-dev libffi-dev \
    && /app/scripts/build \
    && apk del .build-deps

CMD ["/app/scripts/serve"]
EXPOSE 8000
