FROM phullr2/todobackend-base:latest

# Copy application artefacts
COPY target /wheelhouse

# Install Application
RUN . /appenv/bin/activate && \
    pip install --no-index -f /wheelhouse todobackend && \
    rm -rf /wheelhouse