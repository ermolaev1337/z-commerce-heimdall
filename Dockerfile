FROM node:20

RUN curl --proto '=https' --tlsv1.2 https://sh.rustup.rs -sSf | sh -s -- -y
RUN /bin/bash -c 'source "$HOME/.cargo/env"'
RUN git clone https://github.com/iden3/circom.git /app/installation/circom
RUN /root/.cargo/bin/cargo build --release --manifest-path /app/installation/circom/Cargo.toml
RUN /root/.cargo/bin/cargo install --path /app/installation/circom/circom

#TODO: get rid of the redundant "circom" pfolder in the "installation" folder (above)
RUN git clone https://github.com/iden3/circomlib.git /app/circom/lib/circomlib
RUN npm install -g snarkjs@latest

COPY ./heimdalljs/package.json ./heimdalljs/package-lock.json /app/heimdalljs/
WORKDIR /app/heimdalljs

RUN npm ci

RUN apt update
RUN apt upgrade -y
RUN apt install golang-go -y
ENV GO111MODULE=on

RUN go install github.com/msoap/shell2http@latest
RUN mkdir -p ~/bin/
RUN ln -s $(go env GOPATH)/bin/shell2http ~/bin/shell2http
ENV PATH=$PATH:/root/go/bin/

COPY ./heimdalljs /app/heimdalljs
RUN npm link
RUN heimdalljs -h

# https://github.com/msoap/shell2http
WORKDIR /app/execution
CMD ["shell2http","-show-errors","-cgi","-form", \
 "GET:/upload/form", "echo \"<html><body><form method=POST action=/upload/file?name=$v_name enctype=multipart/form-data><input type=file name=uplfile><input type=submit></form>\"",\
 "POST:/upload/file", "cat $filepath_uplfile > $v_name; echo OK \"$v_name $filepath_uplfile\"",\
 "/heimdalljs/key/new", "heimdalljs key new $v_seed > $v_name ; cat $v_name",\
 "/heimdalljs/key/pub", "echo \"$v_private\" | heimdalljs key pub > $v_name ; cat $v_name",\
 "/heimdalljs/cred/new", "heimdalljs cred new --attributes $v_attributes --id $v_id --publicKey $v_publicKey --expiration $v_expiration --type $v_type --delegatable $v_delegatable --registry $v_registry --secretKey $v_secretKey --destination $v_destination ; cat $v_destination",\
 "/heimdalljs/pres/range", "echo \"Access-Control-Allow-Origin: *\n\"; v_upper=$(expr $(date +%s%3N) - 567993600000); heimdalljs pres range $v_index --expiration $v_expiration --challenge $v_challenge --destination $v_destination --secretKey $v_secretKey --credential $v_credential --upperBound $v_upper; cat $v_destination",\
 "/heimdalljs/pres/attribute", "echo \"Access-Control-Allow-Origin: *\n\"; heimdalljs pres attribute $v_index --expiration $v_expiration --challenge $v_challenge --destination $v_destination --secretKey $v_secretKey --credential $v_credential ; cat $v_destination",\
 "/heimdalljs/verify", "heimdalljs verify $v_path --publicKey $v_publicKey --challenge $v_challenge > $v_name ; cat $v_name",\
 "/heimdalljs/revoc/update", "heimdalljs revoc update $v_index -g $v_token > $v_name ; cat $v_name",\
 "/cred", "echo \"Access-Control-Allow-Origin: *\n\"; cat $v_path",\
 "/data", "echo \"Access-Control-Allow-Origin: *\n\"; echo 'some data for another host'"\
 ]