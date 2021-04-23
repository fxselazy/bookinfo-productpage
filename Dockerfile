FROM python:3.8
WORKDIR /usr/src/app
ADD . .
RUN pip install -r requirements.txt
EXPOSE 80
CMD python3 productpage.py 80