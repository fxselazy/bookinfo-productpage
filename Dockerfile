FROM python:3.8
WORKDIR /usr/src/app
ADD . .
ARG DETAILS_HOSTNAME
ARG RATINGS_HOSTNAME
ARG REVIEWS_HOSTNAME
ENV DETAILS_HOSTNAME ${DETAILS_HOSTNAME:-http://details:8080}
ENV RATINGS_HOSTNAME ${RATINGS_HOSTNAME:-http://ratings:8081}
ENV REVIEWS_HOSTNAME ${REVIEWS_HOSTNAME:-http://reviews:9080}
RUN pip3 install -r requirements.txt
EXPOSE 80
CMD python3 productpage.py 80