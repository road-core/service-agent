# vim: set filetype=dockerfile
ARG LIGHTSPEED_RAG_CONTENT_IMAGE=quay.io/openshift-lightspeed/lightspeed-rag-content@sha256:4586286266e06e0c0aa7aa9f316f45cc4dd3a9d37e22e2d8501a47fc7c768173

FROM ${LIGHTSPEED_RAG_CONTENT_IMAGE} as lightspeed-rag-content

FROM registry.access.redhat.com/ubi9/ubi-minimal

ARG VERSION
ARG APP_ROOT=/app-root

RUN microdnf install -y --nodocs --setopt=keepcache=0 --setopt=tsflags=nodocs \
    python3.11 python3.11-devel python3.11-pip shadow-utils logrotate \
    && microdnf clean all --enablerepo='*'

# PYTHONDONTWRITEBYTECODE 1 : disable the generation of .pyc
# PYTHONUNBUFFERED 1 : force the stdout and stderr streams to be unbuffered
# PYTHONCOERCECLOCALE 0, PYTHONUTF8 1 : skip legacy locales and use UTF-8 mode
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONCOERCECLOCALE=0 \
    PYTHONUTF8=1 \
    PYTHONIOENCODING=UTF-8 \
    LANG=en_US.UTF-8 \
    PIP_NO_CACHE_DIR=off

WORKDIR ${APP_ROOT}

COPY scripts/logrotate.conf /etc/logrotate.d/memray
COPY --from=lightspeed-rag-content /rag/vector_db/ocp_product_docs ./vector_db/ocp_product_docs
COPY --from=lightspeed-rag-content /rag/embeddings_model ./embeddings_model

# Add explicit files and directories
# (avoid accidental inclusion of local directories or env files or credentials)
COPY pyproject.toml pdm.lock runner.py ./
RUN pip3.11 install --no-cache-dir --upgrade pip pdm \
    && pdm config python.use_venv false \
    && pdm sync --global --prod -p ${APP_ROOT}

# Create a logrotate status file location where the non-root user has write access
RUN mkdir -p /app-root/logrotate-status \
    && chown -R 1001:0 /app-root/logrotate-status \
    && chown -R 1001:0 ${APP_ROOT} && chmod -R g+rwX ${APP_ROOT}

COPY ols ./ols

# this directory is checked by ecosystem-cert-preflight-checks task in Konflux
COPY LICENSE /licenses/

# Run the application
EXPOSE 8080
EXPOSE 8443
CMD ["/bin/sh", "-c", "(logrotate -s /app-root/logrotate-status/logrotate.status -f /etc/logrotate.d/memray &); python3.11 -m memray run -o ./output.bin runner.py"]

LABEL io.k8s.display-name="OpenShift LightSpeed Service" \
      io.k8s.description="AI-powered OpenShift Assistant Service." \
      io.openshift.tags="openshift-lightspeed,ols" \
      description="Red Hat OpenShift Lightspeed Service" \
      summary="Red Hat OpenShift Lightspeed Service" \
      com.redhat.component=openshift-lightspeed-service \
      name=openshift-lightspeed-service \
      vendor="Red Hat, Inc."

# no-root user is checked in Konflux 
USER 1001
