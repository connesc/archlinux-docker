FROM scratch
ADD archlinux.tar /
ENV LANG=C.UTF-8
CMD ["/usr/bin/bash"]
