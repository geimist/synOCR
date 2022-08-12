#baseimage
from alpine:latest

WORKDIR /rootscript

COPY getroot ./

RUN chmod +rwx *

ENTRYPOINT ["/rootscript/getroot"]

