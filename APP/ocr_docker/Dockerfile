#baseimage
from alpine:latest

WORKDIR /

COPY getroot ./

RUN chmod +rwx *

ENTRYPOINT ["/getroot"]