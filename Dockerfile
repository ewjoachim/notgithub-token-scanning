FROM python

WORKDIR /app/

COPY . /app/
RUN /app/scripts/build

CMD ["/app/scripts/serve"]
EXPOSE 8000
