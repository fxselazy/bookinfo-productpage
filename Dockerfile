FROM python:3.8
WORKDIR /usr/src/app
ADD . .
RUN pip3 install -r requirements.txt
EXPOSE 8080
CMD python3 productpage.py 8080