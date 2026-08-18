FROM myoung34/github-runner:latest

RUN pip install --no-cache-dir uv

# Add runner user to docker group for socket access
RUN groupmod -g 998 docker; usermod -aG docker runner
