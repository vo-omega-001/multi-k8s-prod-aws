FROM amazon/aws-cli:2.1.24
WORKDIR '/work'
RUN cat /etc/*-release

RUN yum install -y git gzip jq tar vim

RUN yum install -y openssh
RUN mkdir -p ~/.ssh/

RUN curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
RUN mv /tmp/eksctl /usr/local/bin

RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
RUN chmod +x ./kubectl && mv ./kubectl /usr/local/bin/kubectl
CMD ["sh"]
