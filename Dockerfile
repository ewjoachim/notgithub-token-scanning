FROM python

WORKDIR /app/

COPY scripts ./scripts
COPY requirements.txt ./
RUN /app/scripts/build

COPY main.py ./
COPY templates ./templates
CMD ["/app/scripts/serve"]
EXPOSE 8000
