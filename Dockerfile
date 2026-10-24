FROM ubuntu:26.04@sha256:c098726dd9b9733f3e885f8de0ef375206a311b0a317eadc40d347b1115fb944

COPY --from=ghcr.io/astral-sh/uv:0.13.5@sha256:32a7bb39b496babbd997b0a39a4d66c126bdaf5661b302bf6f06abda8deca6ff /uv /uvx /bin/

WORKDIR /app/

ENV UV_FROZEN=1 UV_LINK_MODE=copy UV_COMPILE_BYTECODE=1 UV_NO_DEV=1 UV_PYTHON_INSTALL_DIR=/opt/python

RUN useradd --system --create-home app

COPY pyproject.toml uv.lock ./

RUN --mount=type=cache,target=/root/.cache/uv uv sync

ENV PATH=/app/.venv/bin:$PATH

COPY templates ./templates
COPY main.py ./

USER app
EXPOSE 8000
# The base image has no curl, but the venv's interpreter is already on PATH.
# Checks the key listing rather than /, which creates a keypair as a side effect.
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s \
    CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:8000/meta/public_keys/token_scanning')"]
CMD ["uvicorn", "main:app", "--host=0.0.0.0"]
