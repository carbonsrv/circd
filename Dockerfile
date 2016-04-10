####################
# CIRCd Dockerfile #
####################

FROM carbonsrv/carbon

MAINTAINER Adrian "vifino" Pistol

# Make /conf a volume, so you can bind it
VOLUME ["/conf"]
WORKDIR /conf

# Put the source in that directory.
COPY . /circd

# Run cobalt
ENTRYPOINT ["/usr/bin/carbon", "-root=/circd", "/circd/circd.lua"]
CMD [":6667"]
